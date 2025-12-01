# email.py
*how to send and receive email from python*

Call the `send_email` function below with destination address, subject text, and body text.

Call the `receive_email` function to fetch recent emails sent to admin@microclub.org.

```py
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Send an email from admin.microclub.org; return success or error
def send_email(destination, subject, body) -> str:
    # Email account and SMTP server details
    sender_email = "admin@microclub.org"
    sender_name = "microclub"  # The name you want to appear
    sender_password = config.get_config_value('EMAIL_PASSWORD')  # Load from .env file
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
    password = config.get_config_value('EMAIL_PASSWORD')  # Load from .env file

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
```

