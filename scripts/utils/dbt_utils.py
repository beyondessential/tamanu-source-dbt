import os

import yaml

from .file_utils import read_file, write_file
from .system_utils import cprint

BASE_DIR = os.getcwd()


def get_dbt_project_config():
    """
    Retrieves the configuration of the dbt project from the dbt_project.yml file.

    Returns:
        dict: The configuration of the dbt project.
    """

    try:
        config_path = os.path.join(BASE_DIR, "dbt_project.yml")
        with open(config_path, "r") as f:
            return yaml.safe_load(f)
    except Exception as e:
        cprint(f"Error reading dbt_project.yml: {e}", "error")
        exit(1)


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
        cprint("No macros found.", "error")
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
        cprint("No tests found.", "error")
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
        config = get_dbt_project_config()
        return config.get("version")
    except Exception as e:
        cprint(f"Error reading version: {e}", "error")
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
        config = get_dbt_project_config()
        vars = config.get("vars", {})

        if param_name is None:
            return vars

        return vars.get(param_name)

    except Exception as e:
        cprint(f"Error reading dbt_project.yml: {e}", "error")
        exit(1)


def get_project_name() -> str:
    """
    Retrieves the name of the dbt project from the dbt_project.yml file.
    """
    try:
        config = get_dbt_project_config()
        return config.get("name")
    except Exception as e:
        cprint(f"Error reading name: {e}", "error")
        exit(1)


def get_deployment_name() -> str:
    """
    Retrieves the deployment name of the dbt project from the project name.
    """
    try:
        project_name = get_project_name()
        if project_name == "tamanu_source_dbt":
            return "standard"
        else:
            return project_name.replace("tamanu_dbt_", "")
    except Exception as e:
        cprint(f"Error extracting deployment name: {e}", "error")
        exit(1)
