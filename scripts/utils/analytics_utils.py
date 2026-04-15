import json
import os
from pathlib import Path
from typing import Any, Dict, List

import yaml

from .dbt_utils import get_deployment_name, get_deployment_version, get_project_name
from .file_utils import ensure_directory_exists
from .system_utils import cprint

BASE_DIR = os.getcwd()
PROJECT_NAME = get_project_name()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def load_manifest(manifest_path: str) -> Dict[str, Any]:
    """Load the dbt manifest.json file."""
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Manifest file not found at {manifest_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in manifest file: {e}")


def is_empty_value(value):
    """Check if a value is empty, null, or contains only empty values."""
    if value is None:
        return True
    if isinstance(value, str) and not value.strip():
        return True
    if isinstance(value, (list, tuple)) and not value:
        return True
    if isinstance(value, dict):
        if not value:
            return True
        # Check if all values in dict are empty
        return all(is_empty_value(v) for v in value.values())
    return False


def clean_dict(data):
    """Recursively remove empty/null values from a dictionary."""
    if not isinstance(data, dict):
        return data

    cleaned = {}
    for key, value in data.items():
        if is_empty_value(value):
            continue

        if isinstance(value, dict):
            cleaned_value = clean_dict(value)
            if cleaned_value:  # Only add if the cleaned dict is not empty
                cleaned[key] = cleaned_value
        elif isinstance(value, list):
            cleaned_list = []
            for item in value:
                if isinstance(item, dict):
                    cleaned_item = clean_dict(item)
                    if cleaned_item:
                        cleaned_list.append(cleaned_item)
                elif not is_empty_value(item):
                    cleaned_list.append(item)
            if cleaned_list:
                cleaned[key] = cleaned_list
        else:
            cleaned[key] = value

    return cleaned


def extract_bases_models(manifest: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract all models from the bases folder."""
    bases_models = []

    # Get all nodes from the manifest
    nodes = manifest.get("nodes", {})

    for node_id, node_data in nodes.items():
        # Check if this is a model node and if it's in the bases folder
        if (
            node_data.get("resource_type") == "model"
            and "models/bases/" in Path(node_data.get("original_file_path", "")).as_posix()
        ):
            # Extract relevant information
            config_data = node_data.get("config", {})
            config_tags = config_data.get("tags", [])

            model_info = {
                "name": node_data.get("name"),
                "description": node_data.get("description", ""),
                "config": {"tags": config_tags} if config_tags else {},
                "tags": node_data.get("tags", []),
                "meta": node_data.get("meta", {}),
            }

            # Extract column information, excluding columns tagged as direct_identifier
            columns = node_data.get("columns", {})
            if columns:
                model_info["columns"] = {}
                for col_name, col_data in columns.items():
                    # Skip columns tagged as direct_identifier
                    col_tags = col_data.get("tags", [])
                    if "direct_identifier" in col_tags:
                        continue

                    col_info = {
                        "name": col_name,
                        "description": col_data.get("description", ""),
                        "data_type": col_data.get("data_type"),
                        "meta": col_data.get("meta", {}),
                        "tags": col_tags,
                    }
                    model_info["columns"][col_name] = col_info

            # Clean the model_info to remove empty/null values
            cleaned_model_info = clean_dict(model_info)
            if cleaned_model_info:
                bases_models.append(cleaned_model_info)

    # Sort by model name for consistent output
    bases_models.sort(key=lambda x: x["name"])

    return bases_models


def print_bases_models_summary(models: List[Dict[str, Any]]) -> None:
    """Print a summary of the extracted bases models."""
    cprint("\n=== BASES MODELS SUMMARY ===", "info")
    cprint(f"Total models found: {len(models)}", "info")
    cprint(f"{'Model Name':<40} {'Columns':<10}", "info")
    cprint("-" * 60, "info")

    for model in models:
        col_count = len(model.get("columns", {}))
        cprint(f"{model['name']:<40} {col_count:<10}", "info")


def save_bases_models_to_yaml(models: List[Dict[str, Any]], output_path: str) -> None:
    """Save the extracted bases models to a YAML file."""
    ensure_directory_exists(os.path.dirname(output_path))
    with open(output_path, "w", encoding="utf-8") as f:
        yaml.dump(models, f, default_flow_style=False, allow_unicode=True, indent=2)


def generate_analytics_metadata():
    """Generate analytics metadata from dbt manifest."""
    # Set up paths - output to versioned directory with analytics_metadata prefix
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    output_path = os.path.join(VERSION_DIR, f"analytics-metadata-v{VERSION}-{DEPLOYMENT}.yml")

    try:
        # Load manifest and extract bases models
        manifest = load_manifest(manifest_path)
        bases_models = extract_bases_models(manifest)

        if not bases_models:
            cprint("No models found in the bases folder.", "warning")
            return

        # Save detailed information to YAML in versioned directory
        save_bases_models_to_yaml(bases_models, output_path)

        # Print concise summary
        total_columns = sum(len(model.get("columns", {})) for model in bases_models)
        cprint(
            f"Extracted {len(bases_models)} bases models with {total_columns} total columns",
            "success",
        )

    except Exception as e:
        cprint(f"Error: {e}", "error")
        raise
