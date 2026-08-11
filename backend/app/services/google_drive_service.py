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
    async def get_or_create_resumes_folder(cls, access_token: str) -> str | None:
        """
        Retrieves the folder ID for 'resumes_tatvik', creating it if it doesn't exist.
        """
        headers = {
            "Authorization": f"Bearer {access_token}",
        }
        folder_name = "resumes_tatvik"

        # 1. Search for existing folder
        try:
            query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{folder_name}' and trashed = false"
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://www.googleapis.com/drive/v3/files",
                    params={"q": query, "fields": "files(id)"},
                    headers=headers,
                    timeout=10.0,
                )
                if response.status_code == 200:
                    files = response.json().get("files", [])
                    if files:
                        return files[0]["id"]
        except Exception as e:
            logger.error(
                f"Error searching for '{folder_name}' folder in Google Drive: {e}"
            )

        # 2. Create the folder if it wasn't found
        try:
            folder_metadata = {
                "name": folder_name,
                "mimeType": "application/vnd.google-apps.folder",
            }
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://www.googleapis.com/drive/v3/files",
                    headers=headers,
                    json=folder_metadata,
                    timeout=10.0,
                )
                if response.status_code == 200:
                    return response.json().get("id")
                else:
                    logger.error(
                        f"Failed to create Google Drive folder: {response.status_code} - {response.text}"
                    )
        except Exception as e:
            logger.error(f"Error creating '{folder_name}' folder in Google Drive: {e}")

        return None

    @classmethod
    async def upload_file_to_drive(
        cls, user_id: str, filename: str, content: str, db: Session
    ) -> dict:
        """
        Uploads a tailored resume file to Google Drive.
        If the filename ends in .pdf, compiles the Markdown content into PDF bytes and uploads.
        Falls back to local file sync if Google integration is not authenticated.
        """
        # Sanitize filename to prevent path traversal
        safe_filename = os.path.basename(filename)
        if not safe_filename:
            safe_filename = "resume.txt"
        is_pdf = safe_filename.lower().endswith(".pdf")

        # Save to local google_drive_sync folder in the workspace first
        workspace_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        )
        sync_dir = os.path.abspath(os.path.join(workspace_dir, "google_drive_sync"))
        os.makedirs(sync_dir, exist_ok=True)
        file_path = os.path.abspath(os.path.join(sync_dir, safe_filename))
        if not file_path.startswith(sync_dir):
            raise ValueError("Path traversal detected")

        if is_pdf:
            try:
                from app.services.pdf_generator_service import PDFGeneratorService

                upload_bytes = PDFGeneratorService.markdown_to_pdf(content)
            except Exception as e:
                logger.error(f"Failed to generate PDF: {e}")
                # Fallback to plain text
                upload_bytes = content.encode("utf-8")
                safe_filename = os.path.basename(safe_filename.replace(".pdf", ".txt"))
                file_path = os.path.abspath(os.path.join(sync_dir, safe_filename))
                if not file_path.startswith(sync_dir):
                    raise ValueError("Path traversal detected")
                is_pdf = False
        else:
            upload_bytes = content.encode("utf-8")

        try:
            if is_pdf:
                with open(file_path, "wb") as f:
                    f.write(upload_bytes)
            else:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)
        except Exception as e:
            logger.error(f"Failed to save local file sync backup: {e}")

        access_token = await cls.get_or_refresh_token(user_id, db)
        if not access_token:
            # Return local-only status, advising user to connect
            return {
                "status": "local_only",
                "file_name": safe_filename,
                "file_path": file_path,
                "drive_file_id": None,
                "web_view_link": None,
                "message": "Connected to local workspace backup. Link Google Drive to sync to cloud.",
                "synced_at": "Just now (local)",
            }

        # Resolve resumes_tatvik folder
        folder_id = await cls.get_or_create_resumes_folder(access_token)

        try:
            mime_type = "application/pdf" if is_pdf else "text/markdown"
            metadata = {"name": safe_filename, "mimeType": mime_type}
            if folder_id:
                metadata["parents"] = [folder_id]
            boundary = b"google_drive_upload_boundary_tatvik"
            headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": f"multipart/related; boundary={boundary.decode()}",
            }
            body = (
                b"\r\n--" + boundary + b"\r\n"
                b"Content-Type: application/json; charset=UTF-8\r\n\r\n"
                + json.dumps(metadata).encode("utf-8")
                + b"\r\n"
                b"--"
                + boundary
                + b"\r\n"
                + f"Content-Type: {mime_type}\r\n\r\n".encode()
                + upload_bytes
                + b"\r\n"
                b"--" + boundary + b"--\r\n"
            )
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
                    headers=headers,
                    content=body,
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
                        "file_name": safe_filename,
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
                        "file_name": safe_filename,
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
                "file_name": safe_filename,
                "file_path": file_path,
                "drive_file_id": None,
                "web_view_link": None,
                "message": "Saved locally. An error occurred during upload.",
                "synced_at": "Just now (local)",
            }
