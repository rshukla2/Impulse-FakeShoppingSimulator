"""Open Icecat batch-index synchronization and normalization."""

from __future__ import annotations

import asyncio
import csv
import gzip
import math
import tempfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit

from backend.app.config import settings
from backend.app.services.external_http import ExternalAPIError, ExternalHTTPClient
from backend.app.services.pricing_rules import stable_catalog_values


CATEGORIES = ("Electronics", "Computers", "Gaming", "Appliances", "Home", "Accessories", "Toys", "Office", "Fashion")
CATEGORY_WORDS = {
    "Computers": ("computer", "notebook", "laptop", "server", "monitor", "printer"),
    "Gaming": ("gaming", "game", "console", "playstation", "xbox", "nintendo"),
    "Appliances": ("vacuum", "washing", "refrigerator", "oven", "dishwasher", "appliance"),
    "Home": ("furniture", "lamp", "mattress", "kitchen", "home"),
    "Accessories": ("mouse", "keyboard", "cable", "adapter", "charger", "case", "headset"),
    "Toys": ("toy", "lego", "doll", "puzzle"),
    "Office": ("office", "projector", "scanner", "shredder"),
    "Fashion": ("watch", "shoe", "clothing", "jacket", "bag"),
}


def icecat_auth_headers(*, include_content: bool = False) -> Dict[str, str]:
    """Build Icecat's header-based token authentication without logging it."""
    if not settings.ICECAT_API_ACCESS_TOKEN:
        raise ExternalAPIError(
            "credentials_missing", "Icecat API access token is not configured"
        )
    headers = {"Api-Token": settings.ICECAT_API_ACCESS_TOKEN}
    if include_content and settings.ICECAT_CONTENT_ACCESS_TOKEN:
        headers["Content-Token"] = settings.ICECAT_CONTENT_ACCESS_TOKEN
    return headers


def sanitize_icecat_url(value: Optional[str]) -> Optional[str]:
    """Prevent Icecat access tokens from entering SQLite or API responses."""
    if not value:
        return value
    parts = urlsplit(value)
    safe_query = [
        (key, item)
        for key, item in parse_qsl(parts.query, keep_blank_values=True)
        if key.lower().replace("-", "_")
        not in {"content_token", "api_token", "app_key"}
    ]
    return urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urlencode(safe_query), parts.fragment)
    )


def infer_category(*values: Optional[str]) -> str:
    text = " ".join(value or "" for value in values).lower()
    for category, keywords in CATEGORY_WORDS.items():
        if any(word in text for word in keywords):
            return category
    return "Electronics"


def _first(row: Dict[str, str], *names: str) -> Optional[str]:
    lowered = {str(key).lower(): value for key, value in row.items()}
    for name in names:
        value = lowered.get(name.lower())
        if value and str(value).strip():
            return str(value).strip()
    return None


