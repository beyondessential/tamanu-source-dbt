import os
from pathlib import Path

from utils.dbt_utils import get_deployment_name, get_deployment_version
from utils.file_utils import ensure_directory_exists, read_file, write_file
from utils.system_utils import cprint

BASE_DIR = Path.cwd()
VERSION = get_deployment_version()
DEPLOYMENT = get_deployment_name()

COMPILED_DIR = BASE_DIR / "compiled"
VERSION_DIR = COMPILED_DIR / f"v{VERSION}"
MANIFEST_FILE = COMPILED_DIR / "manifest.json"


def main():
    cprint(f"Compiling manifest for deployment: {DEPLOYMENT} - {VERSION}", "info")

    if not COMPILED_DIR.exists() or not VERSION_DIR.exists():
        cprint(
            "Please run build_reporting_assets.py first to generate compiled assets",
            "error",
        )
        return

    version = ".".join(VERSION.split(".")[:2])
    schema = f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql"
    reports = [f.name for f in VERSION_DIR.glob("*.json")]

    entry = {
        "tamanu": f"~{version}.0",
        "schema": schema,
        "reports": sorted(reports),
    }

    if MANIFEST_FILE.exists():
        manifest = read_file(MANIFEST_FILE, "json")
    else:
        manifest = {"deploymentName": DEPLOYMENT, "versions": []}

    manifest["versions"].append(entry)
    manifest["versions"].sort(key=lambda x: x["tamanu"], reverse=True)

    write_file(MANIFEST_FILE, manifest, "json")
    cprint(
        f"Manifest updated: {len(reports)} reports added for version {version}",
        "success",
    )


if __name__ == "__main__":
    main()
