from fastapi.testclient import TestClient

from app.db.base import Base
from app.db.session import engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_register_and_login_flow():
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "devmentor@example.com",
            "password": "Password123!",
            "name": "Dev Mentor",
        },
    )
    assert register_response.status_code == 200
    assert "access_token" in register_response.json()

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "devmentor@example.com", "password": "Password123!"},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()
