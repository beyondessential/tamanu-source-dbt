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
from utils.system_utils import cprint

REPO_URL = "https://github.com/beyondessential/tamanu.git"

BASE_DIR = Path(__file__).resolve().parent.parent
TEMP_DIR = Path(tempfile.gettempdir()) / "tamanu"
DBT_SOURCE_DIR = BASE_DIR / "models" / "sources"
DBT_LOG_DIR = BASE_DIR / "models" / "logs"
REPO_SOURCE_DIR = TEMP_DIR / "database" / "model" / "public"
REPO_LOG_DIR = TEMP_DIR / "database" / "model" / "logs"


def main():
    version = get_deployment_version()
    branch_name = f"release/{'.'.join(version.split('.')[:2])}"
    cprint(f"\n\nDetected version: {version}", "info")
    cprint(f"Cloning branch '{branch_name}' from repository '{REPO_URL}'", "info")

    execute_command(f"git clone --branch {branch_name} --depth 1 {REPO_URL} {TEMP_DIR}")
    copy_files_from_directory(REPO_SOURCE_DIR, DBT_SOURCE_DIR)
    copy_files_from_directory(REPO_LOG_DIR, DBT_LOG_DIR)

    # Delete overview.md from the sources directory
    overview_file = DBT_SOURCE_DIR / "overview.md"
    if overview_file.exists():
        overview_file.unlink()
        cprint("Deleted overview.md from the sources directory.", "success")

    remove_directory(TEMP_DIR)
    cprint("\nFiles copied successfully!", "success")


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
