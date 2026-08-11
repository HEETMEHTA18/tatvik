import os
import sys

# Force the database URL to use a local SQLite test database for all pytest runs
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["ENVIRONMENT"] = "testing"

# Clean up any existing test database file
if os.path.exists("test.db"):
    try:
        os.remove("test.db")
    except Exception:
        pass
