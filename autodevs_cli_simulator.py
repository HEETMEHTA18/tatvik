import sys
import json
import httpx
from jose import jwt
from datetime import datetime, timedelta
import sqlite3
import os

# Configuration
DB_PATH = "backend/tatvik.db"
SECRET_KEY = "change-me"
ALGORITHM = "HS256"
API_URL = "https://tatvik-jmjh.onrender.com/api/v1/prompts/event"


def get_first_user_id():
    if not os.path.exists(DB_PATH):
        print(f"Error: Database file not found at '{DB_PATH}'")
        return None
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM users LIMIT 1")
        row = cursor.fetchone()
        conn.close()
        if row:
            return row[0]
    except Exception as e:
        print(f"Could not read database: {e}")
    return None

def generate_token(user_id):
    payload = {
        "sub": user_id,
        "exp": datetime.utcnow() + timedelta(hours=24)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def main():
    if len(sys.argv) < 2:
        print("Usage: python autodevs_cli_simulator.py \"your prompt here\" [project_name]")
        print("Example: python autodevs_cli_simulator.py \"create a button widget with circular borders\" tatvik-app")
        sys.exit(1)
        
    prompt_text = sys.argv[1]
    project_name = sys.argv[2] if len(sys.argv) > 2 else "autodevs-cli"
    
    token = os.environ.get("TATVIK_TOKEN")
    if token:
        print("Using JWT token from environment variable TATVIK_TOKEN.")
    else:
        user_id = get_first_user_id()
        if not user_id:
            print("\nNo user found in the local database and no TATVIK_TOKEN environment variable is set.")
            print("To run against production, log in via your mobile app and set the TATVIK_TOKEN environment variable.")
            sys.exit(1)
            
        print(f"Detected User ID from DB: {user_id}")
        token = generate_token(user_id)
        print("Generated JWT authentication token.")

    
    print(f"\nSending prompt event to Tatvik API...")
    print(f"Original Prompt: '{prompt_text}'")
    print(f"Project context: '{project_name}'")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {
        "original_prompt": prompt_text,
        "project_name": project_name,
        "file_context": "CLI simulator active"
    }
    
    try:
        response = httpx.post(API_URL, json=payload, headers=headers, timeout=30.0)
        if response.status_code == 200:
            res_data = response.json()
            print("\n" + "="*50)
            print("🚀 PROMPT ANALYSIS SYNCED SUCCESSFULLY")
            print("="*50)
            print(f"Score: {res_data.get('score')}/100")
            print(f"Workflow: {res_data.get('workflow')}")
            print(f"Technologies: {', '.join(res_data.get('technologies', []))}")
            print("\n[ORIGINAL PROMPT]")
            print(res_data.get("original_prompt"))
            print("\n[AI UPGRADED PROMPT]")
            print(res_data.get("refined_prompt"))
            print("="*50)
            print("\nOpen the Tatvik app and switch to the 'PROMPTS' tab to see it live!")
        else:
            print(f"\nAPI Error (Status {response.status_code}): {response.text}")
    except Exception as e:
        print(f"\nConnection failed: {e}")

if __name__ == "__main__":
    main()
