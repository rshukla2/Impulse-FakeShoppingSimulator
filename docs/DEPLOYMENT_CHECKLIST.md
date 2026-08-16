# Deployment checklist

## GitHub

- [ ] Review the current diff and push `main`.
- [ ] Confirm no `.env`, token, private key, MMDB, SQLite DB, or signing file is tracked.
- [ ] In **Settings → Pages**, choose **GitHub Actions**.
- [ ] Set Actions variable `API_BASE_URL=https://[PUBLIC_IPV6]` (brackets required for IPv6 URLs).
- [ ] Confirm the Pages workflow succeeds.

## DigitalOcean

- [ ] Create an Ubuntu Droplet and confirm password SSH works; use a long, unique password.
- [ ] Point a Cloud Firewall at it with only SSH, 80, and 443 inbound for IPv6.
- [ ] Clone the repository to `/opt/impulse`.
- [ ] Run `sudo ./scripts/setup_server.sh PUBLIC_IP`.
- [ ] Create `/opt/impulse/.env` from `deploy/production.env.example`, owned by `root:impulse` with mode `0640`.
- [ ] Install or download `storage/GeoLite2-Country.mmdb`.
- [ ] Run `sudo ./scripts/deploy_backend.sh`.
- [ ] Run `sudo ./scripts/enable_https.sh PUBLIC_IP CONTACT_EMAIL`.
- [ ] Confirm `nginx -t`, `systemctl is-active impulse`, and `curl --globoff 'https://[PUBLIC_IPV6]/health'`.
- [ ] Run initial Frankfurter, Open Food Facts, Wikidata, and Icecat sync jobs.
- [ ] Confirm all `impulse-*` timers are enabled.
- [ ] Trigger one SQLite backup and confirm `PRAGMA integrity_check` reported success.
- [ ] Test Certbot renewal with `certbot renew --dry-run`.

## Flutter web

- [ ] Confirm `flutter analyze`, `flutter test`, and the release web build pass.
- [ ] Confirm `https://rshukla2.github.io/Impulse-FakeShoppingSimulator/` loads.
- [ ] In browser developer tools, confirm API requests use `https://[PUBLIC_IPV6]`.
- [ ] Confirm `/bootstrap` and catalogs succeed without mixed-content or CORS errors.
- [ ] Smoke-test Login → Home → all five tabs → Cart → Checkout → Orders.

## iOS

- [ ] Set the Apple development team and final signing profile in Xcode.
- [ ] Confirm bundle ID `com.rshukla2.impulse` is available.
- [ ] Build with the production `API_BASE_URL`.
- [ ] Archive and validate through Xcode; verify the live API on a device/TestFlight.

## Android

- [ ] Create an upload keystore outside Git and populate ignored `android/key.properties`.
- [ ] Confirm application ID `com.rshukla2.impulse` is available.
- [ ] Build a signed release AAB with the production `API_BASE_URL`.
- [ ] Verify the live API in an internal-testing install before Play submission.
