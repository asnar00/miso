#!/usr/bin/env python3
"""
Send watchdog email notification using the same email function as the Flask app
This avoids DNS issues when running from cron
"""

import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email(destination, subject, body):
    """Send email using admin@microclub.org"""
    sender_email = "admin@microclub.org"
    sender_name = "microclub"
    sender_password = "CreateTogetherN0w"
    smtp_server = "smtp.office365.com"
    smtp_port = 587

    message = MIMEMultipart()
    message["From"] = f"{sender_name} <{sender_email}>"
    message["To"] = destination
    message["Subject"] = subject
    message.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, destination, message.as_string())
            return 'success'
    except Exception as e:
        return f'failed: {e}'

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: send_watchdog_email.py <to> <subject> <body>")
        sys.exit(1)

    to_email = sys.argv[1]
    subject = sys.argv[2]
    body = sys.argv[3]

    result = send_email(to_email, subject, body)
    if result == 'success':
        print(f"Email sent successfully to {to_email}")
        sys.exit(0)
    else:
        print(f"Failed to send email: {result}")
        sys.exit(1)
