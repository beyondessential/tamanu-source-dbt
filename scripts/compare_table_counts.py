#!/usr/bin/env python3
"""
Compares row counts between public.{table_name} and replica.rec__{table_name}
for all tables in the public schema.
Uses TAMANU_DEMO_DB_* environment variables for database connection.
"""

import os
import psycopg2
import sys
from pathlib import Path

# Add utils directory to path for cprint
sys.path.append(str(Path(__file__).parent / 'utils'))
from utils import cprint

def get_db_connection():
    """Establishes a database connection using environment variables."""
    try:
        conn = psycopg2.connect(
            host=os.environ.get("TAMANU_DEMO_DB_URL"),
            port=os.environ.get("TAMANU_DEMO_DB_PORT", "5432"),
            database=os.environ.get("TAMANU_DEMO_DB_DATABASE"),
            user=os.environ.get("TAMANU_DEMO_DB_USER"),
            password=os.environ.get("TAMANU_DEMO_DB_PASSWORD")
        )
        cprint("Successfully connected to the database.", "success")
        return conn
    except Exception as e:
        cprint(f"Error connecting to the database: {e}", "error")
        sys.exit(1)

def get_public_table_names(cursor):
    """Retrieves a list of table names from the 'public' schema."""
    try:
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE';
        """)
        return [row[0] for row in cursor.fetchall()]
    except Exception as e:
        cprint(f"Error retrieving table names from public schema: {e}", "error")
        return []

def get_replica_table_names(cursor):
    """Retrieves a list of table names from the 'replica' schema."""
    try:
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'replica'
            AND table_type = 'BASE TABLE';
        """)
        return [row[0] for row in cursor.fetchall()]
    except Exception as e:
        cprint(f"Error retrieving table names from replica schema: {e}", "error")
        return []

def main():
    """Main execution function to compare table counts."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        public_tables = get_public_table_names(cursor)
        replica_tables = get_replica_table_names(cursor)
        replica_table_map = {t[len("rec__"):]: t for t in replica_tables if t.startswith("rec__")}

        cprint(f"Found {len(public_tables)} tables in public schema.", "info")
        cprint(f"Found {len(replica_tables)} tables in replica schema.", "info")

        print("\n--- Table Row Count Comparison ---")
        print(f"{'Table Name':<30} | {'Public Count':<15} | {'Replica Count':<15} | {'Match'}")
        print("-" * 80)

        for table_name in sorted(public_tables):
            public_count = -1
            replica_count = -1
            match = "N/A"

            # Get public table count
            try:
                cursor.execute(f"SELECT COUNT(*) FROM public.{table_name};")
                public_count = cursor.fetchone()[0]
            except Exception as e:
                cprint(f"Warning: Could not get count for public.{table_name}: {e}", "warning")
                conn.rollback() # Rollback to clear aborted transaction state

            # Get replica table count if it exists
            replica_rec_table_name = replica_table_map.get(table_name)
            if replica_rec_table_name:
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM replica.{replica_rec_table_name};")
                    replica_count = cursor.fetchone()[0]
                except Exception as e:
                    cprint(f"Warning: Could not get count for replica.{replica_rec_table_name}: {e}", "warning")
                    conn.rollback() # Rollback to clear aborted transaction state

            if public_count != -1 and replica_count != -1:
                match = "YES" if public_count == replica_count else "NO"
            elif public_count != -1 and replica_count == -1:
                match = "NO (Replica missing)"
            elif public_count == -1 and replica_count != -1:
                match = "NO (Public missing)"

            print(f"{table_name:<30} | {public_count:<15} | {replica_count:<15} | {match}")

    except Exception as e:
        cprint(f"An unexpected error occurred: {e}", "error")
    finally:
        if conn:
            conn.close()
            cprint("Database connection closed.", "info")

if __name__ == "__main__":
    main()
