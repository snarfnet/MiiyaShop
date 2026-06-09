import os
import sys
import time

import jwt
import requests


KEY_ID = os.environ.get("ASC_KEY_ID", "WDXGY9WX55")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2be0734f-943a-4d61-9dc9-5d9045c46fec")
BUNDLE_ID = os.environ.get("APP_BUNDLE_ID", "com.tokyonasu.miiyaShop")
APP_VERSION = os.environ.get("APP_VERSION", "1.1")
P8_PATH = os.environ.get("ASC_P8_PATH", "/tmp/asc_key.p8")
EXPECTED_BUILD_NUMBER = os.environ.get("EXPECTED_BUILD_NUMBER", "").strip()
FORCE_RESUBMIT = os.environ.get("FORCE_RESUBMIT", "").lower() in ("1", "true", "yes")
MAX_BUILD_WAIT_ATTEMPTS = int(os.environ.get("MAX_BUILD_WAIT_ATTEMPTS", "90"))

REVIEW_NOTES = """Admin panel password: miiya2026

How to access the admin panel:
1. Open the first screen.
2. Press and hold the main mascot image for 3 seconds.
3. Enter the password above.

This build adds customer-facing features beyond store marketing:
- Visit stamp card and coupon: customers can enter the in-store stamp code once per day to collect visit stamps. After 5 stamps, the app shows a coupon that customers can present at checkout. The store owner can manage the stamp code and coupon text from the admin panel.
- Feature visibility controls: the store owner can show or hide announcements, the stamp card, the shopping memo, and the business calendar from the admin panel.
- Break status: the store owner can set the shop status to open, break, or closed. Each status has its own main image.
- Business calendar: customers can check open and closed days. The store owner can update each date from the admin panel by marking it as open (〇) or closed (✖).
- Question form: customers can send questions to the store from the app. The store owner can read, mark, and delete received messages in the admin panel.
- Store announcements: the store owner can send announcements from the admin panel. Customers can see these announcements in the app and receive local notifications when the app is active with notification permission.
- Shopping memo: customers can create a personal shopping memo and add recommended products to it."""

REVIEW_CONTACT = {
    "contactFirstName": "Tokyo",
    "contactLastName": "Nasu",
    "contactEmail": "tokyonasu@yahoo.co.jp",
    "contactPhone": "+81 80-2368-9194",
}


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


def headers():
    return {"Authorization": f"Bearer {make_token()}", "Content-Type": "application/json"}


def api(method, path, **kwargs):
    for _ in range(8):
        response = requests.request(
            method,
            f"https://api.appstoreconnect.apple.com/v1{path}",
            headers=headers(),
            timeout=120,
            **kwargs,
        )
        if response.status_code not in (401, 429, 500, 502, 503, 504):
            return response
        time.sleep(20)
    return response


def api_json(method, path, **kwargs):
    response = api(method, path, **kwargs)
    try:
        body = response.json()
    except Exception:
        body = {}
    return response, body


def list_all(path):
    rows = []
    next_path = path
    while next_path:
        response, body = api_json("GET", next_path)
        if response.status_code != 200:
            raise RuntimeError(f"List failed {response.status_code}: {response.text[:500]}")
        rows.extend(body.get("data", []))
        next_url = body.get("links", {}).get("next")
        next_path = next_url.split("/v1", 1)[1] if next_url else None
    return rows


def fail(message):
    print(message)
    sys.exit(1)


def find_app_id():
    response, body = api_json("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")
    if response.status_code != 200 or not body.get("data"):
        fail(f"App not found for bundle ID {BUNDLE_ID}: {response.status_code} {response.text[:500]}")
    app_id = body["data"][0]["id"]
    print(f"App ID: {app_id}")
    return app_id


