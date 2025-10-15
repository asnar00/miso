#!/usr/bin/env python3
"""
Test script for sign-in authentication endpoints
Tests the complete authentication flow
"""

import requests
import json
import time
import sys

# Configuration
SERVER_URL = "http://185.96.221.52:8080"
TEST_EMAIL = "test@example.com"
TEST_DEVICE_ID = "test-device-12345"

def print_test(name):
    """Print test name"""
    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print('='*60)

def print_pass(message="PASSED"):
    """Print success message"""
    print(f"✅ {message}")

def print_fail(message):
    """Print failure message and exit"""
    print(f"❌ FAILED: {message}")
    sys.exit(1)

def send_code(email):
    """Send verification code to email"""
    url = f"{SERVER_URL}/api/auth/send-code"
    data = {"email": email}
    response = requests.post(url, json=data)
    return response

def verify_code(email, code, device_id):
    """Verify code and authenticate"""
    url = f"{SERVER_URL}/api/auth/verify-code"
    data = {
        "email": email,
        "code": code,
        "device_id": device_id
    }
    response = requests.post(url, json=data)
    return response

def test_send_code_success():
    """Test 1: Send code successfully"""
    print_test("Send Code to Email")

    response = send_code(TEST_EMAIL)

    if response.status_code != 200:
        print_fail(f"Expected status 200, got {response.status_code}")

    data = response.json()
    if data.get('status') != 'success':
        print_fail(f"Expected success status, got {data}")

    print_pass("Code sent successfully")
    return True

def test_missing_email():
    """Test 7: Missing email parameter"""
    print_test("Missing Email Parameter")

    url = f"{SERVER_URL}/api/auth/send-code"
    response = requests.post(url, json={})

    if response.status_code != 400:
        print_fail(f"Expected status 400, got {response.status_code}")

    data = response.json()
    if data.get('status') != 'error':
        print_fail(f"Expected error status, got {data}")

    if 'Email is required' not in data.get('message', ''):
        print_fail(f"Expected 'Email is required' message, got {data}")

    print_pass("Missing email correctly rejected")
    return True

def test_invalid_code():
    """Test 4: Reject invalid code"""
    print_test("Reject Invalid Code")

    # First send a code
    response = send_code(TEST_EMAIL)
    if response.status_code != 200:
        print_fail("Failed to send code")

    # Try to verify with wrong code
    response = verify_code(TEST_EMAIL, "0000", TEST_DEVICE_ID)

    if response.status_code != 401:
        print_fail(f"Expected status 401, got {response.status_code}")

    data = response.json()
    if data.get('status') != 'error':
        print_fail(f"Expected error status, got {data}")

    if 'Invalid verification code' not in data.get('message', ''):
        print_fail(f"Expected 'Invalid verification code' message, got {data}")

    print_pass("Invalid code correctly rejected")
    return True

def test_no_code_requested():
    """Test 6: Reject verification without code request"""
    print_test("Reject Verification Without Request")

    # Try to verify without requesting code first
    fake_email = f"never-requested-{int(time.time())}@example.com"
    response = verify_code(fake_email, "1234", TEST_DEVICE_ID)

    if response.status_code != 404:
        print_fail(f"Expected status 404, got {response.status_code}")

    data = response.json()
    if data.get('status') != 'error':
        print_fail(f"Expected error status, got {data}")

    if 'No verification code found' not in data.get('message', ''):
        print_fail(f"Expected 'No verification code found' message, got {data}")

    print_pass("Verification without request correctly rejected")
    return True

def test_missing_verify_params():
    """Test 8: Missing verification parameters"""
    print_test("Missing Verification Parameters")

    url = f"{SERVER_URL}/api/auth/verify-code"

    # Missing device_id
    response = requests.post(url, json={"email": TEST_EMAIL, "code": "1234"})

    if response.status_code != 400:
        print_fail(f"Expected status 400, got {response.status_code}")

    data = response.json()
    if data.get('status') != 'error':
        print_fail(f"Expected error status, got {data}")

    print_pass("Missing parameters correctly rejected")
    return True

def test_full_flow_interactive():
    """Test 3: Complete authentication flow (requires manual code input)"""
    print_test("Complete Authentication Flow (Interactive)")

    # Send code
    print(f"Sending code to {TEST_EMAIL}...")
    response = send_code(TEST_EMAIL)

    if response.status_code != 200:
        print_fail("Failed to send code")

    print_pass("Code sent")

    # Ask user to input code
    print(f"\n📧 Check email {TEST_EMAIL} for verification code")
    code = input("Enter the 4-digit code: ").strip()

    if len(code) != 4 or not code.isdigit():
        print_fail("Invalid code format")

    # Verify code
    print(f"Verifying code {code}...")
    response = verify_code(TEST_EMAIL, code, TEST_DEVICE_ID)

    if response.status_code != 200:
        data = response.json()
        print_fail(f"Verification failed: {data.get('message', 'Unknown error')}")

    data = response.json()
    if data.get('status') != 'success':
        print_fail(f"Expected success status, got {data}")

    if 'user_id' not in data:
        print_fail(f"Expected user_id in response, got {data}")

    print_pass(f"Authentication successful! User ID: {data['user_id']}")
    return True

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("SIGN-IN AUTHENTICATION TESTS")
    print("="*60)
    print(f"Server: {SERVER_URL}")
    print(f"Test Email: {TEST_EMAIL}")

    try:
        # Non-interactive tests
        test_missing_email()
        test_send_code_success()
        test_invalid_code()
        test_no_code_requested()
        test_missing_verify_params()

        # Interactive test
        print("\n" + "="*60)
        print("INTERACTIVE TESTS")
        print("="*60)
        print("\nThe following test requires manual code input from email.")
        choice = input("Run interactive test? (y/n): ").strip().lower()

        if choice == 'y':
            test_full_flow_interactive()
        else:
            print("⏭️  Skipping interactive test")

        # Summary
        print("\n" + "="*60)
        print("✅ ALL TESTS PASSED")
        print("="*60)

    except requests.exceptions.ConnectionError:
        print_fail(f"Could not connect to server at {SERVER_URL}")
    except KeyboardInterrupt:
        print("\n\n⚠️  Tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_fail(f"Unexpected error: {e}")

if __name__ == '__main__':
    main()
