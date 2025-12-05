#!/usr/bin/env python3
"""
Complete TestFlight deployment pipeline.
Builds, uploads, waits for processing, distributes to testers, and updates server version.
"""

import subprocess
import requests
import sys
import time
import os

# ============================================================================
# Configuration
# ============================================================================

ISSUER_ID = "2e5cbf08-b1a5-4857-b013-30fb6eec002e"
KEY_ID = "TF37RTPFSZ"
BUNDLE_ID = "com.miso.noobtest"
APP_ID = "6753210931"
PROJECT_NAME = "NoobTest"

APP_STORE_API = "https://api.appstoreconnect.apple.com/v1"
SERVER_URL = "http://185.96.221.52:8080"

# ============================================================================
# Utility Functions
# ============================================================================

def run_command(cmd, description, capture=False, show_output=True):
    """Run a shell command with nice formatting."""
    print(f"   Running: {' '.join(cmd[:3])}..." if len(cmd) > 3 else f"   Running: {' '.join(cmd)}")

    if capture:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"   Error: {result.stderr}")
            return None
        return result.stdout.strip()
    else:
        result = subprocess.run(cmd)
        return result.returncode == 0

def generate_jwt_token():
    """Generate a JWT token for App Store Connect API."""
    result = subprocess.run(
        ["xcrun", "altool", "--generate-jwt", "--apiKey", KEY_ID, "--apiIssuer", ISSUER_ID],
        capture_output=True, text=True
    )
    output = result.stderr.strip()
    lines = output.split('\n')
    return lines[-1].strip()

