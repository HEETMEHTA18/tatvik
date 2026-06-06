import sqlite3

db_path = "/home/heet18/Projects/devmentor/backend/devmentor.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Check if columns already exist
cursor.execute("PRAGMA table_info(prompt_histories)")
columns = [row[1] for row in cursor.fetchall()]

if "session_id" not in columns:
    print("Adding session_id to prompt_histories...")
    cursor.execute("ALTER TABLE prompt_histories ADD COLUMN session_id VARCHAR(255)")

if "prompt_id" not in columns:
    print("Adding prompt_id to prompt_histories...")
    cursor.execute("ALTER TABLE prompt_histories ADD COLUMN prompt_id VARCHAR(255)")

if "response" not in columns:
    print("Adding response to prompt_histories...")
    cursor.execute("ALTER TABLE prompt_histories ADD COLUMN response TEXT")

conn.commit()
conn.close()
print("Migration completed successfully!")
