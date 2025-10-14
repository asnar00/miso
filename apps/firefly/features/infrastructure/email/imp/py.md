# email.py
*how to send an email from python*

Call the `send_email` function below with destination address, subject text, and body text.

```py
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

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
```