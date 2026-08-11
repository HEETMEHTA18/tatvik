# Tatvik Backend

FastAPI backend scaffold for Tatvik.

## Quick start

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## Run tests

```bash
cd backend
source .venv/bin/activate
pytest -q
```

