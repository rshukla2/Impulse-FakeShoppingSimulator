"""Wikidata dish metadata enriched with licensed Wikimedia Commons images."""

from __future__ import annotations

import hashlib
import html
import re
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import unquote, urlparse

from sqlalchemy.orm import Session

from backend.app.config import settings
from backend.app.models import RestaurantModel
from backend.app.services.external_http import ExternalHTTPClient
from backend.app.services.pricing_rules import stable_catalog_values


SPARQL = """
SELECT DISTINCT ?dish ?dishLabel ?dishDescription ?cuisineLabel ?country ?countryLabel ?countryCode ?image WHERE {
  ?dish wdt:P31/wdt:P279* wd:Q746549;
        wdt:P18 ?image.
  OPTIONAL { ?dish wdt:P2012 ?cuisine. }
  OPTIONAL { ?dish wdt:P495 ?country. OPTIONAL { ?country wdt:P297 ?countryCode. } }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 150
"""

ALLOWED_LICENSES = {
    "cc0": "CC0", "public domain": "Public Domain", "pd": "Public Domain",
    "cc by 2.0": "CC BY 2.0", "cc by 3.0": "CC BY 3.0", "cc by 4.0": "CC BY 4.0",
    "cc by-sa 2.0": "CC BY-SA 2.0", "cc by-sa 3.0": "CC BY-SA 3.0", "cc by-sa 4.0": "CC BY-SA 4.0",
}


def allowed_license_name(raw_license: str) -> Optional[str]:
    lowered = raw_license.strip().lower()
    if lowered.startswith("cc0"):
        return "CC0"
    if lowered.startswith("public domain") or lowered == "pd":
        return "Public Domain"
    if re.fullmatch(r"cc by(?:-sa)? \d(?:\.\d)?", lowered):
        return raw_license.strip().upper()
    return ALLOWED_LICENSES.get(lowered)


def _binding(binding: Dict[str, Any], name: str) -> Optional[str]:
    value = binding.get(name, {}).get("value")
    return str(value).strip() if value else None


def _qid(uri: Optional[str]) -> Optional[str]:
    return uri.rsplit("/", 1)[-1] if uri and re.search(r"Q\d+$", uri) else None


def commons_title(image_url: str) -> Optional[str]:
    path = unquote(urlparse(image_url).path)
    marker = "Special:FilePath/"
    filename = path.split(marker, 1)[-1] if marker in path else path.rsplit("/", 1)[-1]
    return f"File:{filename.replace('_', ' ')}" if filename else None


def parse_wikidata_bindings(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    result = []
    seen = set()
    for row in payload.get("results", {}).get("bindings", []):
        qid = _qid(_binding(row, "dish"))
        name = _binding(row, "dishLabel")
        image = _binding(row, "image")
        title = commons_title(image) if image else None
        if not qid or not name or not title or qid in seen or name == qid:
            continue
        seen.add(qid)
        result.append({
            "qid": qid, "name": name[:255], "description": (_binding(row, "dishDescription") or "")[:1000] or None,
            "cuisine": (_binding(row, "cuisineLabel") or "International")[:128],
            "country_code": (_binding(row, "countryCode") or "")[:2].upper() or None,
            "country_name": _binding(row, "countryLabel"),
            "commons_title": title, "source_url": f"https://www.wikidata.org/wiki/{qid}",
        })
    return result


def _strip_html(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    cleaned = re.sub(r"<[^>]+>", " ", html.unescape(value))
    return re.sub(r"\s+", " ", cleaned).strip()[:500] or None


def _metadata_value(metadata: Dict[str, Any], key: str) -> Optional[str]:
    value = metadata.get(key, {}).get("value")
    return str(value) if value else None


def normalize_commons_page(page: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    info = (page.get("imageinfo") or [None])[0]
    if not info:
        return None
    metadata = info.get("extmetadata") or {}
    raw_license = (_metadata_value(metadata, "LicenseShortName") or "").strip()
    license_name = allowed_license_name(raw_license)
    if not license_name:
        return None
    image_url = info.get("thumburl") or info.get("url")
    if not image_url:
        return None
    return {
        "image_url": image_url, "image_source_url": info.get("descriptionurl") or info.get("url"),
        "image_license": license_name,
        "image_license_url": _metadata_value(metadata, "LicenseUrl"),
        "image_attribution": _strip_html(_metadata_value(metadata, "Artist") or _metadata_value(metadata, "Credit")) or "Wikimedia Commons contributor",
    }


async def fetch_commons_metadata(titles: Iterable[str], *, client=None) -> Dict[str, Dict[str, Any]]:
    unique = list(dict.fromkeys(titles))
    result: Dict[str, Dict[str, Any]] = {}
    async with ExternalHTTPClient("wikimedia-commons-sync", client) as http:
        for index in range(0, len(unique), 50):
            batch = unique[index:index + 50]
            payload = await http.get_json(settings.WIKIMEDIA_API_ENDPOINT, params={
                "action": "query", "format": "json", "formatversion": 2, "prop": "imageinfo",
                "titles": "|".join(batch), "iiprop": "url|extmetadata", "iiurlwidth": 900,
                "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Credit",
            })
            for page in payload.get("query", {}).get("pages", []):
                normalized = normalize_commons_page(page)
                if normalized and page.get("title"):
                    result[page["title"]] = normalized
    return result


def _restaurant_for(cuisine: str, restaurants: List[RestaurantModel], identity: str) -> RestaurantModel:
    lowered = cuisine.lower()
    matches = [restaurant for restaurant in restaurants if restaurant.cuisine.lower() in lowered or lowered in restaurant.cuisine.lower()]
    candidates = matches or restaurants
    offset = int(hashlib.sha256(identity.encode()).hexdigest()[:8], 16) % len(candidates)
    return candidates[offset]


async def fetch_wikidata_food(db: Session, *, wikidata_client=None, commons_client=None) -> List[Dict[str, Any]]:
    restaurants = db.query(RestaurantModel).order_by(RestaurantModel.id).all()
    if not restaurants:
        raise ValueError("Restaurant templates must be seeded before Wikidata synchronization")
    async with ExternalHTTPClient("wikidata-sync", wikidata_client) as http:
        payload = await http.get_json(settings.WIKIDATA_SPARQL_ENDPOINT, params={"query": SPARQL, "format": "json"}, headers={"Accept": "application/sparql-results+json"})
    dishes = parse_wikidata_bindings(payload)
    if not dishes:
        raise ValueError("Wikidata returned no usable dishes")
    commons = await fetch_commons_metadata((dish["commons_title"] for dish in dishes), client=commons_client)
    products = []
    for dish in dishes:
        image = commons.get(dish["commons_title"])
        if not image:
            continue
        restaurant = _restaurant_for(dish["cuisine"], restaurants, dish["qid"])
        values = stable_catalog_values(dish["qid"], "Food", "food")
        products.append({
            "id": f"wikidata_{dish['qid']}", "type": "food", "name": dish["name"],
            "brand": restaurant.name, "category": "Main", "cuisine": dish["cuisine"],
            "description": dish["description"] or f"A {dish['cuisine']} dish represented in Wikidata.",
            "source": "wikidata", "source_id": dish["qid"], "restaurant_id": restaurant.id,
            "country_code": dish["country_code"], "is_fictional": False,
            "source_url": dish["source_url"], **image, **values,
        })
    if not products:
        raise ValueError("No Wikidata dishes had acceptable Commons licensing")
    return products
