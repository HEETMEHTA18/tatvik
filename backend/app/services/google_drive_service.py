import os
import json
import logging
import httpx
from datetime import datetime
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.entities import GoogleProfile

logger = logging.getLogger(__name__)


class GoogleDriveService:
    @staticmethod
    async def get_or_refresh_token(user_id: str, db: Session) -> str | None:
        """
        Retrieves the access token for the given user, refreshing it if necessary.
        """
        stmt = select(GoogleProfile).where(GoogleProfile.user_id == user_id)
        profile = db.scalar(stmt)
        if not profile or not profile.access_token:
            return None

        # Verify or refresh token using Google OAuth token endpoint
        # If we have a refresh token, we can aggressively refresh to avoid mid-operation expiry
        if profile.refresh_token:
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        "https://oauth2.googleapis.com/token",
                        data={
                            "client_id": settings.GOOGLE_CLIENT_ID
                            or "google-client-id",
                            "client_secret": settings.GOOGLE_CLIENT_SECRET
                            or "google-client-secret",
                            "refresh_token": profile.refresh_token,
                            "grant_type": "refresh_token",
                        },
                        timeout=10.0,
                    )
                    if response.status_code == 200:
                        data = response.json()
                        new_access = data.get("access_token")
                        if new_access:
                            profile.access_token = new_access
                            profile.synced_at = datetime.utcnow()
                            db.commit()
                            logger.info(
                                f"Refreshed Google OAuth token for user {user_id}"
                            )
                            return new_access
            except Exception as e:
                logger.error(
                    f"Failed to refresh Google OAuth token for user {user_id}: {e}"
                )

        return profile.access_token

    @classmethod
    async def upload_file_to_drive(
        cls, user_id: str, filename: str, content: str, db: Session
    ) -> dict:
        """
        Uploads a markdown/text file to Google Drive.
        Falls back to local file sync if Google integration is not authenticated.
        """
        # Save to local google_drive_sync folder in the workspace first
        workspace_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        )
        sync_dir = os.path.join(workspace_dir, "google_drive_sync")
        os.makedirs(sync_dir, exist_ok=True)
        file_path = os.path.join(sync_dir, filename)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

        access_token = await cls.get_or_refresh_token(user_id, db)
        if not access_token:
            # Return local-only status, advising user to connect
            return {
                "status": "local_only",
                "file_name": filename,
                "file_path": file_path,
                "drive_file_id": None,
                "web_view_link": None,
                "message": "Connected to local workspace backup. Link Google Drive to sync to cloud.",
                "synced_at": "Just now (local)",
            }

        try:
            metadata = {"name": filename, "mimeType": "text/markdown"}
            boundary = "google_drive_upload_boundary_devmentor"
            headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": f"multipart/related; boundary={boundary}",
            }
            body = (
                f"\r\n--{boundary}\r\n"
                "Content-Type: application/json; charset=UTF-8\r\n\r\n"
                f"{json.dumps(metadata)}\r\n"
                f"--{boundary}\r\n"
                "Content-Type: text/markdown; charset=UTF-8\r\n\r\n"
                f"{content}\r\n"
                f"--{boundary}--\r\n"
            )
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
                    headers=headers,
                    content=body.encode("utf-8"),
                    timeout=15.0,
                )
                if response.status_code == 200:
                    res_data = response.json()
                    file_id = res_data.get("id")
                    logger.info(
                        f"Successfully uploaded tailored resume to Google Drive for user {user_id}"
                    )
                    return {
                        "status": "success",
                        "file_name": filename,
                        "file_path": file_path,
                        "drive_file_id": file_id,
                        "web_view_link": f"https://drive.google.com/open?id={file_id}",
                        "synced_at": "Just now",
                    }
                else:
                    logger.error(
                        f"Google Drive API error: {response.status_code} - {response.text}"
                    )
                    return {
                        "status": "partial_success_api_error",
                        "file_name": filename,
                        "file_path": file_path,
                        "drive_file_id": None,
                        "web_view_link": None,
                        "message": f"Saved locally. Google Drive API error: {response.status_code}",
                        "synced_at": "Just now (local)",
                    }
        except Exception as e:
            logger.error(f"Exception uploading to Google Drive: {e}")
            return {
                "status": "partial_success_exception",
                "file_name": filename,
                "file_path": file_path,
                "drive_file_id": None,
                "web_view_link": None,
                "message": f"Saved locally. Error uploading: {str(e)}",
                "synced_at": "Just now (local)",
            }
