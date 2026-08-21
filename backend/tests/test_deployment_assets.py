from pathlib import Path

from backend.app.config import settings
from backend.app.models import Base


ROOT = Path(__file__).resolve().parents[2]


def test_nginx_only_trusts_the_connection_address_for_forwarding():
    nginx = (ROOT / "deploy/nginx.conf").read_text(encoding="utf-8")
    assert "listen 443 ssl" in nginx
    assert "proxy_pass http://127.0.0.1:8000" in nginx
    assert "proxy_set_header X-Forwarded-For $remote_addr;" in nginx
    assert "$proxy_add_x_forwarded_for" not in nginx
    assert "access_log off;" in nginx
    assert "listen [::]:443 ssl" in nginx
    assert "https://__PUBLIC_URL_HOST__" in nginx
    assert "/live/__PUBLIC_IP__/fullchain.pem" in nginx


def test_deployment_scripts_accept_and_bracket_ipv6_only_for_urls():
    https_script = (ROOT / "scripts/enable_https.sh").read_text(encoding="utf-8")
    assert "address.version != 4" not in https_script
    assert 'f"[{address}]" if address.version == 6' in https_script
    setup_script = (ROOT / "scripts/setup_server.sh").read_text(encoding="utf-8")
    assert "IPV6=yes" in setup_script
    assert "fail2ban" in setup_script


def test_uvicorn_is_loopback_only_and_has_no_access_log():
    service = (ROOT / "deploy/impulse.service").read_text(encoding="utf-8")
    assert "--host 127.0.0.1" in service
    assert "--forwarded-allow-ips=127.0.0.1" in service
    assert "--no-access-log" in service
    assert "User=impulse" in service


def test_production_template_has_safe_boundaries_and_blank_secrets():
    template = (ROOT / "deploy/production.env.example").read_text(encoding="utf-8")
    assert "ENVIRONMENT=production" in template
    assert "IMPULSE_DEBUG=false" in template
    assert "DATABASE_URL=sqlite:////opt/impulse/storage/impulse.db" in template
    assert "TRUST_PROXY_HEADERS=true" in template
    assert "ENABLE_LAZY_COUNTRY_SYNC=false" in template
    assert "CORS_ALLOWED_ORIGINS=https://rshukla2.github.io" in template
    for name in (
        "ICECAT_API_ACCESS_TOKEN",
        "ICECAT_CONTENT_ACCESS_TOKEN",
        "MAXMIND_ACCOUNT_ID",
        "MAXMIND_LICENSE_KEY",
    ):
        assert f"{name}=\n" in template


def test_backend_models_contain_no_user_or_order_storage():
    forbidden = {
        "user",
        "users",
        "email",
        "phone",
        "address",
        "payment",
        "card",
        "cart",
        "order",
        "orders",
        "ip_address",
    }
    table_names = {table.name for table in Base.metadata.sorted_tables}
    assert table_names.isdisjoint(forbidden)
    for table in Base.metadata.sorted_tables:
        assert {column.name for column in table.columns}.isdisjoint(forbidden)


def test_mobile_release_declares_only_network_access():
    manifest = (ROOT / "mobile/android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    assert "android.permission.INTERNET" in manifest
    assert 'android:allowBackup="false"' in manifest
    assert "android.permission.ACCESS_FINE_LOCATION" not in manifest
    assert "android.permission.CAMERA" not in manifest
    gradle = (ROOT / "mobile/android/app/build.gradle.kts").read_text(encoding="utf-8")
    assert 'signingConfigs.getByName("debug")' not in gradle


def test_public_privacy_policy_meets_store_delivery_requirements():
    policy = ROOT / "mobile/web/privacy-policy/index.html"
    html = policy.read_text(encoding="utf-8")
    assert "<title>Privacy Policy | Impulse</title>" in html
    assert "Effective date:" in html
    assert "Rishi Shukla" in html
    assert "rishishukla2k@gmail.com" in html
    assert "does not collect or store personal information in a user database" in html
    assert "IP address is not retained" in html
    assert "It is not persisted or transmitted" in html
    assert "CVVs, are never requested" in html
    assert "clear the app's storage" in html
    assert "<script" not in html

    workflow = (ROOT / ".github/workflows/deploy-pages.yml").read_text(
        encoding="utf-8"
    )
    assert "test -f build/web/privacy-policy/index.html" in workflow


def test_no_alternative_production_architecture_is_present():
    forbidden_paths = (
        "Dockerfile",
        "docker-compose.yml",
        "firebase.json",
        "package.json",
        "vercel.json",
    )
    assert all(not (ROOT / name).exists() for name in forbidden_paths)
