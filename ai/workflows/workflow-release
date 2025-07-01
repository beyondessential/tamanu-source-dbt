# Release Workflow

## Pre-Release Steps

### 1. Update Version Number
- Version number is required and is updated in `dbt_project.yml` in the field "version"
- Current version format follows semantic versioning (e.g., "2.33.1")
- Check with user if it is a minor or patch version update:
  - Minor version: New features or significant updates (increment middle number, e.g., 2.33.1 → 2.34.0)
  - Patch version: Bug fixes or minor improvements (increment last number, e.g., 2.33.1 → 2.33.2)
  - Major version: Breaking changes (increment first number, e.g., 2.33.1 → 3.0.0)

### 2. Refresh Tamanu Source
- Run `python scripts/refresh_tamanu_source.py` to refresh the source data definitions
- This ensures the latest schema changes from the Tamanu system are incorporated

### 3. Build Reporting Assets
- Execute `python scripts/build_reporting_assets.py` to generate reporting assets
- This step builds the necessary components for the reporting layer

### 4. Validate and Test Release
- **Required**: Run comprehensive validation and testing before release
- Execute the following commands in sequence:
  1. `dbt test --profiles-dir config` - Run all data integrity and business logic tests
  2. `python scripts/validate_report_configs.py` - Validate report configuration files
  3. `sqlfluff lint models` - Check SQL code style compliance
- **All validation steps must pass** before proceeding with release
- Address any test failures or validation errors before continuing
- Verify that all models in the data flow (sources → bases → datasets → reports) are functioning correctly
- Ensure documentation is up-to-date for any new or modified models

### 5. Generate Translation File and Check for Duplicates
- Run `python scripts/generate_translation_file.py` to generate the translation file for the current version
- Run `python scripts/check_translation_duplicates.py` to check for duplicate stringIds in the translation file
- **Address any duplicate stringIds found** - these must be resolved before release
- Duplicate default values are acceptable but should be reviewed for consistency

### 6. List Tamanu Reports
- Run `python scripts/list_tamanu_reports.py` to generate an updated list of available reports
- This creates or updates the report inventory for the release

### 7. Build All Models
- Run `dbt run --profiles-dir config` to build all models and ensure they compile and run successfully
- This final step confirms that all changes work together correctly