def api_request(method, endpoint, token, data=None):
    """Make an API request to App Store Connect."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    url = f"{APP_STORE_API}{endpoint}"

    if method == "GET":
        response = requests.get(url, headers=headers)
    elif method == "POST":
        response = requests.post(url, headers=headers, json=data)
    else:
        raise ValueError(f"Unknown method: {method}")

    if response.status_code >= 400:
        print(f"   API Error {response.status_code}: {response.text}")
        return None

    return response.json() if response.text else {}

# ============================================================================
# Build Pipeline Steps
# ============================================================================

def sync_tunables():
    """Sync tunable constants to iOS bundle."""
    print("\n" + "=" * 60)
    print("Step 1: Syncing tunables")
    print("=" * 60)

    result = subprocess.run(["./sync-tunables.sh"], capture_output=True, text=True)
    if result.returncode == 0:
        print("   Synced live-constants.json to iOS bundle")
        return True
    else:
        print(f"   Error: {result.stderr}")
        return False

def increment_build_number():
    """Increment the build number using agvtool."""
    print("\n" + "=" * 60)
    print("Step 2: Incrementing build number")
    print("=" * 60)

    subprocess.run(["agvtool", "next-version", "-all"], capture_output=True)
    result = subprocess.run(["agvtool", "what-version", "-terse"], capture_output=True, text=True)
    build_number = result.stdout.strip()
    print(f"   New build number: {build_number}")
    return build_number

def build_and_archive():
    """Build and archive the app."""
    print("\n" + "=" * 60)
    print("Step 3: Building and archiving")
    print("=" * 60)

    cmd = [
        "xcodebuild",
        "-project", f"{PROJECT_NAME}.xcodeproj",
        "-scheme", PROJECT_NAME,
        "-archivePath", f"/tmp/{PROJECT_NAME}.xcarchive",
        "-allowProvisioningUpdates",
        "LD=clang",
        "archive"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if "ARCHIVE SUCCEEDED" in result.stdout or result.returncode == 0:
        print("   Archive complete")
        return True
    else:
        print(f"   Archive failed!")
        # Show last few lines of output
        lines = result.stdout.strip().split('\n')
        for line in lines[-10:]:
            print(f"   {line}")
        return False

def export_for_app_store():
    """Export the archive for App Store distribution."""
    print("\n" + "=" * 60)
    print("Step 4: Exporting for App Store")
    print("=" * 60)

    export_path = f"/tmp/{PROJECT_NAME}Export"

    # Clean up previous export
    subprocess.run(["rm", "-rf", export_path], capture_output=True)

    cmd = [
        "xcodebuild",
        "-exportArchive",
        "-archivePath", f"/tmp/{PROJECT_NAME}.xcarchive",
        "-exportPath", export_path,
        "-exportOptionsPlist", "ExportOptions.plist",
        "-allowProvisioningUpdates"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if "EXPORT SUCCEEDED" in result.stdout or result.returncode == 0:
        print("   Export complete")
        return f"{export_path}/{PROJECT_NAME}.ipa"
    else:
        print(f"   Export failed!")
        lines = result.stdout.strip().split('\n')
        for line in lines[-10:]:
            print(f"   {line}")
        return None

def upload_to_testflight(ipa_path):
    """Upload the IPA to TestFlight."""
    print("\n" + "=" * 60)
    print("Step 5: Uploading to TestFlight")
    print("=" * 60)

    cmd = [
        "xcrun", "altool",
        "--upload-app",
        "--type", "ios",
        "--file", ipa_path,
        "--apiKey", KEY_ID,
        "--apiIssuer", ISSUER_ID
    ]

    print("   Uploading... (this may take a minute)")
    result = subprocess.run(cmd, capture_output=True, text=True)

    # altool outputs to stderr
    output = result.stderr + result.stdout

    if "No errors uploading" in output or result.returncode == 0:
        print("   Upload complete")
        return True
    else:
        print(f"   Upload failed!")
        print(f"   {output}")
        return False

def wait_for_processing(build_number, max_wait=1200, interval=30):
    """Wait for Apple to finish processing the build."""
    print("\n" + "=" * 60)
    print(f"Step 6: Waiting for Apple to process build {build_number}")
    print("=" * 60)
    print("   (This typically takes 5-15 minutes)")

    token = generate_jwt_token()
    elapsed = 0

    while elapsed < max_wait:
        result = api_request(
            "GET",
            f"/builds?filter[app]={APP_ID}&filter[version]={build_number}&limit=1",
            token
        )

        if result and result.get("data"):
            status = result["data"][0]["attributes"].get("processingState", "UNKNOWN")
            print(f"   Status: {status} (elapsed: {elapsed}s)")

            if status == "VALID":
                print("   Build is ready!")
                return True
            elif status == "INVALID":
                print("   Build is invalid!")
                return False
        else:
            print(f"   Build not found yet (elapsed: {elapsed}s)")

        time.sleep(interval)
        elapsed += interval

    print("   Timeout waiting for processing!")
    return False

def distribute_to_testers(token):
    """Add the build to the external beta group and submit for review."""
    print("\n" + "=" * 60)
    print("Step 7: Distributing to external testers")
    print("=" * 60)

    # Get beta groups
    print("   Getting beta groups...")
    groups_result = api_request("GET", f"/apps/{APP_ID}/betaGroups", token)

    if not groups_result or not groups_result.get("data"):
        print("   No beta groups found!")
        return None

    # Find external group
    external_group = None
    for g in groups_result["data"]:
        attrs = g.get("attributes", {})
        if not attrs.get("isInternalGroup", False):
            external_group = g
            break

    if not external_group:
        print("   No external beta group found!")
        return None

    group_name = external_group["attributes"]["name"]
    group_id = external_group["id"]
    print(f"   Target group: {group_name}")

    # Get latest build
    print("   Getting latest build from Apple...")
    build_result = api_request(
        "GET",
        f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=1",
        token
    )

    if not build_result or not build_result.get("data"):
        print("   No builds found!")
        return None

    build = build_result["data"][0]
    build_id = build["id"]
    build_number = build["attributes"].get("version", "?")
    print(f"   Latest build: {build_number}")

    # Add build to group
    print(f"   Adding build to {group_name}...")
    add_data = {
        "data": [{"type": "builds", "id": build_id}]
    }
    add_result = api_request("POST", f"/betaGroups/{group_id}/relationships/builds", token, add_data)

    if add_result is None:
        print("   Failed to add build to group!")
        return None
    print("   Build added to group")

    # Check/submit for beta review
    print("   Checking beta review status...")
    review_result = api_request("GET", f"/builds/{build_id}/betaAppReviewSubmission", token)

    if review_result and review_result.get("data"):
        review_status = review_result["data"]["attributes"].get("betaReviewState")
        print(f"   Already submitted: {review_status}")
    else:
        print("   Submitting for Beta App Review...")
        submit_data = {
            "data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {
                    "build": {
                        "data": {"type": "builds", "id": build_id}
                    }
                }
            }
        }
        submit_result = api_request("POST", "/betaAppReviewSubmissions", token, submit_data)
        if submit_result and submit_result.get("data"):
            review_status = submit_result["data"]["attributes"].get("betaReviewState")
            print(f"   Submitted! Status: {review_status}")
        else:
            print("   Failed to submit for review (may need manual submission)")

    print("   Distribution complete!")
    return int(build_number)

def update_server_version(build_number):
    """Update the server's LATEST_BUILD to match the deployed build."""
    print("\n" + "=" * 60)
    print(f"Step 8: Updating server version to {build_number}")
    print("=" * 60)

    # Update remote .env file via SSH
    cmd = [
        "ssh", "microserver@185.96.221.52",
        f"sed -i '' 's/^LATEST_BUILD=.*/LATEST_BUILD={build_number}/' ~/firefly-server/.env"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"   Failed to update .env: {result.stderr}")
        return False

    # Restart server to pick up new config
    print("   Restarting server...")
    restart_cmd = [
        "ssh", "microserver@185.96.221.52",
        "cd ~/firefly-server && ./stop.sh && ./start.sh"
    ]

    result = subprocess.run(restart_cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"   Failed to restart server: {result.stderr}")
        return False

    # Verify
    print("   Verifying...")
    try:
        response = requests.get(f"{SERVER_URL}/api/version", timeout=5)
        data = response.json()
        server_build = data.get("latest_build", 0)

        if server_build == build_number:
            print(f"   Server now reports build {server_build}")
            return True
        else:
            print(f"   Warning: Server reports {server_build}, expected {build_number}")
            return False
    except Exception as e:
        print(f"   Failed to verify: {e}")
        return False

