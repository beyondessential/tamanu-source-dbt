# Setup Workflow - tamanu-dbt-project

## Initial Project Setup

### 1. Environment Preparation
- **Required**: Python 3.8+ installed
- **Required**: PostgreSQL database access to Tamanu instance
- **Required**: Git for version control
- **Required**: PowerShell as default CLI environment
- Clone the tamanu-dbt-* repository to local machine
- Navigate to project directory in PowerShell

### 2. Virtual Environment Setup
- Create virtual environment: `python -m venv .venv`
- **Required**: Upgrade pip after creating virtual environment: `python.exe -m pip install --upgrade pip`
- **Required**: Enhance virtual environment activation script to automatically load .env file:
  - Add .env file loading functionality to `.venv/Scripts/Activate.ps1`
  - This ensures environment variables are automatically available when activating the virtual environment
- Activate virtual environment: `.venv/Scripts/Activate.ps1`
- Install Python dependencies: `pip install -r requirements.txt`
### 3. Environment Configuration
- Copy environment template: `Copy-Item .env.example .env`
- **Required**: Update .env.example file with country-specific environment variable names
  - Use 2-letter country code format (e.g., TAMANU_FJ_* for Fiji, TAMANU_AU_* for Australia)
  - Include all environment types: demo, clone, replica, prod
- **Required**: Human must manually update .env file with actual database credentials:
  - Database host, port, username, password
  - Database name for Tamanu instance
  - Any additional environment-specific variables
- **Verify database connectivity** before proceeding

### 4. Project Configuration Files

#### Update `dbt_project.yml`:
- Update `name` field to match project (e.g., `tamanu_dbt_palau`)
- Update `profile` field to match project name
- Update `version` to match current Tamanu version
- **Verify date/time formatting variables are present**:
  - `date_format: 'YYYY-MM-DD'`
  - `datetime_format: 'YYYY-MM-DD HH24:MI:SS'`
  - `datetime_without_seconds_format: 'YYYY-MM-DD HH24:MI'`
  - `time_format: 'HH24:MI'`
  - `yearmonth_format: 'YYYY-MM'`

#### Update `config/profiles.yml`:
- Update profile name to match project (e.g., tamanu_dbt_fiji)
- **Required**: Update environment variable names to match country-specific format
  - Use 2-letter country code (e.g., TAMANU_FJ_* for Fiji)
  - Update all environment types: demo, clone, replica
- Configure target environments (replica, demo, clone, prod)
- Ensure database connection details reference environment variables
- **Test connection configuration**

#### Update `packages.yml`:
- Update `revision` to match Tamanu version (use specific version tags for production)
- Verify tamanu-source-dbt package dependency is correctly configured
- **Use git tags for production deployments, not branch references**

### 5. Install dbt Dependencies
- Run `dbt deps` to install package dependencies
- **Required**: Run `dbt debug --profiles-dir config` to test database connection
- **All connection tests must pass** before proceeding
- Verify tamanu-source-dbt package is correctly installed in `dbt_packages/`

## Project Customisation

### 6. Generate Project-Specific Models
- **Required**: Generate survey models based on current database schema
- Run `python dbt_packages/tamanu_source_dbt/scripts/generate_survey_models.py`
- **Required**: Build reporting assets for project
- Run `python dbt_packages/tamanu_source_dbt/scripts/build_reporting_assets.py`
- Verify generated models are created in `models/surveys/` directory

### 7. Initial Build and Validation
- **Required**: Test model compilation: `dbt compile --profiles-dir config`
- **Required**: Run base models to verify setup: `dbt run --select bases --profiles-dir config`
- **Critical**: If base models fail, address database schema issues before proceeding
- **Required**: Run full build: `dbt run --profiles-dir config`
- **Required**: Run all tests: `dbt test --profiles-dir config`
- **All tests must pass** before proceeding with development
- Address any compilation or test failures immediately

### 8. Validate Report Configurations
- **Required**: Run `python dbt_packages/tamanu_source_dbt/scripts/validate_report_configs.py`
- **All validation errors must be resolved** before development
- Verify all report config files in `models/reports/config/` are valid JSON
- Check that config files conform to the JSON schema

## Development Environment Verification

### 9. Code Style Setup
- **Required**: Verify `.sqlfluff` configuration is present
- **Optional**: Code style validation can be skipped during initial setup
- For development work: Set DBT_PROFILES_DIR environment variable before running sqlfluff
- Run `sqlfluff lint models` to check code style compliance (if needed)
- **Required**: Run `sqlfluff fix models` to format existing code (if needed)
- Ensure all SQL files pass linting before development begins

### 10. Documentation Generation
- Run `dbt docs generate --profiles-dir config` to create initial documentation
- **Optional**: Run `dbt docs serve` to review documentation locally
- Verify all package models and documentation are accessible

### 11. Translation Setup
- Run `python dbt_packages/tamanu_source_dbt/scripts/generate_translation_file.py`
- Run `python dbt_packages/tamanu_source_dbt/scripts/check_translation_duplicates.py`
- **Address any duplicate stringIds found** before development
- Review translation patterns for project-specific customisations

## Final Setup Verification

### 12. Complete Build Test
- **Required**: Run full build: `dbt run --profiles-dir config`
- **Required**: Run all tests: `dbt test --profiles-dir config`
- **Required**: Validate all configurations: `python dbt_packages/tamanu_source_dbt/scripts/validate_report_configs.py`
- **All steps must complete successfully** for setup to be considered complete

### 13. Generate Report Inventory
- Run `python dbt_packages/tamanu_source_dbt/scripts/list_tamanu_reports.py`
- Verify `list_tamanu_reports.md` is generated with current report inventory
- Review available reports for project-specific requirements

### 14. Version Alignment Verification
- **Required**: Verify project version in `dbt_project.yml` matches Tamanu version
- **Required**: Verify package version in `packages.yml` matches Tamanu version
- Document any version discrepancies and resolution plan
- **Version alignment is critical for production deployments**

## Post-Setup Development Readiness

### Daily Development Workflow Setup
- **Always activate virtual environment first**: `.venv/Scripts/Activate.ps1`
- **Standard development sequence**:
  1. Update dependencies if needed: `dbt deps`
  2. Work on models following layer hierarchy
  3. Format code: `sqlfluff fix`
  4. Test changes: `dbt test --profiles-dir config`
  5. Build models: `dbt run --profiles-dir config`

### Project-Specific Development Guidelines
- **Custom models**: Create in `models/datasets/` and `models/reports/` only
- **Documentation**: Required for all custom models except reports
- **Testing**: Implement integrity tests for all custom models
- **Translations**: Check for existing translations before creating new ones
- **Configuration**: Each report requires corresponding config file in `models/reports/config/`

## Troubleshooting Common Setup Issues

### Connection Issues
- Verify `.env` file configuration and database credentials
- Test with `dbt debug --profiles-dir config`
- Check network access to database server
- Verify PostgreSQL client compatibility

### Package Issues
- Ensure correct package version in `packages.yml`
- Run `dbt deps --upgrade` to refresh packages
- Check package repository access and authentication
- Verify git access to tamanu-source-dbt repository

### Model Generation Issues
- Verify database contains survey data for generation scripts
- Check Python script permissions and dependencies
- Ensure virtual environment is activated
- Review script output for specific error messages

### Validation Failures
- Review specific validation error messages
- Check JSON syntax in report configuration files
- Verify schema compliance for all configurations
- Address data quality issues in source database
