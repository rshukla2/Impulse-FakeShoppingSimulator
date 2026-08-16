# HTTPS without a domain

Impulse uses a publicly trusted Let's Encrypt certificate for the Droplet's
public IP; no domain purchase is required. Let's Encrypt made IP-address
certificates generally available for both IPv4 and IPv6 in 2026. They use the
`shortlived` profile and are valid for six days, so reliable automatic renewal
is essential.

## Initial certificate

`setup_server.sh` installs the current snap release of Certbot and serves only
the ACME webroot on port 80. Certbot 5.4 or newer is required. Request and
install the certificate with:

```bash
cd /opt/impulse
sudo ./scripts/enable_https.sh 'RAW_IPV6_WITHOUT_BRACKETS' CONTACT_EMAIL
```

For a non-trusted staging rehearsal only:

```bash
sudo IMPULSE_CERTBOT_STAGING=true ./scripts/enable_https.sh 'RAW_IPV6_WITHOUT_BRACKETS' CONTACT_EMAIL
```

The script uses the currently supported webroot form:

```bash
certbot certonly --preferred-profile shortlived \
  --webroot --webroot-path /var/www/certbot \
  --ip-address RAW_IPV6_WITHOUT_BRACKETS
```

It then renders [nginx.conf](../deploy/nginx.conf), verifies it with `nginx -t`,
and reloads nginx. Certbot's nginx installer does not currently install IP
certificates, which is why this explicit two-step flow is used.

## Certificate locations and nginx

Certbot maintains these symlinks:

```text
/etc/letsencrypt/live/RAW_IPV6/fullchain.pem
/etc/letsencrypt/live/RAW_IPV6/privkey.pem
```

The production nginx configuration references those paths, redirects HTTP to
HTTPS (except the ACME challenge path), and proxies HTTPS to loopback Uvicorn.
Never copy the private key into the repository.

## Automatic renewal

`impulse-certbot-renew.timer` runs twice daily with a randomized delay. Certbot
renews only when due. A hook installed at
`/etc/letsencrypt/renewal-hooks/deploy/impulse-reload-nginx` first validates and
then reloads nginx after any successful renewal, including renewal by Certbot's
snap timer.

```bash
systemctl status impulse-certbot-renew.timer
systemctl list-timers impulse-certbot-renew.timer
journalctl -u impulse-certbot-renew
```

Test the renewal path after issuance:

```bash
sudo /snap/bin/certbot renew --dry-run --run-deploy-hooks
```

Verify the public endpoint and certificate:

```bash
curl --globoff --fail 'https://[PUBLIC_IPV6]/health'
openssl s_client -connect '[PUBLIC_IPV6]:443' -verify_ip PUBLIC_IPV6 </dev/null
```

Monitor renewal failures: a six-day certificate leaves little room for an
unnoticed outage. The official references are the [Let's Encrypt IP certificate
instructions](https://letsencrypt.org/2026/03/11/shorter-certs-certbot.html)
and [Certbot documentation](https://eff-certbot.readthedocs.io/en/stable/using.html).
