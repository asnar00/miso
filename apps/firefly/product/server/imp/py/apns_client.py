"""
APNs (Apple Push Notification service) client for sending push notifications.
Uses PyAPNs2 with JWT token-based authentication.
"""

import os
from apns2.client import APNsClient, NotificationPriority
from apns2.payload import Payload
from apns2.credentials import TokenCredentials

class PushNotificationService:
    """Service for sending push notifications via APNs"""

    def __init__(self):
        self.client = None
        self.bundle_id = os.getenv('APNS_BUNDLE_ID', 'com.miso.noobtest')
        self._initialize_client()

    def _initialize_client(self):
        """Initialize APNs client with JWT credentials"""
        key_id = os.getenv('APNS_KEY_ID')
        team_id = os.getenv('APNS_TEAM_ID')
        key_path = os.getenv('APNS_KEY_PATH')
        use_sandbox = os.getenv('APNS_USE_SANDBOX', 'true').lower() == 'true'

        if not all([key_id, team_id, key_path]):
            print("[APNS] Missing configuration, push notifications disabled")
            print(f"[APNS] KEY_ID={key_id}, TEAM_ID={team_id}, KEY_PATH={key_path}")
            return

        if not os.path.exists(key_path):
            print(f"[APNS] Key file not found: {key_path}")
            return

        try:
            credentials = TokenCredentials(
                auth_key_path=key_path,
                auth_key_id=key_id,
                team_id=team_id
            )
            self.client = APNsClient(
                credentials=credentials,
                use_sandbox=use_sandbox
            )
            env = "sandbox" if use_sandbox else "production"
            print(f"[APNS] Client initialized ({env})")
        except Exception as e:
            print(f"[APNS] Failed to initialize client: {e}")

    def send_notification(self, device_token: str, title: str, body: str, badge: int = 1) -> bool:
        """
        Send a push notification to a device.

        Args:
            device_token: APNs device token (hex string)
            title: Notification title
            body: Notification body text
            badge: App icon badge number (default 1)

        Returns:
            True if sent successfully, False otherwise
        """
        if not self.client:
            print("[APNS] Client not initialized, skipping notification")
            return False

        if not device_token:
            print("[APNS] No device token provided")
            return False

        try:
            payload = Payload(
                alert={"title": title, "body": body},
                badge=badge,
                sound="default"
            )

            self.client.send_notification(
                token_hex=device_token,
                notification=payload,
                topic=self.bundle_id,
                priority=NotificationPriority.Immediate
            )
            print(f"[APNS] Sent: '{title}' to {device_token[:8]}...")
            return True

        except Exception as e:
            print(f"[APNS] Failed to send notification: {e}")
            return False

    def send_to_user(self, db, user_id: int, title: str, body: str) -> bool:
        """
        Send notification to a user by their user ID.

        Args:
            db: Database instance
            user_id: User's database ID
            title: Notification title
            body: Notification body text

        Returns:
            True if sent successfully, False otherwise
        """
        user = db.get_user_by_id(user_id)
        if not user:
            print(f"[APNS] User {user_id} not found")
            return False

        token = user.get('apns_device_token')
        if not token:
            print(f"[APNS] User {user_id} has no device token")
            return False

        return self.send_notification(token, title, body)


# Global instance - initialized when module is imported
push_service = PushNotificationService()
