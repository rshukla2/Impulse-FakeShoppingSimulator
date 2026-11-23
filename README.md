# Impulse - Fake Shopping Simulator

**Live demo:** <https://rshukla2.github.io/Impulse-FakeShoppingSimulator/>

Impulse is a Flutter app for simulated shopping. You browse food, groceries,
general products and some fictional ones, place fake orders, and see how much
money you "saved" by not buying anything. There are no accounts, payments or
deliveries.

This repository is a **portfolio demo**. The app runs entirely in the browser
from a bundled catalog snapshot. It has no backend and calls no APIs at runtime.

## What's inside

- **Flutter** app for web, Android and iOS (`mobile/`), using Riverpod for state
  and Dio for data access.
- **Catalog snapshot** (`mobile/assets/static_demo/`): 1,000 shopping products,
  plus groceries, dishes and restaurants for 8 regions (US, IN, GB, JP, DE, FR,
  CA, AU), and exchange rates for 249 countries. The data was originally
  collected from Open Icecat, Open Food Facts, Wikidata/Wikimedia Commons and
  Frankfurter (ECB rates), and frozen in November 2026.
- **`StaticDemoInterceptor`** (`mobile/lib/core/network/static_demo_interceptor.dart`)
  answers every catalog request in the app itself. It handles filtering,
  search, pagination and currency conversion, so the UI code is the same as
  when a REST API served it.
- Local cart, simulated checkout with masked card and address profiles kept in
  encrypted on-device storage, order history, and a "money saved" tracker.

## Run it locally

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

## Checks

```bash
cd mobile
flutter analyze
flutter test
```

Every push to `main` builds the web app and publishes it to GitHub Pages
(`.github/workflows/deploy-pages.yml`).

## Privacy

Nothing leaves your device except the product image downloads from their
public hosts. See the
[privacy policy](https://rshukla2.github.io/Impulse-FakeShoppingSimulator/privacy-policy/).

## Credits and license

Data and image credits are listed in [docs/licenses.md](docs/licenses.md) and
on the app's Credits screen. The code is MIT licensed.
