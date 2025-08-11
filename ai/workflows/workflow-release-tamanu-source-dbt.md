# Release Workflow for AI Assistants

## Version Update
- Update version in `dbt_project.yml` following semantic versioning
- Ask user for version type:
  - **Patch** (bug fixes): 2.33.1 → 2.33.2
  - **Minor** (new features): 2.33.1 → 2.34.0
  - **Major** (breaking changes): 2.33.1 → 3.0.0

## Pre-Release Commands
Execute in order:

1. **Refresh source data**: `python scripts/refresh_tamanu_source.py`
2. **Build reporting assets**: `python scripts/build_reporting_assets.py`
3. **Validate everything**:
   - `python scripts/validate_report_configs.py`
   - `python scripts/check_translations.py`
4. **Update report list**: `python scripts/list_tamanu_reports.py`

## Validation Requirements
- All tests must pass before release
- No validation errors allowed
- Resolve any duplicate translation stringIds
- Verify all models compile and run successfully

## Notes for AI Assistants
- Always run commands in the specified order
- Stop and fix issues before proceeding to next step
- Confirm each step completes successfully before continuing
- Ensure virtual environment is activated before running Python scripts
