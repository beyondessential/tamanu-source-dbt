#!/usr/bin/env python3
"""
Create reconstructs models for all tables found in logs.changes.
Only creates models that don't already exist - existing models are skipped.
Then runs dbt to build the replica schema.
"""

import argparse
from pathlib import Path
from utils import write_file, cprint, execute_command_with_output

# List of table names to exclude from reconstructs model creation
EXCLUDE_TABLES = [
    "attachments",
    "lab_request_attachments",
    "vital_logs"
]


def get_distinct_table_names(target=None):
    """Query logs.changes for distinct table names using dbt macro."""
    try:
        # Build dbt command
        cmd = "dbt run-operation get_table_list --profiles-dir config"
        if target:
            cmd += f" --target {target}"
            
        # Run dbt macro to get table list
        result = execute_command_with_output(cmd)
        print(result)
        if result.returncode != 0:
            cprint(f"dbt macro failed: {result.stderr}", "error")
            return []

        # Parse output to extract table names
        table_names = []
        lines = result.stdout.split("\n")

        # Look for lines that appear to be table names (after dbt setup messages)
        parsing_tables = False
        for line in lines:
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            # Skip dbt setup/warning messages
            if (line.startswith("Running") or 
                line.startswith("Completed") or 
                line.startswith("Found") or 
                line.startswith("Registered") or 
                "functionality" in line or
                ":" in line[:12]):  # Skip timestamp lines (first 12 chars contain time)
                continue
                
            # This should be a table name - validate it
            if line.replace("_", "").isalnum() and len(line) > 0:
                table_names.append(line)

        return table_names

    except Exception as e:
        cprint(f"Error querying database: {e}", "error")
        return []


def get_existing_models():
    """Get existing reconstructs model names."""
    reconstructs_dir = Path("models/reconstructs")
    existing = set()

    if reconstructs_dir.exists():
        for file_path in reconstructs_dir.glob("rec_*.sql"):
            table_name = file_path.stem[len("rec__") :]
            existing.add(table_name)

    return existing


def create_model(table_name):
    """Create reconstructs model for table."""
    model_path = Path(f"models/reconstructs/rec__{table_name}.sql")

    # Skip if model already exists
    if model_path.exists():
        cprint(f"Skipped (exists): {model_path}", "warning")
        return False

    content = f"""{{{{
    config(
        unique_key='logs_changes_record_id',
        on_schema_change='sync_all_columns'
    )
}}}}

{{{{ jsonb_to_columns_dynamic('{table_name}')}}}}
"""

    Path("models/reconstructs").mkdir(exist_ok=True)
    write_file(str(model_path), content, "text")
    cprint(f"Created: {model_path}", "success")
    return True


def run_dbt_replica(target=None):
    """Run dbt to build the replica schema."""
    try:
        # Build dbt command
        cmd = "dbt run --profiles-dir config --selector replica"
        if target:
            cmd += f" --target {target}"
            
        cprint(f"Running: {cmd}", "info")
        result = execute_command_with_output(cmd)
        
        if result.returncode == 0:
            cprint("dbt run completed successfully", "success")
        else:
            cprint(f"dbt run failed: {result.stderr}", "error")
            
        return result.returncode == 0
        
    except Exception as e:
        cprint(f"Error running dbt: {e}", "error")
        return False


def main():
    """Main execution."""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Update replica schema by creating reconstruct models and running dbt")
    parser.add_argument("--target", help="dbt target to use")
    args = parser.parse_args()
    
    cprint("Querying database for table names...", "info")
    table_names = get_distinct_table_names(args.target)

    if not table_names:
        cprint("No table names found", "error")
        return

    cprint(f"Found {len(table_names)} tables in logs.changes", "info")

    existing = get_existing_models()
    cprint(f"Found {len(existing)} existing reconstructs models", "info")

    created_count = 0
    skipped_count = 0

    for table_name in table_names:
        if table_name in existing:
            cprint(f"Skipped (exists): rec_{table_name}.sql", "warning")
            skipped_count += 1
        elif table_name in EXCLUDE_TABLES:
            cprint(f"Skipped (excluded): rec_{table_name}.sql", "warning")
            skipped_count += 1
        else:
            if create_model(table_name):
                created_count += 1

    cprint(f"Summary: {created_count} created, {skipped_count} skipped", "info")
    
    # Run dbt to build replica schema
    cprint("Building replica schema...", "info")
    if run_dbt_replica(args.target):
        cprint("Replica schema update completed successfully!", "success")
    else:
        cprint("Replica schema update failed!", "error")


if __name__ == "__main__":
    main()
