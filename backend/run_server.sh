#!/bin/bash
cd /home/heet18/Projects/devmentor/backend
export DATABASE_URL="sqlite:///./devmentor.db"
exec ./.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
