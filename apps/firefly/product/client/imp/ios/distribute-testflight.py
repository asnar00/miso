#!/usr/bin/env python3
"""
Automatically distribute the latest TestFlight build to an external beta group.
Uses the App Store Connect API with JWT authentication.
"""

import subprocess
import requests
import sys

# Configuration
ISSUER_ID = "2e5cbf08-b1a5-4857-b013-30fb6eec002e"
KEY_ID = "TF37RTPFSZ"
BUNDLE_ID = "com.miso.noobtest"

BASE_URL = "https://api.appstoreconnect.apple.com/v1"

def generate_token():
    """Generate a JWT token using altool (more reliable than PyJWT)."""
    result = subprocess.run(
        ["xcrun", "altool", "--generate-jwt", "--apiKey", KEY_ID, "--apiIssuer", ISSUER_ID],
        capture_output=True, text=True
    )
    # altool outputs to stderr, token is on the last non-empty line
    output = result.stderr.strip()
    lines = output.split('\n')
    token = lines[-1].strip()
    return token

def api_request(method, endpoint, token, data=None):
    """Make an API request to App Store Connect."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    url = f"{BASE_URL}{endpoint}"
    
    if method == "GET":
        response = requests.get(url, headers=headers)
    elif method == "POST":
        response = requests.post(url, headers=headers, json=data)
    else:
        raise ValueError(f"Unknown method: {method}")
    
    if response.status_code >= 400:
        print(f"Error {response.status_code}: {response.text}")
        return None
    
    return response.json() if response.text else {}

def get_app_id(token):
    """Get the app ID for our bundle identifier."""
    result = api_request("GET", f"/apps?filter[bundleId]={BUNDLE_ID}", token)
    if result and result.get("data"):
        return result["data"][0]["id"]
    return None

def get_beta_groups(token, app_id):
    """Get all beta groups for the app."""
    result = api_request("GET", f"/apps/{app_id}/betaGroups", token)
    if result and result.get("data"):
        return result["data"]
    return []

def get_latest_build(token, app_id):
    """Get the most recent build for the app."""
    result = api_request("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=1", token)
    if result and result.get("data"):
        build = result["data"][0]
        return build
    return None

def add_build_to_group(token, build_id, group_id):
    """Add a build to a beta group."""
    data = {
        "data": [
            {
                "type": "builds",
                "id": build_id
            }
        ]
    }
    result = api_request("POST", f"/betaGroups/{group_id}/relationships/builds", token, data)
    return result is not None

def get_beta_review_status(token, build_id):
    """Check if a build has been submitted for beta review."""
    result = api_request("GET", f"/builds/{build_id}/betaAppReviewSubmission", token)
    if result and result.get("data"):
        return result["data"]["attributes"].get("betaReviewState")
    return None

def submit_for_beta_review(token, build_id):
    """Submit a build for Beta App Review (required for external testers)."""
    data = {
        "data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {
                "build": {
                    "data": {
                        "type": "builds",
                        "id": build_id
                    }
                }
            }
        }
    }
    result = api_request("POST", "/betaAppReviewSubmissions", token, data)
    if result and result.get("data"):
        return result["data"]["attributes"].get("betaReviewState")
    return None

def main():
    print("🔐 Generating JWT token...")
    token = generate_token()
    
    print("📱 Getting app ID...")
    app_id = get_app_id(token)
    if not app_id:
        print("❌ Could not find app!")
        sys.exit(1)
    print(f"   App ID: {app_id}")
    
    print("👥 Getting beta groups...")
    groups = get_beta_groups(token, app_id)
    if not groups:
        print("❌ No beta groups found!")
        sys.exit(1)
    
    print("   Available groups:")
    external_group = None
    for g in groups:
        attrs = g.get("attributes", {})
        name = attrs.get("name", "Unknown")
        is_internal = attrs.get("isInternalGroup", False)
        group_type = "internal" if is_internal else "EXTERNAL"
        print(f"   - {name} ({group_type}) [ID: {g['id']}]")
        
        # Pick the first external group
        if not is_internal and external_group is None:
            external_group = g
    
    if not external_group:
        print("❌ No external beta group found!")
        sys.exit(1)
    
    group_name = external_group["attributes"]["name"]
    group_id = external_group["id"]
    print(f"\n📦 Will distribute to: {group_name}")
    
    print("🔍 Getting latest build...")
    build = get_latest_build(token, app_id)
    if not build:
        print("❌ No builds found!")
        sys.exit(1)
    
    build_id = build["id"]
    attrs = build.get("attributes", {})
    version = attrs.get("version", "?")
    processing = attrs.get("processingState", "?")
    print(f"   Latest build: {version} (state: {processing})")
    
    if processing != "VALID":
        print(f"⏳ Build is still processing ({processing}). Try again in a few minutes.")
        sys.exit(1)
    
    print(f"🚀 Adding build {version} to {group_name}...")
    if not add_build_to_group(token, build_id, group_id):
        print("❌ Failed to add build to group.")
        sys.exit(1)
    print("   ✓ Build added to group")

    # Check if already submitted for beta review
    print("📋 Checking beta review status...")
    review_status = get_beta_review_status(token, build_id)

    if review_status:
        print(f"   Already submitted: {review_status}")
    else:
        print("   Submitting for Beta App Review (required for external testers)...")
        review_status = submit_for_beta_review(token, build_id)
        if review_status:
            print(f"   ✓ Submitted! Status: {review_status}")
        else:
            print("   ⚠️ Failed to submit for review. You may need to do this manually.")

    print("\n✅ Success! Build distributed to external testers.")
    if review_status == "WAITING_FOR_REVIEW":
        print("   Note: Build is waiting for Apple's Beta App Review.")
        print("   This typically takes <24 hours for the first build, then instant for subsequent builds.")
    elif review_status == "APPROVED":
        print("   Build is approved and available to testers now!")

if __name__ == "__main__":
    main()