# ============================================================================
# Main Pipeline
# ============================================================================

def main():
    print("=" * 60)
    print("TestFlight Deployment Pipeline")
    print("=" * 60)

    # Change to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"Working directory: {script_dir}")

    # Step 1: Sync tunables
    if not sync_tunables():
        print("\nFailed at Step 1!")
        sys.exit(1)

    # Step 2: Increment build number
    build_number = increment_build_number()
    if not build_number:
        print("\nFailed at Step 2!")
        sys.exit(1)

    # Step 3: Build and archive
    if not build_and_archive():
        print("\nFailed at Step 3!")
        sys.exit(1)

    # Step 4: Export for App Store
    ipa_path = export_for_app_store()
    if not ipa_path:
        print("\nFailed at Step 4!")
        sys.exit(1)

    # Step 5: Upload to TestFlight
    if not upload_to_testflight(ipa_path):
        print("\nFailed at Step 5!")
        sys.exit(1)

    # Step 6: Wait for processing
    if not wait_for_processing(build_number):
        print("\nFailed at Step 6!")
        sys.exit(1)

    # Step 7: Distribute to testers
    token = generate_jwt_token()
    confirmed_build = distribute_to_testers(token)
    if not confirmed_build:
        print("\nFailed at Step 7!")
        sys.exit(1)

    # Step 8: Update server version
    if not update_server_version(confirmed_build):
        print("\nWarning: Failed to update server version automatically.")
        print(f"Please manually update LATEST_BUILD={confirmed_build} on the server.")

    # Done!
    print("\n" + "=" * 60)
    print("Deployment Complete!")
    print("=" * 60)
    print(f"Build {confirmed_build} is now available to external testers.")
    print(f"Server version updated to {confirmed_build}.")

if __name__ == "__main__":
    main()
