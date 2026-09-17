import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from utils import (
    cprint,
    execute_command,
    generate_reporting_schema_script,
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

CALLBACK_URL = os.environ.get("SCHEMA_CALLBACK_URL", "").strip()

# The callback is the only way the schema leaves the container, and a caller
# that is refused or unreachable has nowhere else to put it, so a retryable
# answer is retried here rather than by running the whole build again.
CALLBACK_ATTEMPTS = 5
CALLBACK_BACKOFF_SECONDS = 2


def build():
    """Compile the project and write the reporting schema's SQL."""
    # The translation macro is generated rather than committed, and
    # macros/translations.sql calls it, so nothing compiles without it.
    generate_translation_macro()

    # Survey models are the half of a schema that follows from the deployment's
    # own configuration, and reading them is what needs the database.
    if DEPLOYMENT != "standard":
        cprint("Generating survey models...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'generate_survey_models.py'}")

    execute_command(f"dbt compile --profiles-dir config{get_dbt_target_arg()}")

    generate_reporting_schema_script()

    return os.path.join(VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql")


def deliver(sql):
    """POST the built schema to the callback, retrying what is worth retrying.

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
            with urllib.request.urlopen(request) as response:
                cprint(f"Delivered the schema ({response.status})", "success")
                return
        except urllib.error.HTTPError as err:
            # 503 is the caller saying it cannot take it yet. Anything else it
            # answers is about this build, and sending it again would answer
            # the same.
            retryable = err.code == 503
            if not retryable:
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
    """Build a reporting schema for one version and deployment, and hand it back.

    Narrower than build_reporting_assets: no docs, no report configs, and no
    `dbt run`, since what this builds is read out of the compiled manifest and
    the database it reads is not this build's to write to.
    """
    cprint(f"\nBuilding reporting schema v{VERSION} ({DEPLOYMENT})", "info")

    schema_file = build()

    if not CALLBACK_URL:
        # Nowhere to deliver it: the local case, where the file is the output.
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
