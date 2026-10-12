# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:

- raw (or source) schema
- reporting schema
- analytics schema (upcoming)

## AI Rules

This project includes AI rules for AI assistants located in the `ai/` directory.

To use these AI rules with Cline or Cursor, you need to create a symbolic link to the `ai/` directory to make the rules accessible to your AI assistant.

## Local development

Python and dbt dependencies are managed with [uv](https://docs.astral.sh/uv/) from
`pyproject.toml`. Run project commands through `uv run` — it syncs the virtualenv
automatically — and pass `--env-file .env` to load the database credentials and
`DBT_PROFILES_DIR`:

```bash
cp .env.example .env                    # then fill in real values
uv run --env-file .env dbt deps         # one-time: install dbt packages (from hub.getdbt.com)
uv run --env-file .env dbt build        # build + test
uv run --env-file .env sqlfluff lint models
```

`.env` (copied from `.env.example`) provides the DB connection vars plus
`DBT_PROFILES_DIR=config`, so dbt finds `config/profiles.yml` without a `--profiles-dir`
flag. Run `dbt deps` once before building or linting. There is no session-start hook or
manual `venv` activation — `uv run` handles the environment.

## SQL linting

We use SQLFluff and the configuration file is located in the root folder and is named `.sqlfluff`.

There are two commands available to run:

- `sqlfluff lint models` - Lints the file (does not apply fix)
- `sqlfluff fix models` - Fixes the SQL files

## Upgrading Tamanu Version

**Automated Upgrade (Recommended):** Use the GitHub Actions workflow to automatically upgrade to the latest Tamanu version or specify a version manually.

Quick start:
1. Go to Actions → "Tamanu Version Upgrade"
2. Click "Run workflow"
3. Leave version empty for auto-detection or specify a version
4. Review and merge the generated PR

The GitHub Actions workflow updates the version and refreshes source models.

## Refresh Tamanu source models
To refresh the source models from the Tamanu repository, execute the following command:
`python scripts/refresh_tamanu_source.py`

This command pulls the source model information from the Tamanu repository based on the version specified in the dbt_project.yml file. All models located under the `tamanu/database/model/central-server/public/` folder (remote tamanu repository) will be copied to the `models/sources/` folder (local repository).

## Build Reporting Assets

`tamanu-dbt-*` deployment repos build their reporting bundle with this script, run from
`dbt_packages/tamanu_source_dbt/scripts/`. Run it here only to check that the models
build (requires a database connection):

```bash
python scripts/build_reporting_assets.py
```

This script performs the following steps:
1. Generate survey models (for non-standard deployments)
2. Validate report configurations
3. Process translations (check, generate macro, convert to Excel)
4. Clean and prepare dbt environment
5. Build dbt models and documentation
6. Generate language-specific reports for all supported languages
7. List all Tamanu reports

The generated assets are saved in the `compiled/` folder, which is gitignored. Run
`python scripts/compile_manifest.py` afterwards to list the reports a build produced.
The documentation is versioned and placed in a subfolder:
- Dataset SQL scripts: `compiled/views/reporting_schema_build_script.sql`
- Compiled report JSON files: `compiled/reports/`
- Import script: `compiled/reports/importReports.js`
- Versioned documentation: `compiled/v{VERSION}/reporting-docs-v{VERSION}-{DEPLOYMENT}.html`

## Sensitive Facility Reporting

Set `has_sensitive_facility: true` in the `vars` block of `dbt_project.yml` to include models
tagged `restricted` (sensitive-facility dataset views) when generating reports and the reporting
schema script. When `false` (the default), those models are silently excluded from both
`generate_project_reports()` and `generate_reporting_schema_script()`.

The flag is read at script run-time from `dbt_project.yml` via `get_dbt_project_vars()`, not
from the dbt runtime context, so it must be set in the file before running the build scripts.

## Generate survey models
To automatically generate dbt models and documentation for surveys from database, execute the following command:
```
python scripts/generate_survey_models.py
```
This will generate models and documentation for all surveys in the Tamanu database.

## Script to list Tamanu reports

This script generates a list of all reports in the repository and outputs the result in a Markdown file.

### Usage
To generate a report list:

```
python list_tamanu_reports.py
```

## Importing reports to a deployment

To import the compiled report definitions (and optionally a reporting schema) into a
central server running on Kubernetes, use the scripts in
[scripts/import-reports/](scripts/import-reports/). There is a PowerShell version for
Windows (`import-reports-k8s.ps1`) and an equivalent Bash version for macOS/Linux
(`import-reports-k8s.sh`). They switch the kubectl context first and **default to the
demo cluster** (configurable via `--context` / `-Context`), and default to a read-only
plan, only writing when re-run with `-Apply` / `--apply`. See
[scripts/import-reports/README.md](scripts/import-reports/README.md) for prerequisites,
options, and examples.

## Versioning

We will use semantic versioning `< major >`.`< minor >`.`< patch >`. This number will mirror Tamanu's release
`< major >`.`< minor >` version numbers with the `< patch >` number for patching within this repository.

## Creating a release

A release is a version stamp followed by a tag. No bundle is built or committed here:
Canopy builds the reporting schema through `build-schema-image.yml`, and `tamanu-dbt-*`
repos build their own bundle from the tag they pin in `packages.yml`.

Releases are usually cut from the maintenance branch for the version (`2.60`, `2.59`, …),
not from `main`. `main` carries the next in-development version.

1. Run the **Release** workflow (Actions → Release → Run workflow) with the branch to
   release. Leave the version empty for the branch's current version if it is untagged
   (such as the `vX.Y.0` that a Tamanu upgrade sets on `main`), otherwise the next patch.
   It stamps `dbt_project.yml` and `pyproject.toml` and opens a `release: vX.Y.Z` PR
   against that branch; if both already carry the version, it opens no PR.
2. Merge the PR.
3. Publish a GitHub release: tag `vX.Y.Z`, target the same branch, generate the notes.
   Only the Maui team can create `v*` tags. Publishing a `vX.Y.0` release also runs
   `create-version-branch.yml`.

## Licence

Copyright (C) 2026 BES International Limited.

This project is licensed under the GNU General Public License, Version 3.0
([LICENSE](LICENSE)) or <https://www.gnu.org/licenses/gpl-3.0-standalone.html>, or any
later version of that licence, at your option.

`models/sources/` and `models/logs/` are not authored here. They are copied verbatim from
`database/model/public` and `database/model/logs` in
[beyondessential/tamanu](https://github.com/beyondessential/tamanu) by
`scripts/refresh_tamanu_source.py`, and re-synced on every Tamanu upgrade. Those files fall
under Tamanu's default GPL 3.0-or-later terms. Edit them upstream, not here.