def select_balanced_index_rows(rows: Iterable[Dict[str, str]], target: int) -> List[Dict[str, str]]:
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    overflow: List[Dict[str, str]] = []
    per_category = max(1, (target + len(CATEGORIES) - 1) // len(CATEGORIES))
    seen = set()
    for row in rows:
        source_id = _first(row, "product_id", "icecat_id", "productid")
        name = _first(row, "model_name", "product_name", "name")
        if not source_id or not name or source_id in seen:
            continue
        seen.add(source_id)
        category = infer_category(_first(row, "category", "category_name"), name)
        row = dict(row)
        row["_category"] = category
        if len(buckets[category]) >= per_category:
            if len(overflow) < target:
                overflow.append(row)
            if len(seen) >= target * 4:
                break
            continue
        buckets[category].append(row)
        if (sum(map(len, buckets.values())) >= target and all(buckets[category] for category in CATEGORIES)) or len(seen) >= target * 4:
            break
    selected = []
    for category in CATEGORIES:
        selected.extend(buckets[category])
    if len(selected) < target:
        selected.extend(overflow[:target - len(selected)])
    return selected[:target]


def parse_icecat_index(path: Path, target: int) -> List[Dict[str, str]]:
    with gzip.open(path, "rt", encoding="utf-8-sig", errors="replace", newline="") as source:
        sample = source.read(8192)
        source.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel_tab
        return select_balanced_index_rows(csv.DictReader(source, dialect=dialect), target)


def candidate_target_for(usable_target: int, buffer_percent: int) -> int:
    """Return enough index candidates to meet a usable-product cache target."""
    if usable_target < 1:
        raise ValueError("Icecat target must be at least one product")
    return max(
        usable_target,
        math.ceil(usable_target * (1 + max(0, buffer_percent) / 100)),
    )


def normalize_icecat_xml(content: bytes, fallback: Dict[str, str]) -> Dict[str, Any]:
    root = ET.fromstring(content)
    product = root.find(".//Product") or root
    source_id = str(product.attrib.get("ID") or _first(fallback, "product_id", "icecat_id", "productid"))
    supplier = product.find(".//Supplier")
    category_node = product.find(".//Category")
    description = product.find(".//ProductDescription")
    name = (
        product.attrib.get("Name")
        or (description.attrib.get("ShortDesc") if description is not None else None)
        or _first(fallback, "model_name", "product_name", "name")
    )
    brand = supplier.attrib.get("Name") if supplier is not None else _first(fallback, "supplier_name", "brand")
    category = infer_category(category_node.attrib.get("Name") if category_node is not None else None, name)
    long_description = description.attrib.get("LongDesc") if description is not None else None
    image = sanitize_icecat_url(
        product.attrib.get("HighPic")
        or product.attrib.get("LowPic")
        or _first(fallback, "high_pic", "highpic")
    )
    values = stable_catalog_values(source_id, category, "shopping")
    return {
        "id": f"icecat_{source_id}", "type": "shopping", "name": str(name).strip(),
        "brand": brand, "category": category, "description": long_description,
        "image_url": image, "source": "icecat", "source_id": source_id,
        "is_fictional": False, "image_license": "Open Icecat catalog media",
        "image_attribution": "Open Icecat / product manufacturer", "source_url": urljoin("https://data.icecat.biz/", str(_first(fallback, "path") or "")),
        "image_source_url": image, **values,
    }


def normalize_icecat_index_row(row: Dict[str, str]) -> Dict[str, Any]:
    source_id = str(_first(row, "product_id", "icecat_id", "productid"))
    name = str(_first(row, "model_name", "product_name", "name"))
    category = row.get("_category") or infer_category(_first(row, "category", "category_name"), name)
    image = sanitize_icecat_url(_first(row, "high_pic", "highpic"))
    return {
        "id": f"icecat_{source_id}", "type": "shopping", "name": name,
        "brand": _first(row, "supplier_name", "brand"), "category": category,
        "description": None, "image_url": image, "source": "icecat", "source_id": source_id,
        "is_fictional": False, "image_license": "Open Icecat catalog media",
        "image_attribution": "Open Icecat / product manufacturer", "image_source_url": image,
        "source_url": urljoin("https://data.icecat.biz/", str(_first(row, "path") or "")),
        **stable_catalog_values(source_id, category, "shopping"),
    }


async def sync_icecat_products(*, client=None, target: Optional[int] = None) -> List[Dict[str, Any]]:
    index_headers = icecat_auth_headers()
    product_headers = icecat_auth_headers(include_content=True)
    target = target or settings.ICECAT_TARGET_PRODUCTS
    candidate_target = candidate_target_for(
        target,
        settings.ICECAT_CANDIDATE_BUFFER_PERCENT,
    )
    with tempfile.TemporaryDirectory(prefix="impulse-icecat-") as temp_dir:
        index_path = Path(temp_dir) / "files.index.csv.gz"
        async with ExternalHTTPClient("icecat-sync", client) as http:
            await http.download(
                settings.ICECAT_INDEX_URL, index_path, headers=index_headers
            )
            rows = parse_icecat_index(index_path, candidate_target)
            if not rows:
                raise ValueError("Icecat index contained no usable products")
            semaphore = asyncio.Semaphore(max(1, settings.ICECAT_CONCURRENCY))

            async def detail(row):
                path = _first(row, "path")
                if not path:
                    return normalize_icecat_index_row(row)
                async with semaphore:
                    try:
                        response = await http.request(
                            "GET",
                            urljoin("https://data.icecat.biz/", path),
                            headers=product_headers,
                        )
                        return normalize_icecat_xml(response.content, row)
                    except (ExternalAPIError, ET.ParseError, ValueError):
                        return normalize_icecat_index_row(row)

            products = await asyncio.gather(*(detail(row) for row in rows))

            image_semaphore = asyncio.Semaphore(
                max(1, settings.ICECAT_IMAGE_VALIDATION_CONCURRENCY)
            )

            async def validate_image(product):
                image_url = product.get("image_url")
                if not image_url:
                    return product
                async with image_semaphore:
                    if not await public_image_is_usable(http, image_url):
                        # Keep the original source URL for provenance, but do
                        # not advertise an image the client cannot display.
                        product = dict(product)
                        product["image_url"] = None
                return product

            products = await asyncio.gather(
                *(validate_image(product) for product in products)
            )

    unique = {product["id"]: product for product in products if product.get("name")}
    if len(unique) < target:
        raise ValueError(
            f"Icecat returned {len(unique)} usable products; target is {target}. "
            "Existing cache was retained."
        )
    ranked = sorted(
        unique.values(),
        # Python's sort is stable, so the balanced provider-index selection
        # order is preserved inside the image and no-image partitions.
        key=lambda product: not bool(product.get("image_url")),
    )
    return ranked[:target]


async def public_image_is_usable(http: ExternalHTTPClient, url: str) -> bool:
    """Return whether an unauthenticated Flutter client can fetch an image."""
    parts = urlsplit(url)
    if parts.scheme.lower() != "https" or not parts.netloc:
        return False
    try:
        response = await http.request(
            "HEAD",
            url,
            headers={"Accept": "image/*"},
        )
    except ExternalAPIError:
        return False
    content_type = response.headers.get("content-type", "").lower()
    return content_type.split(";", 1)[0].strip().startswith("image/")
