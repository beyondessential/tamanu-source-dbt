#!/usr/bin/env python3
"""
Script to validate Tamanu report configuration files against the JSON schema.
"""

import json
import os
from jsonschema import validate, ValidationError
import sys
from pathlib import Path
from typing import List, Tuple

from utils.dbt_utils import get_deployment_name

DEPLOYMENT = get_deployment_name()


def load_schema(schema_path: str) -> dict:
    """Load the JSON schema from file."""
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Schema file not found at {schema_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in schema file: {e}")
        sys.exit(1)


def validate_config_file(config_path: str, schema: dict) -> Tuple[bool, str]:
    """
    Validate a single configuration file against the schema.
    
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config_data = json.load(f)
        
        validate(instance=config_data, schema=schema)
        return True, ""
        
    except FileNotFoundError:
        return False, f"File not found: {config_path}"
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except ValidationError as e:
        return False, f"Schema validation error: {e.message}"
    except Exception as e:
        return False, f"Unexpected error: {e}"


def find_config_files(config_dir: str) -> List[str]:
    """Find all JSON configuration files in the specified directory."""
    config_path = Path(config_dir)
    if not config_path.exists():
        print(f"Error: Configuration directory not found: {config_dir}")
        print(f"  (current working directory: {Path.cwd()})")
        print("  Ensure this script is run from the project root.")
        sys.exit(1)
    
    json_files = list(config_path.glob("*.json"))
    # Exclude the schema file itself
    json_files = [f for f in json_files if f.name != "report-config-schema.json"]
    
    return [str(f) for f in json_files]


def main():
    """Main validation function."""
    # Initialize deployment and determine project root.
    # Uses cwd so this works when installed as a dbt package under dbt_packages/.
    # Must be run from the project root.
    DEPLOYMENT = get_deployment_name()
    PROJECT_ROOT = Path(os.getcwd())
    CONFIG_DIR = PROJECT_ROOT / "models/reports/config"
    BASE_PATH = PROJECT_ROOT if DEPLOYMENT == "standard" else PROJECT_ROOT / "dbt_packages/tamanu_source_dbt"
    SCHEMA_PATH = BASE_PATH / "scripts" / "report_validation" / "report-config-schema.json"

    # Load schema
    schema = load_schema(SCHEMA_PATH)

    # Find configuration files
    config_files = find_config_files(str(CONFIG_DIR))
    if not config_files:
        print("No configuration files found.")
        return

    # Validate each file
    valid_count = 0
    invalid_count = 0

    for config_file in sorted(config_files):
        file_name = Path(config_file).name
        is_valid, error_message = validate_config_file(config_file, schema)

        if is_valid:
            valid_count += 1
        else:
            print(f"INVALID: {file_name}: {error_message}")
            invalid_count += 1

    # Summary
    if invalid_count > 0:
        print(f"\n{invalid_count} of {len(config_files)} files failed validation")
        sys.exit(1)
    else:
        print(f"All {len(config_files)} configuration files are valid")


if __name__ == "__main__":
    main()
