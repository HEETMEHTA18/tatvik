from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.models.entities import PushDevice

router = APIRouter()


class PushDeviceRegisterRequest(BaseModel):
    token: str = Field(min_length=16)
    platform: str = Field(default="web")
    device_name: str | None = None


class PushDeviceUnregisterRequest(BaseModel):
    token: str = Field(min_length=16)


@router.post("/register")
def register_push_device(
    payload: PushDeviceRegisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    device_stmt = select(PushDevice).where(PushDevice.token == payload.token)
    device = db.scalar(device_stmt)
    if not device:
        device = PushDevice(
            user_id=user_id,
            token=payload.token,
            platform=payload.platform,
            device_name=payload.device_name,
        )
    else:
        device.user_id = user_id
        device.platform = payload.platform
        device.device_name = payload.device_name
        device.is_active = True

    device.last_seen_at = datetime.utcnow()
    db.add(device)
    db.commit()
    return {"success": True, "message": "Push device registered."}


@router.post("/unregister")
def unregister_push_device(
    payload: PushDeviceUnregisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    device_stmt = select(PushDevice).where(
        PushDevice.token == payload.token,
        PushDevice.user_id == user_id,
    )
    device = db.scalar(device_stmt)
    if device:
        device.is_active = False
        device.last_seen_at = datetime.utcnow()
        db.add(device)
        db.commit()
    return {"success": True, "message": "Push device unregistered."}
