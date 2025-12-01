# email implementation
*platform-agnostic email sending and receiving*

## Overview

Provides ability to send emails from and receive emails to a configured email account. Used primarily for passwordless authentication via one-time codes, with additional capability to verify email delivery for testing.

## Configuration

Email account details:
- **Sender address**: admin@microclub.org
- **Sender display name**: microclub
- **SMTP server**: smtp.office365.com (port 587, STARTTLS)
- **IMAP server**: outlook.office365.com (port 993, SSL)
- **Credentials**: Stored securely (not in code)

## Send Email Function

**Function**: `sendEmail(destination, subject, body) → result`

**Parameters:**
- `destination`: String - recipient email address
- `subject`: String - email subject line
- `body`: String - email body text (plain text)

**Returns:**
- On success: "success"
- On failure: "failed: <error message>"

**Process:**
1. Create email message with sender, recipient, subject, and body
2. Connect to SMTP server
3. Initiate TLS encryption
4. Authenticate with credentials
5. Send email
6. Return success or error message

**Error handling:**
- Network failures
- Authentication failures
- Invalid recipient addresses
- SMTP server errors

## Receive Email Function

**Function**: `receiveEmail(maxCount) → result`

**Parameters:**
- `maxCount`: Integer - maximum number of recent emails to fetch (default: 10)

**Returns:**
- On success: Array of email objects
- On failure: "failed: <error message>"

**Email object structure:**
```
{
  from: String,      // Sender address
  subject: String,   // Subject line
  date: String,      // Date sent
  body: String       // Plain text body
}
```

**Process:**
1. Connect to IMAP server with SSL
2. Authenticate with credentials
3. Select INBOX
4. Search for all emails
5. Fetch most recent `maxCount` emails (newest first)
6. Parse each email:
   - Decode subject (handle encoding)
   - Extract sender address
   - Extract date
   - Extract plain text body (handle multipart)
7. Return array of email objects

**Error handling:**
- Network failures
- Authentication failures
- IMAP server errors
- Email parsing errors

## Usage in Firefly

**Primary use case - Authentication:**
1. User requests sign-in
2. Generate 4-digit verification code
3. Send email with code to user's address
4. User enters code to authenticate

**Testing use case:**
1. Send test email to admin@microclub.org
2. Call receiveEmail() to verify delivery
3. Check that sent email appears in received emails
4. Confirm email system is working

## Security Considerations

- Credentials must not be hardcoded in source files
- Use environment variables or secure credential storage
- Email content may contain sensitive verification codes
- SMTP connection must use TLS encryption
- IMAP connection must use SSL

## Platform Implementation Notes

Different platforms may use:
- Built-in email libraries (Python: smtplib/imaplib)
- Third-party email services (SendGrid, AWS SES)
- Platform-specific APIs (iOS MailKit, Android JavaMail)
- Web APIs for server-side implementations

The interface (sendEmail/receiveEmail) remains the same across platforms.
