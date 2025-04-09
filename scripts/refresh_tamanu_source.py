import os
import shutil
import sys
import tempfile
from pathlib import Path

from utils import (
    copy_files_from_directory,
    execute_command,
    get_deployment_version,
    remove_directory,
)

REPO_URL = "https://github.com/beyondessential/tamanu.git"

BASE_DIR = Path(__file__).resolve().parent.parent
TEMP_DIR = Path(tempfile.gettempdir()) / "tamanu"
DBT_SOURCE_DIR = BASE_DIR / "models" / "sources"
REPO_SOURCE_DIR = TEMP_DIR / "database" / "model" / "public"


def main():
    version = get_deployment_version()
    branch_name = f"release/{'.'.join(version.split('.')[:2])}"
    print(f"\n\nDetected version: {version}")
    print(f"Cloning branch '{branch_name}' from repository '{REPO_URL}'")

    execute_command(f"git clone --branch {branch_name} --depth 1 {REPO_URL} {TEMP_DIR}")
    copy_files_from_directory(REPO_SOURCE_DIR, DBT_SOURCE_DIR)
    remove_directory(TEMP_DIR)
    print("\nFiles copied successfully!")


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)
