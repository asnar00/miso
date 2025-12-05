# sign-in pseudocode
*natural-language implementation approach for all products*

## Overview

Sign-in uses passwordless email authentication with 4-digit verification codes. The process requires coordination between the client (iOS/Android) and server (Python/Flask).

## Data Structures

**Client Storage** (persistent):
- `user_email` (string): User's email address
- `is_logged_in` (boolean): Whether user is authenticated
- `device_id` (string): Unique identifier for this device (UUID)

**Server Storage** (in-memory, temporary):
- `pending_codes` (dictionary): Maps email → {code, timestamp}
  - Automatically expires after 10 minutes
  - Cleared after successful verification

**Database** (PostgreSQL):
- `users` table: Contains email, created_at, device_ids array
- Persistent user records

## Process Flow

### Stage 1: Email Entry

**Client**:
1. On app startup, check Storage for `is_logged_in` flag
2. If True and email exists, go directly to main app
3. If False, show sign-in screen with email input field
4. User enters email address and taps Submit
5. Send POST request to `/api/auth/send-code` with email

**Server**:
1. Receive email from client
2. Check if user exists in database by email
3. If user doesn't exist:
   - Create new user record with email
   - Initialize empty device_ids array
4. Generate random 4-digit code (0000-9999)
5. Store code in `pending_codes[email] = {code, timestamp}`
6. Send email to user: "Your microclub verification code is: XXXX"
7. Return success response to client

**Client**:
8. Show code verification screen

### Stage 2: Code Verification

**Client**:
1. Show 4-digit code input field
2. User enters the code they received via email
3. Send POST request to `/api/auth/verify-code` with {email, code, device_id}

**Server**:
1. Look up email in `pending_codes`
2. If not found, return error: "No code requested for this email"
3. Check if timestamp is within 10 minutes
4. If expired, return error: "Code expired, please request a new one"
5. Compare submitted code with stored code
6. If mismatch, return error: "Invalid code"
7. If match:
   - Get user from database by email
   - Add device_id to user's device_ids array (if not already present)
   - Remove code from `pending_codes`
   - Return success with user_id

**Client**:
8. On success response:
   - Save to Storage: `user_email = email`, `is_logged_in = True`
   - Transition to main app screen
9. On error response:
   - Show error message
   - Allow user to retry or request new code

## Error Handling

**Invalid email format**: Client should validate before sending
**Email delivery failure**: Server should return error, client shows message
**Code expired**: User can request new code (restart from Stage 1)
**Code incorrect**: User can retry up to 3 times before requiring new code
**Network errors**: Client shows "Connection error, please try again"

## Security Considerations

**Code generation**: Use cryptographically secure random number generator
**Rate limiting**: Limit code requests to 1 per minute per email
**Expiration**: Codes must expire after 10 minutes
**Device tracking**: Associate device_id with user to enable multi-device support

## Functions to Implement

### Server (Python/Flask)

`generate_verification_code()` → string
- Generate random 4-digit code (0000-9999)
- Use secure random number generator

`send_verification_email(email, code)` → bool
- Use existing email feature
- Subject: "microclub Verification Code"
- Body: "Your verification code is: {code}. This code expires in 10 minutes."
- Return True on success, False on failure

`clean_expired_codes()`
- Remove codes older than 10 minutes from pending_codes
- Called before each code check

`POST /api/auth/send-code`
- Input: {email}
- Process: Check/create user, generate code, send email
- Output: {status: "success"} or {status: "error", message: "..."}

`POST /api/auth/verify-code`
- Input: {email, code, device_id}
- Process: Validate code, update user device list
- Output: {status: "success", user_id: X} or {status: "error", message: "..."}

### Client (iOS/Swift)

`SignInView` (SwiftUI View)
- State: .enterEmail or .enterCode
- Shows appropriate screen based on state

`sendCodeRequest(email)` → async
- POST to /api/auth/send-code
- Handle success/error
- Transition to code entry on success

`verifyCode(email, code)` → async
- Get device_id from Storage
- POST to /api/auth/verify-code with {email, code, device_id}
- On success: save login state, navigate to main app
- On error: show error message

### Client (Android/Kotlin)

Similar structure to iOS implementation
