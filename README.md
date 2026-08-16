# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:

- raw (or source) schema
- reporting schema
- analytics schema (upcoming)

## AI Rules

This project includes AI rules for AI assistants located in the `ai/` directory.

To use these AI rules with Cline or Cursor, you need to create a symbolic link to the `ai/` directory to make the rules accessible to your AI assistant.

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
5. After merging, run locally: `python scripts/build_reporting_assets.py`

The GitHub Actions workflow updates the version and refreshes source models. After merging, you need to run the build script locally to prepare models and generate reporting assets (requires database connection).

## Refresh Tamanu source models
To refresh the source models from the Tamanu repository, execute the following command:
`python scripts/refresh_tamanu_source.py`

This command pulls the source model information from the Tamanu repository based on the version specified in the dbt_project.yml file. All models located under the `tamanu/database/model/central-server/public/` folder (remote tamanu repository) will be copied to the `models/sources/` folder (local repository).

## Build Reporting Assets

After upgrading the Tamanu version (via GitHub Actions), build the reporting assets:

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

The generated assets are saved in the `compiled/` folder. The documentation is versioned and placed in a subfolder:
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

## Versioning

We will use semantic versioning `< major >`.`< minor >`.`< patch >`. This number will mirror Tamanu's release
`< major >`.`< minor >` version numbers with the `< patch >` number for patching within this repository.

## Creating a release

A release is a version bump **and** a compiled bundle, in one PR, followed by a tag.
Both halves matter: publishing is driven by the tag, but it uploads the bundle committed
under `compiled/v<version>/`. Tagging a version with no bundle behind it publishes
nothing — the upload fails on a path that does not exist, or is skipped silently.

Releases are usually cut from the maintenance branch for the version (`2.60`, `2.59`, …),
not from `main`. `main` carries the next in-development version.

### The short way

From the version branch you are releasing:

```bash
python scripts/prepare_release.py
```

This works out the next patch version, cuts a `release/vX.Y.Z` branch, stamps
`dbt_project.yml` and `pyproject.toml`, builds the reporting assets, diffs the result
against the last released bundle, and drafts the commit message and PR body under
`target/`. It stops before committing — add `--commit` to have the commit made — and
never pushes or opens the PR.

Before building anything it checks that dbt resolves to the release database matching the
version being released. Building against the wrong database — a stale `.env` still
pointing at another version, or a deployment replica — produces artefacts that look
completely valid and are wrong for the branch. Use `--dry-run` to see what it would do,
and `--no-db-check` only when preparing a release from an already-built bundle.

### The steps it performs

1. Bump the version in `dbt_project.yml` and `pyproject.toml`
2. Build the bundle (see [Build Reporting Assets](#build-reporting-assets)); commit the
   three aggregate artefacts under `compiled/v<version>/`. The per-report JSONs are
   gitignored build output
3. Open a PR against the version branch and merge it (merge commit, not squash)
4. Then draft a GitHub release: choose the version branch, tag it `vX.Y.Z`, and publish

Publishing the release is what triggers `publish-artifacts.yml`, which uploads the bundle
to S3 and registers it with the meta-server. Never upload bundles by hand. If a release
publishes nothing, check that `compiled/v<version>/` was committed before the tag was cut.
