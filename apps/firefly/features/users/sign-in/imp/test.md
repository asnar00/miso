# sign-in tests
*testing the authentication flow*

## Overview

These tests verify the complete sign-in flow from code generation to user authentication. Tests cover both successful authentication and error cases.

## Test Environment

**Prerequisites**:
- Python server running at http://185.96.221.52:8080
- Database accessible with users table
- Email sending configured (admin@microclub.org)
- Valid email address for receiving test codes

## Test Cases

### Test 1: Send Code to New User

**Purpose**: Verify that a new user can request a verification code

**Steps**:
1. Send POST to `/api/auth/send-code` with a new email address
2. Check response status is "success"
3. Verify user was created in database
4. Verify email was sent with 4-digit code

**Expected Result**:
- Response: `{"status": "success", "message": "Verification code sent"}`
- New user record exists in database with email
- Email received with 4-digit code

### Test 2: Send Code to Existing User

**Purpose**: Verify that existing users can request new codes

**Steps**:
1. Send POST to `/api/auth/send-code` with existing user email
2. Check response status is "success"
3. Verify no duplicate user created
4. Verify email was sent

**Expected Result**:
- Response: `{"status": "success", "message": "Verification code sent"}`
- User count unchanged
- Email received with new code

### Test 3: Verify Valid Code

**Purpose**: Verify that correct codes authenticate users

**Steps**:
1. Request code for test email
2. Extract code from email or server logs
3. Send POST to `/api/auth/verify-code` with {email, code, device_id}
4. Check response status is "success"
5. Verify device_id added to user's device list

**Expected Result**:
- Response: `{"status": "success", "user_id": X, "email": "test@example.com"}`
- User's device_ids array contains the device_id
- Code removed from pending_codes

### Test 4: Reject Invalid Code

**Purpose**: Verify that incorrect codes are rejected

**Steps**:
1. Request code for test email
2. Send POST to `/api/auth/verify-code` with wrong code (e.g., "0000")
3. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "Invalid verification code"}`
- HTTP status code: 401
- User not authenticated

### Test 5: Reject Expired Code

**Purpose**: Verify that codes expire after 10 minutes

**Steps**:
1. Request code for test email
2. Wait 11 minutes (or manually set timestamp in past)
3. Send POST to `/api/auth/verify-code` with the expired code
4. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "No verification code found. Please request a new code."}`
- HTTP status code: 404

### Test 6: Reject Code Verification Without Request

**Purpose**: Verify that codes can't be guessed

**Steps**:
1. Send POST to `/api/auth/verify-code` with email that never requested code
2. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "No verification code found. Please request a new code."}`
- HTTP status code: 404

### Test 7: Missing Email Parameter

**Purpose**: Verify validation of required fields

**Steps**:
1. Send POST to `/api/auth/send-code` with empty JSON
2. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "Email is required"}`
- HTTP status code: 400

### Test 8: Missing Verification Parameters

**Purpose**: Verify validation of required fields

**Steps**:
1. Send POST to `/api/auth/verify-code` without device_id
2. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "Email, code, and device_id are required"}`
- HTTP status code: 400

### Test 9: Code Reuse Prevention

**Purpose**: Verify that codes can only be used once

**Steps**:
1. Request code and verify successfully
2. Try to verify with same code again
3. Check response status is "error"

**Expected Result**:
- Response: `{"status": "error", "message": "No verification code found. Please request a new code."}`
- HTTP status code: 404

### Test 10: Multiple Devices per User

**Purpose**: Verify that users can authenticate multiple devices

**Steps**:
1. Request code and verify with device_id_1
2. Request new code and verify with device_id_2
3. Check database shows both devices

**Expected Result**:
- User's device_ids array contains both device_id_1 and device_id_2
- No duplicate device IDs

## Automated Test Script

See `test-py.py` for automated Python test script that runs all test cases above.

## Manual Testing

Use curl commands:

```bash
# Test 1: Send code to new user
curl -X POST http://185.96.221.52:8080/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# Test 3: Verify code (replace CODE with actual code from email)
curl -X POST http://185.96.221.52:8080/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "code": "CODE", "device_id": "test-device-123"}'

# Test 4: Try invalid code
curl -X POST http://185.96.221.52:8080/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "code": "0000", "device_id": "test-device-123"}'
```

## Success Criteria

All 10 test cases must pass:
- ✅ New users can request codes
- ✅ Existing users can request codes
- ✅ Valid codes authenticate users
- ✅ Invalid codes are rejected
- ✅ Expired codes are rejected
- ✅ Codes can't be verified without request
- ✅ Missing parameters return errors
- ✅ Codes can only be used once
- ✅ Multiple devices per user work correctly
- ✅ Input validation works

## Integration with Existing Tests

This feature can be tested from the iOS/Android test infrastructure using the `/test/sign-in` endpoint (to be implemented in respective clients).
