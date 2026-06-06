import sqlite3

db_path = "/home/heet18/Projects/devmentor/backend/devmentor.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("--- sessions ---")
cursor.execute("SELECT * FROM autodev_sessions")
for row in cursor.fetchall():
    print(row)

print("--- prompt histories ---")
cursor.execute("SELECT id, user_id, session_id, prompt_id, original_prompt, refined_prompt, score, technologies, workflow FROM prompt_histories")
for row in cursor.fetchall():
    print(row)

print("--- executed commands ---")
cursor.execute("SELECT * FROM executed_commands")
for row in cursor.fetchall():
    print(row)

print("--- generated files ---")
cursor.execute("SELECT * FROM generated_files")
for row in cursor.fetchall():
    print(row)

conn.close()
