import os
import re
from pathlib import Path

import yaml

from .file_utils import read_file, write_file
from .system_utils import execute_command_with_output

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))


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


def get_dbt_project_vars(param_name: str = None) -> dict | str:
    """
    Read and parse the dbt_project.yml file to get variable values.

    Args:
        param_name (str, optional): The name of the specific parameter to retrieve.
            If None, returns all variables.

    Returns:
        dict | str: If param_name is None, returns a dictionary containing all variables.
            If param_name is provided, returns the value of that specific parameter.
            Returns None if the parameter is not found.
    """
    try:
        config_path = os.path.join(BASE_DIR, "dbt_project.yml")
        with open(config_path, "r") as f:
            contents = yaml.safe_load(f)
        vars = contents.get("vars", {})

        if param_name is None:
            return vars

        return vars.get(param_name)

    except Exception as e:
        print(f"Error reading dbt_project.yml: {e}")
        return None


def get_surveys_from_dbt(profile="demoland"):
    """
    Get all surveys from the database using dbt using the get_surveys_list macro.

    Args:
        profile (str): The dbt profile target to use

    Returns:
        list: List of tuples containing (id, name) for each survey
    """
    surveys = []
    cmd = f"dbt run-operation get_surveys_list --target {profile} --profiles-dir config"

    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)

        if not result or result.returncode != 0:
            if result:
                print(f"Error running dbt command: {result.stderr}")
            return surveys

        for line in (result.stdout + result.stderr).split("\n"):
            if "SURVEY_DATA:" in line:
                parts = line.split("SURVEY_DATA:")[1].split("|")
                if len(parts) == 2:
                    surveys.append(tuple(part.strip() for part in parts))

        return surveys

    except Exception as e:
        print(f"Error getting surveys from dbt: {e}")
        return surveys
