"""Python function to send email with login credential to driver when created"""
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
from firebase_functions import firestore_fn
from firebase_admin import initialize_app

load_dotenv()

initialize_app()

def send_python_email(recipient_email, driver_name):
    """Sending email to driver"""
    sender_email = os.getenv("SENDER_EMAIL")
    sender_password = os.getenv("SENDER_PASSWORD")

    if not sender_email or not sender_password:
        print("Error: Email credentials not found in environment.")
        return

    message = MIMEMultipart("alternative")
    message["Subject"] = "Welcome to Swiftline Carrier!"
    message["From"] = f"Swiftline Admin <{sender_email}>"
    message["To"] = recipient_email

    html = f"""
    <html>
      <body>
        <h2>Welcome, {driver_name}!</h2>
        <p>Your driver account for <b>Swiftline</b> has been created.</p>
        <p>Please log in using your registered email.</p>
        <br>
        <p>Safe driving,<br>The Swiftline Team</p>
      </body>
    </html>
    """
    message.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, recipient_email, message.as_string())
        print(f"Email sent successfully to {recipient_email}")
    except (smtplib.SMTPAuthenticationError, smtplib.SMTPException) as e:
        print(f"Error sending email: {e}")

@firestore_fn.on_document_created(document="drivers/{driverId}")
def on_driver_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """Event trigger when a new driver is created"""
    if event.data is None:
        return

    driver_data = event.data.to_dict()
    email = driver_data.get("email")
    name = driver_data.get("fullName")

    if email:
        send_python_email(email, name)
