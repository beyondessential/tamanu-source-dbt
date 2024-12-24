from datetime import datetime
import subprocess
import argparse
import json
import sys
import os

SCHEMA = "reporting"
ROLE = "tamanu_reporting"
MANIFEST_PATH = "../target/manifest.json"
COMPILED_MODELS_DIR = "../target/compiled/tamanu_source_dbt/models/"
VIEWS_DIR = "../compiled/views" 

def execute_command(command):
    """
    Run a command using subprocess.Popen and print output in real time.
    """
    print(f"\nRunning: {' '.join(command)}\n")
    
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    for stdout_line in process.stdout:
        print(stdout_line, end='') 

    for stderr_line in process.stderr:
        print(stderr_line, end='') 

    process.wait()

    if process.returncode != 0:
        print(f"Error while running command: {' '.join(command)}")
        sys.exit(1)

def file_exists(file_path):
    """Check if a file exists."""
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

def create_directory(DIR):
    """Create the directory if it doesn't exist."""
    if not os.path.exists(DIR):
        os.makedirs(DIR)

def generate_project_datasets(target):
    
    file_exists(MANIFEST_PATH)

    with open(MANIFEST_PATH, "r") as f:
        manifest = json.load(f)

    models = [m for m in manifest["nodes"] if m.split(".")[0] == 'model']
    processed_models, model_processing_levels = [], []

    while len(processed_models) < len(models):
        ready_to_process_models = [
            model for model in models
            if all(dep.split(".")[0] == 'source' or dep in processed_models
                   for dep in manifest["nodes"][model]["depends_on"]["nodes"]) 
            and model not in processed_models
        ]
        processed_models.extend(ready_to_process_models)
        model_processing_levels.append(ready_to_process_models)

    scripts = [
        f"CREATE SCHEMA IF NOT EXISTS {SCHEMA};",
        f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SCHEMA} GRANT SELECT ON TABLES TO {ROLE};"
    ]

    for level in model_processing_levels:
        for model in level:
            model_path = manifest["nodes"][model]["path"]
            model_database = manifest["nodes"][model]["database"]
            view_name = os.path.basename(model_path)[:-4]
            compiled_model_path = os.path.join(COMPILED_MODELS_DIR, model_path)
            if os.path.exists(compiled_model_path):
                with open(compiled_model_path, "r") as f:
                    sql = f.read()
                    sql = sql.replace(f'"{model_database}"."public"', f'"public"')
                    scripts.append(f'CREATE OR REPLACE VIEW "{SCHEMA}"."{view_name}" AS (\n{sql}\n);')
            else:
                print(f"Warning: Model file {compiled_model_path} not found.")

    create_directory(VIEWS_DIR)
    output_filename = os.path.join(VIEWS_DIR, f"{target}_datasets.sql")

    with open(output_filename, "w") as f:
        f.write("\n".join(scripts))

def main():
    parser = argparse.ArgumentParser(description='Deployment script to generate project-specific models and reports.')
    parser.add_argument('-t', '--target', default='demoland', help='Target profile for models and reports (defaults to "demoland")')
    args = parser.parse_args()

    print(f"Generating build script for {args.target}")
    execute_command(["dbt", "clean"])
    execute_command(["dbt", "deps"])
    execute_command(["dbt", "compile", "--target", args.target])

    generate_project_datasets(args.target)

if __name__ == "__main__":
    main()
