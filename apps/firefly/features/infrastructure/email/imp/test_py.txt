#!/usr/bin/env python3
"""
Test script for email send/receive functionality
Sends a test email from admin@microclub.org to admin@microclub.org
Then checks if it was received
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import imaplib
import email
from email.header import decode_header
import time

# Send an email from admin.microclub.org; return success or error
def send_email(destination, subject, body) -> str:
    # Email account and SMTP server details
    sender_email = "admin@microclub.org"
    sender_name = "microclub"  # The name you want to appear
    sender_password = "Conf1dant!"  # Replace with the actual password
    smtp_server = "smtp.office365.com"
    smtp_port = 587  # Correct port for using STARTTLS

    # Create a MIMEText object
    message = MIMEMultipart()
    message["From"] = f"{sender_name} <{sender_email}>"
    message["To"] = destination
    message["Subject"] = subject

    # Add body to the email
    message.attach(MIMEText(body, "plain"))

    # Convert the message to a string
    text = message.as_string()

    # Send the email
    try:
        # Connect to SMTP server in plain text mode then start TLS
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.ehlo()  # Can be omitted
            server.starttls()  # Secure the connection
            server.ehlo()  # Can be omitted
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, destination, text)
            print("Email sent successfully!")
            return 'success'
    except Exception as e:
        print(f"Failed to send email. Error: {e}")
        return 'failed: ' + str(e)

# Receive emails from admin@microclub.org; return list of emails or error
def receive_email(max_count=10):
    import imaplib
    import email
    from email.header import decode_header

    # Email account and IMAP server details
    imap_server = "outlook.office365.com"
    imap_port = 993
    email_address = "admin@microclub.org"
    password = "Conf1dant!"

    try:
        # Connect to IMAP server with SSL
        mail = imaplib.IMAP4_SSL(imap_server, imap_port)
        mail.login(email_address, password)

        # Select the inbox
        mail.select("INBOX")

        # Search for all emails
        status, messages = mail.search(None, "ALL")

        if status != "OK":
            return 'failed: could not search inbox'

        # Get list of email IDs
        email_ids = messages[0].split()

        # Limit to most recent max_count emails
        email_ids = email_ids[-max_count:]

        emails = []

        # Fetch each email
        for email_id in reversed(email_ids):  # Most recent first
            status, msg_data = mail.fetch(email_id, "(RFC822)")

            if status != "OK":
                continue

            # Parse the email
            msg = email.message_from_bytes(msg_data[0][1])

            # Decode subject
            subject = msg.get("Subject", "")
            if subject:
                decoded_subject = decode_header(subject)[0]
                if isinstance(decoded_subject[0], bytes):
                    subject = decoded_subject[0].decode(decoded_subject[1] or 'utf-8')
                else:
                    subject = decoded_subject[0]

            # Get sender
            from_addr = msg.get("From", "")

            # Get date
            date = msg.get("Date", "")

            # Get body
            body = ""
            if msg.is_multipart():
                for part in msg.walk():
                    content_type = part.get_content_type()
                    if content_type == "text/plain":
                        try:
                            body = part.get_payload(decode=True).decode()
                            break
                        except:
                            pass
            else:
                try:
                    body = msg.get_payload(decode=True).decode()
                except:
                    body = msg.get_payload()

            emails.append({
                'from': from_addr,
                'subject': subject,
                'date': date,
                'body': body
            })

        # Logout
        mail.close()
        mail.logout()

        return emails

    except Exception as e:
        print(f"Failed to receive email. Error: {e}")
        return 'failed: ' + str(e)


def test_email_send_receive():
    """Test sending and receiving email"""

    # Generate unique subject to identify our test email
    test_subject = f"Test Email {int(time.time())}"
    test_body = "This is a test email from the email send/receive test script."

    print(f"\n=== Email Send/Receive Test ===\n")

    # Step 1: Send email
    print(f"Step 1: Sending test email to admin@microclub.org...")
    print(f"  Subject: {test_subject}")
    result = send_email("admin@microclub.org", test_subject, test_body)

    if result != 'success':
        print(f"FAILED: Could not send email - {result}")
        return False

    print("  Success: Email sent\n")

    # Step 2: Wait a bit for email to arrive
    print("Step 2: Waiting 5 seconds for email to arrive...")
    time.sleep(5)

    # Step 3: Check for received email
    print("Step 3: Checking inbox for test email...")
    emails = receive_email(max_count=20)

    if isinstance(emails, str) and emails.startswith('failed'):
        print(f"FAILED: Could not receive emails - {emails}")
        return False

    # Look for our test email
    found = False
    for email_item in emails:
        if email_item['subject'] == test_subject:
            found = True
            print(f"  Found test email!")
            print(f"    From: {email_item['from']}")
            print(f"    Subject: {email_item['subject']}")
            print(f"    Date: {email_item['date']}")
            print(f"    Body preview: {email_item['body'][:50]}...")
            break

    if not found:
        print(f"FAILED: Test email not found in inbox")
        print(f"  Checked {len(emails)} most recent emails")
        return False

    print("\n=== TEST PASSED ===\n")
    return True


if __name__ == "__main__":
    success = test_email_send_receive()
    exit(0 if success else 1)
