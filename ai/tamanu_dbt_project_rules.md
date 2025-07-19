# AI Rules for tamanu-dbt-* Projects

## Project Overview
tamanu-dbt-* projects are country-specific dbt implementations that use tamanu-source-dbt as a package dependency. These projects transform Tamanu healthcare system data into optimised reporting schemas for specific deployments.

## Core Principles
- Always follow the established data flow: sources (including logs) → bases (including surveys) → datasets → reports
- Use tamanu-source-dbt package for standard models and extend with project-specific customisations
- Maintain data integrity and quality at each transformation layer
- Prioritise performance and readability in SQL code
- Ensure comprehensive documentation for all custom models

## Model Layer Requirements
When working with models, always respect the following hierarchy:

### `models/sources` and `models/logs` (Package-Managed)
- **Never modify**: Source and log definitions are managed in tamanu-source-dbt package
- Automatically available through package dependency
- Origin point for most documentation blocks and data integrity checks

### `models/bases` (Package-Managed)
- **Never modify**: Base models are managed in tamanu-source-dbt package
- Strips out deleted data and metadata from tables
- **Always filter out soft-deleted records and test patients using appropriate conditions**
- Shared with data warehouse as `staging` model

### `models/surveys` (Generated)
- **Generated using package scripts**: Use `python dbt_packages/tamanu_source_dbt/scripts/generate_survey_models.py`
- Handle form-based data collection and responses specific to project deployment
- Follow the same bases principles: filter out soft-deleted records and test patients
- **Regenerate when survey definitions change**

### `models/datasets` (Project-Specific)
- Build on top of `bases` models from package
- Create project-specific de-normalised data for reporting consumption
- **Focus on creating user-friendly, denormalised views**
- **No ORDER BY clauses** (intermediate transformation)

### `models/reports` (Project-Specific)
- Based on `datasets` models with customised translations applied
- **Apply translations consistently using established patterns**
- **Each report must have a corresponding config file in `models/reports/config/`** with `.json` extension
- **Only layer where ORDER BY clauses are permitted**
- **Use centralised date/time formatting variables** from `dbt_project.yml`

## Package Management
- **Required**: Use tamanu-source-dbt as package dependency in `packages.yml`
- **Version pinning**: Use specific version tags for production deployments
- **Update process**: Run `dbt deps` after updating package version
- **Script usage**: Use package scripts for generating surveys and building reporting assets

## Documentation Requirements
- **Mandatory**: Each custom model except those in `reports` must have a corresponding .yml file
- Include comprehensive name and description for both the model and all columns
- Maintain professional, clear, and respectful tone in all documentation
- Reference existing doc blocks from package when possible to maintain consistency
- **Always document new columns when adding them to existing models**

## Translation Management
- Keep translation string lists concise and avoid duplication
- **Always check for existing translations before creating new ones**
- Follow established naming conventions for translation keys
- **Use sentence casing for the second variable (display label) in translate functions** (e.g., "Patient name" not "patient_name" or "PATIENT_NAME")
- **Translation labels must be prefixed with a concept** (e.g., patient, user, encounter) to maintain organisation and avoid conflicts

## Code Style Standards
- **Mandatory**: Use `.sqlfluff` for SQL code style enforcement
- Run `sqlfluff fix` before committing changes
- Follow consistent indentation and formatting patterns
- Use meaningful aliases and avoid ambiguous column references
- **Always test SQL syntax before committing**
- **Use Australian English spelling** in all documentation, comments, and text (e.g., "optimise" not "optimize", "colour" not "color", "centre" not "center")
- **Sort order should only be applied in `models/reports`** - Do not use ORDER BY clauses in `models/datasets` as these are intermediate transformations
- **Use centralised date/time formatting variables** from `dbt_project.yml` in all reports: `to_char(field, '{{ var("date_format") }}')` for dates, `to_char(field, '{{ var("datetime_format") }}')` for datetimes, `to_char(field, '{{ var("datetime_without_seconds_format") }}')` for datetimes without seconds, `to_char(field, '{{ var("time_format") }}')` for times, and `to_char(field, '{{ var("yearmonth_format") }}')` for year-month values

## Testing Standards
- **Required**: Implement integrity tests using dbt built-in tests for all custom models
- **Required**: Unit tests for business logic using dbt built-in tests or dbt-utils
- Test critical relationships and constraints
- **Always run `dbt test` before finalising changes**
- Document test failures and resolution steps

## File Management Guidelines
- Follow established naming conventions: `{table_name}.sql` and `{table_name}.yml`
- Place files in appropriate directories based on model layer
- **Never delete files without understanding downstream dependencies**
- **Never manually edit `list_tamanu_reports.md`** - this file is auto-generated from report configuration files
- Use `dbt deps` to manage package dependencies

## Report Configuration Validation
- **Required**: Validate all report configuration files using the package validation script: `python dbt_packages/tamanu_source_dbt/scripts/validate_report_configs.py`
- Report configurations must conform to the JSON schema defined in package
- **Always run validation before committing changes** to report configurations
- Configuration files are located in `models/reports/config/` and must be valid JSON
- **Fix all validation errors** before proceeding with deployment

## Project-Specific Configuration
- **Required**: Update `dbt_project.yml` with project-specific name, profile, and version
- **Required**: Configure `config/profiles.yml` with appropriate database connections
- **Required**: Set up environment variables in `.env` file for database credentials
- **Version alignment**: Mirror Tamanu's release version numbers in project version

## Development Workflow
1. Activate virtual environment before development
2. Understand the data flow and existing model dependencies from package
3. Create or modify project-specific models following layer-appropriate patterns
4. Add comprehensive documentation in .yml files for custom models
5. Implement appropriate tests for custom models
6. Run `sqlfluff fix` for code formatting
7. Execute `dbt test` to validate changes
8. **Validate report configurations** using package validation script
9. Use `dbt run` to build and verify models
10. **Generate survey models** when survey definitions change
11. **Build reporting assets** using package script before deployment
