import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import yaml

from utils import (
    cprint,
    execute_command,
    generate_reporting_schema_script,
    get_dbt_project_config,
    get_dbt_target_arg,
    get_deployment_name,
    get_deployment_version,
)
from generate_translation_macro import generate_translation_macro


BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
SCRIPTS_DIR = (
    Path("scripts")
    if DEPLOYMENT == "standard"
    else Path("dbt_packages") / "tamanu_source_dbt" / "scripts"
)
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")

PROFILES_PATH = Path("config") / "profiles.yml"
TARGET = os.environ.get("TAMANU_DBT_TARGET", "").strip() or "replica"

CALLBACK_URL = os.environ.get("SCHEMA_CALLBACK_URL", "").strip()
CALLBACK_ATTEMPTS = 5
CALLBACK_BACKOFF_SECONDS = 2
CALLBACK_TIMEOUT_SECONDS = 60


def write_profile():
    """Write the profile the build connects through, over the deployment's own.

    Each deployment repo names its targets and the env vars behind them for
    itself, so there is no set of credentials pgro can supply that every one of
    them reads.
    """
    config = get_dbt_project_config()
    profile = config.get("profile") or config.get("name")

    PROFILES_PATH.parent.mkdir(parents=True, exist_ok=True)
    PROFILES_PATH.write_text(
        yaml.safe_dump(
            {
                profile: {
                    "target": TARGET,
                    "outputs": {
                        TARGET: {
                            "type": "postgres",
                            "threads": 1,
                            "host": "{{ env_var('TAMANU_DL_DB_URL') }}",
                            "port": 5432,
                            "user": "{{ env_var('TAMANU_DL_DB_USER') }}",
                            "password": "{{ env_var('TAMANU_DL_DB_PASSWORD') }}",
                            "dbname": "{{ env_var('TAMANU_DL_DB_DATABASE') }}",
                            "schema": "reporting",
                        }
                    },
                }
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )

    cprint(f"Connecting as {profile}.{TARGET}", "info")


def build():
    """Compile the project and write the reporting schema's SQL."""
    # macros/translations.sql calls the generated macro, so nothing compiles without it.
    generate_translation_macro()

    if DEPLOYMENT != "standard":
        cprint("Generating survey models...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'generate_survey_models.py'}")

    # Two models run_query the table they pivot while compiling, so this has to be run, not compile.
    execute_command(f"dbt run --profiles-dir config{get_dbt_target_arg()}")

    generate_reporting_schema_script()

    return os.path.join(VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql")


def deliver(sql):
    """POST the built schema to the callback, retrying while it answers 503.

    Args:
        sql (bytes): The schema's SQL.

    Raises:
        RuntimeError: Where the callback refused it, or never took it.
    """
    for attempt in range(1, CALLBACK_ATTEMPTS + 1):
        request = urllib.request.Request(
            CALLBACK_URL,
            data=sql,
            method="POST",
            headers={"Content-Type": "application/sql"},
        )

        try:
            with urllib.request.urlopen(request, timeout=CALLBACK_TIMEOUT_SECONDS) as response:
                cprint(f"Delivered the schema ({response.status})", "success")
                return
        except urllib.error.HTTPError as err:
            if err.code != 503:
                raise RuntimeError(f"the callback answered {err.code}") from err
            reason = f"answered {err.code}"
        except urllib.error.URLError as err:
            reason = f"could not be reached: {err.reason}"

        if attempt == CALLBACK_ATTEMPTS:
            raise RuntimeError(f"the callback {reason} on every attempt")

        wait = CALLBACK_BACKOFF_SECONDS * 2 ** (attempt - 1)
        cprint(f"The callback {reason}; retrying in {wait}s", "warning")
        time.sleep(wait)


def main():
    """Build a reporting schema for one version and deployment, and hand it back."""
    # The checkout's dbt_project.yml version trails the replica's, so a delivery must name its own.
    if CALLBACK_URL and not os.environ.get("TAMANU_VERSION", "").strip():
        raise RuntimeError("TAMANU_VERSION names the version to build for, and is unset")

    # Only where pgro supplies the credentials: a local run keeps its own profile.
    if os.environ.get("TAMANU_DL_DB_URL", "").strip():
        write_profile()

    cprint(f"\nBuilding reporting schema v{VERSION} ({DEPLOYMENT})", "info")

    schema_file = build()

    if not CALLBACK_URL:
        cprint(f"\n✓ Built {schema_file}", "success")
        return

    sql = Path(schema_file).read_bytes()
    if not sql:
        raise RuntimeError("the build produced an empty schema")

    cprint(f"Delivering {len(sql)} bytes", "info")
    deliver(sql)

    cprint(f"\n✓ Build complete for version {VERSION}", "success")


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
