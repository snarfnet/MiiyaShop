import os
import sys
import time

import jwt
import requests


KEY_ID = os.environ.get("ASC_KEY_ID", "WDXGY9WX55")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2be0734f-943a-4d61-9dc9-5d9045c46fec")
P8_PATH = os.environ.get("ASC_P8_PATH", "/tmp/asc_key.p8")
MODE = os.environ.get("MODE", "list")


with open(P8_PATH, encoding="utf-8") as key_file:
    P8 = key_file.read()


def make_token():
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        P8,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def api(method, path):
    response = requests.request(
        method,
        f"https://api.appstoreconnect.apple.com/v1{path}",
        headers={"Authorization": f"Bearer {make_token()}"},
        timeout=120,
    )
    try:
        body = response.json()
    except Exception:
        body = {}
    return response, body


def list_certificates():
    response, body = api("GET", "/certificates?limit=200")
    if response.status_code != 200:
        print(f"Certificate list failed: {response.status_code} {response.text[:1000]}")
        sys.exit(1)

    certificates = body.get("data", [])
    for certificate in certificates:
        attrs = certificate.get("attributes", {})
        print(
            f"id={certificate['id']} "
            f"type={attrs.get('certificateType')} "
            f"name={attrs.get('name')} "
            f"serial={attrs.get('serialNumber')} "
            f"expires={attrs.get('expirationDate')}"
        )
    return certificates


def main():
    certificates = list_certificates()
    if MODE != "revoke_oldest_ios_development":
        return

    development = [
        certificate for certificate in certificates
        if certificate.get("attributes", {}).get("certificateType") == "IOS_DEVELOPMENT"
    ]
    if not development:
        print("No IOS_DEVELOPMENT certificates found.")
        return

    development.sort(key=lambda item: item.get("attributes", {}).get("expirationDate") or "")
    target = development[0]
    response, body = api("DELETE", f"/certificates/{target['id']}")
    print(f"Revoked oldest IOS_DEVELOPMENT certificate {target['id']}: {response.status_code}")
    if response.status_code not in (200, 204):
        print(response.text[:1000])
        sys.exit(1)


if __name__ == "__main__":
    main()
