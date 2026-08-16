# Impulse API Specification

Base URL: `https://api.yourdomain.com` or `http://localhost:8000`

All endpoints return normalized, localized product and catalog data.

---

### `GET /health`
Returns backend health and confirmation of simulated shopping mode.

---

### `GET /bootstrap`
Detects the user country through the local GeoLite2 Country database and
returns currency information. Direct public IPv4 and IPv6 addresses are
supported. Forwarding headers are used only when `TRUST_PROXY_HEADERS=true`;
invalid/private addresses or a missing/corrupt MMDB fall back to United
States/USD. ISO/CLDR metadata selects the detected country's currency and the
cached Frankfurter rate localizes prices.

**Query Parameters**:
- `country` *(optional)*: ISO country code override (e.g. `IN`, `US`, `GB`, `JP`).

**Response**:
```json
{
  "country_code": "IN",
  "country_name": "India",
  "currency": "INR",
  "currency_symbol": "₹",
  "exchange_rate": 83.25,
  "supported_countries": [
    {"code": "IN", "name": "India", "currency": "INR", "symbol": "₹"},
    {"code": "US", "name": "United States", "currency": "USD", "symbol": "$"}
  ]
}
```

---

### `GET /shopping`
Returns deterministic pages with approximately nine standard products followed
by one fictional product when both matching pools are available.

**Query Parameters**:
- `country` *(optional)*: Country code for localized pricing.
- `category` *(optional)*: Category filter (`Electronics`, `Computers`, `Office`, `Fictional`, etc.).
- `search` *(optional)*: Substring keyword filter.
- `page` *(optional, default 1)*: Page number.
- `limit` *(optional, default 20)*: Page size.

---

### `GET /groceries`
Returns only the detected country's cached products and applicable static
fallbacks. It never fills a page with unrelated countries. A new country may
receive safe fallback results while its first cache refresh runs.

**Query Parameters**:
- `country` *(optional)*: Country code (e.g. `IN` prioritizes Indian pantry/dairy/snacks, `US` prioritizes American groceries).
- `category` *(optional)*: Category filter (`Snacks`, `Beverages`, `Dairy`, `Instant Food`, `Pantry`, `Biscuits`).
- `search` *(optional)*: Substring keyword filter.

---

### `GET /restaurants` & `GET /restaurants/{id}`
Returns fictional restaurants and their menus ranked by regional cuisine preferences.

---

### `GET /food` & `GET /food/{id}`
Returns dishes with regional cuisine weighting.

---

### `GET /categories`
Returns grouped category names across all 3 catalogs.

---

### `GET /search?q=`
Multi-catalog search returning results across shopping, groceries, dishes, and restaurants.

## Maintenance interface

External synchronization is intentionally not exposed as a public HTTP route.
Use `python scripts/sync_all.py`; repeat `--source` or `--country` to narrow the
operation and use `--dry-run` for normalization/credential validation.
