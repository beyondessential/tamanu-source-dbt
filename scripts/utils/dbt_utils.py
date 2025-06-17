import os
import re

from .file_utils import read_file, write_file

BASE_DIR = os.getcwd()


def hide_macros_from_docs():
    """
    Hides macros from the generated documentation by modifying the manifest.

    This function reads the manifest.json file, finds all macros, and updates
    the 'docs' section of each macro to set 'show' to False, preventing them
    from appearing in the documentation.

    Returns:
        None: The manifest is directly modified.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    macros = [key for key in manifest.get("macros", {}) if key.startswith("macro")]

    if not macros:
        print("No macros found.")
        return

    for macro in macros:
        manifest["macros"][macro].setdefault("docs", {})["show"] = False

    write_file(manifest_path, manifest, "json")


def hide_tests_from_docs():
    """
    Hides tests from the generated documentation by modifying the manifest.

    This function reads the manifest.json file, finds all tests, and updates
    the 'docs' section of each test to set 'show' to False, preventing them
    from appearing in the documentation.

    Returns:
        None: The manifest is directly modified.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    tests = [key for key in manifest.get("nodes", {}) if key.startswith("test")]

    if not tests:
        print("No tests found.")
        return

    for test in tests:
        manifest["nodes"][test].setdefault("docs", {})["show"] = False

    write_file(manifest_path, manifest, "json")


def get_deployment_version():
    """
    Retrieves the version of the dbt project from the dbt_project.yml file.

    Args:
        None

    Returns:
        str: The version of the dbt project as a string.

    Raises:
        ValueError: If the version is not found in the dbt_project.yml file.
    """
    try:
        config_path = os.path.join(BASE_DIR, "dbt_project.yml")
        contents = read_file(config_path)
        match = re.search(r"^version:\s*(.*)$", contents, re.MULTILINE)
        if match:
            return match.group(1).strip().strip("\"'")
        raise ValueError("Version not found in dbt_project.yml")
    except Exception as e:
        print(f"Error reading dbt_project.yml: {e}")
        exit(1)