def find_version(app_id):
    versions = list_all(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=200")
    for version in versions:
        attrs = version.get("attributes", {})
        if attrs.get("versionString") == APP_VERSION:
            print(f"Version {APP_VERSION}: {version['id']} state={attrs.get('appStoreState')}")
            return version["id"], attrs.get("appStoreState")
    return create_version(app_id)


def create_version(app_id):
    response, body = api_json(
        "POST",
        "/appStoreVersions",
        json={
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": APP_VERSION,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        },
    )
    print(f"Create version {APP_VERSION}: {response.status_code}")
    if response.status_code != 201:
        fail(response.text[:1000])
    version = body["data"]
    attrs = version.get("attributes", {})
    print(f"Version {APP_VERSION}: {version['id']} state={attrs.get('appStoreState')}")
    return version["id"], attrs.get("appStoreState")


def wait_for_latest_valid_build(app_id):
    if EXPECTED_BUILD_NUMBER:
        print(f"Waiting for valid processed build {EXPECTED_BUILD_NUMBER}...")
    else:
        print("Waiting for latest valid processed build...")
    for attempt in range(MAX_BUILD_WAIT_ATTEMPTS):
        response, body = api_json(
            "GET",
            f"/builds?filter[app]={app_id}&filter[processingState]=VALID&sort=-uploadedDate&limit=10",
        )
        if response.status_code == 200:
            builds = body.get("data", [])
            if EXPECTED_BUILD_NUMBER:
                builds = [
                    build for build in builds
                    if build.get("attributes", {}).get("version") == EXPECTED_BUILD_NUMBER
                ]
            if builds:
                build = builds[0]
                attrs = build.get("attributes", {})
                print(f"Build ready: id={build['id']} version={attrs.get('version')} uploaded={attrs.get('uploadedDate')}")
                return build["id"]
        print(f"  still processing... {attempt + 1}/{MAX_BUILD_WAIT_ATTEMPTS}")
        time.sleep(30)
    if EXPECTED_BUILD_NUMBER:
        print_recent_builds(app_id)
        fail(f"Valid processed build {EXPECTED_BUILD_NUMBER} was not found.")
    print_recent_builds(app_id)
    fail("No valid processed build found.")


def print_recent_builds(app_id):
    response, body = api_json("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=20")
    print("Recent builds:")
    if response.status_code != 200:
        print(f"Could not list builds: {response.status_code} {response.text[:500]}")
        return
    for build in body.get("data", []):
        attrs = build.get("attributes", {})
        print(
            "  "
            f"version={attrs.get('version')} "
            f"processingState={attrs.get('processingState')} "
            f"uploaded={attrs.get('uploadedDate')}"
        )


def update_review_detail(version_id):
    attrs = {
        **REVIEW_CONTACT,
        "demoAccountRequired": True,
        "demoAccountName": "Admin panel",
        "demoAccountPassword": "miiya2026",
        "notes": REVIEW_NOTES,
    }
    response, body = api_json("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if response.status_code == 200 and body.get("data"):
        detail_id = body["data"]["id"]
        response = api(
            "PATCH",
            f"/appStoreReviewDetails/{detail_id}",
            json={"data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}},
        )
        print(f"Review detail update: {response.status_code}")
        if response.status_code not in (200, 201):
            fail(response.text[:1000])
        return

    response = api(
        "POST",
        "/appStoreReviewDetails",
        json={
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                },
            }
        },
    )
    print(f"Review detail create: {response.status_code}")
    if response.status_code not in (200, 201):
        fail(response.text[:1000])


def assign_build(version_id, build_id):
    response = api(
        "PATCH",
        f"/builds/{build_id}",
        json={"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}},
    )
    print(f"Export compliance: {response.status_code}")

    response = api(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        json={"data": {"type": "builds", "id": build_id}},
    )
    print(f"Build assigned: {response.status_code}")
    if response.status_code not in (200, 204):
        fail(response.text[:1000])


def cancel_blocking_submissions(app_id):
    states = ("UNRESOLVED_ISSUES", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW")
    for state in states:
        response, body = api_json("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]={state}&limit=200")
        if response.status_code != 200:
            continue
        for submission in body.get("data", []):
            submission_id = submission["id"]
            response = api(
                "PATCH",
                f"/reviewSubmissions/{submission_id}",
                json={
                    "data": {
                        "type": "reviewSubmissions",
                        "id": submission_id,
                        "attributes": {"canceled": True},
                    }
                },
            )
            print(f"Canceled review submission {submission_id}: {response.status_code}")
    time.sleep(20)


def submit_for_review(app_id, version_id):
    response, body = api_json(
        "POST",
        "/reviewSubmissions",
        json={
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )
    if response.status_code != 201:
        fail(f"Review submission create failed {response.status_code}: {response.text[:1000]}")
    submission_id = body["data"]["id"]
    print(f"Review submission: {submission_id}")

    added = False
    for attempt in range(20):
        response = api(
            "POST",
            "/reviewSubmissionItems",
            json={
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )
        print(f"Add review item {attempt + 1}/20: {response.status_code}")
        if response.status_code == 201:
            added = True
            break
        time.sleep(30)
    if not added:
        fail("Could not add app version to review submission.")

    response, body = api_json(
        "PATCH",
        f"/reviewSubmissions/{submission_id}",
        json={"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}},
    )
    if response.status_code != 200:
        fail(f"Review submit failed {response.status_code}: {response.text[:1000]}")
    print(f"Submitted for App Review. State: {body['data']['attributes'].get('state')}")


def main():
    app_id = find_app_id()
    version_id, state = find_version(app_id)
    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW") and not FORCE_RESUBMIT:
        print(f"Already submitted: {state}")
        return

    build_id = wait_for_latest_valid_build(app_id)
    update_review_detail(version_id)
    cancel_blocking_submissions(app_id)
    assign_build(version_id, build_id)
    submit_for_review(app_id, version_id)


if __name__ == "__main__":
    main()
