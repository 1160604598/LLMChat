import sqlite3
import os

def check_db(db_path):
    print(f"Checking {db_path}...")
    if not os.path.exists(db_path):
        print(f"Database file {db_path} does not exist.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [row[0] for row in cursor.fetchall()]
    print(f"Tables: {tables}")

    target_table = None
    if 'model_configs' in tables:
        target_table = 'model_configs'
    elif 'user_llm_configs' in tables:
        target_table = 'user_llm_configs'
        print("Found user_llm_configs instead of model_configs. Maybe rename?")

    if target_table:
        print(f"Target table: {target_table}")
        # Check columns
        cursor.execute(f"PRAGMA table_info({target_table})")
        columns = [row[1] for row in cursor.fetchall()]
        print(f"Columns: {columns}")
        
        if 'display_order' not in columns:
            try:
                cursor.execute(f"ALTER TABLE {target_table} ADD COLUMN display_order INTEGER DEFAULT 0")
                print(f"Successfully added display_order column to {target_table} table")
            except sqlite3.OperationalError as e:
                print(f"Error adding column: {e}")
        else:
            print("Column display_order already exists")
    else:
        print("No suitable config table found.")
            
    conn.commit()
    conn.close()

if __name__ == "__main__":
    check_db('sql_app.db')
    check_db('backend/sql_app.db')
    check_db('dist/sql_app.db')
