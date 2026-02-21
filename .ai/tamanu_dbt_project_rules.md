# AI Rules for tamanu-dbt-* Projects

## Project Overview
Country-specific dbt projects using tamanu-source-dbt as a package dependency to transform Tamanu healthcare data for specific deployments.

## Core Principles
- Follow data flow: sources/logs → bases/surveys → datasets → reports
- Use tamanu-source-dbt package for standard models, extend with project-specific customisations
- Maintain data integrity at each layer

## Model Layers

**sources/logs** - Package-managed, never modify
**bases** - Package-managed, never modify
**surveys** - Generated via `python dbt_packages/tamanu_source_dbt/scripts/generate_survey_models.py`
**datasets** - Project-specific denormalised views (no ORDER BY)
**reports** - Project-specific with translations, ORDER BY allowed

## Essential Rules

### Documentation
- **Mandatory `.yml`** for all custom models except reports
- **Mandatory `.json` config** for each report in `models/reports/config/`
- Document all columns

### Code Quality
- Run `sqlfluff fix` before committing
- Run `dbt test` before committing
- Test SQL syntax before committing
- **No ORDER BY** in datasets (reports only)

### Date/Time Formatting
Use centralised variables from `dbt_project.yml`:
- `{{ var("date_format") }}`, `{{ var("datetime_format") }}`, `{{ var("time_format") }}`, etc.

### Validation (Before Committing)
1. `python dbt_packages/tamanu_source_dbt/scripts/validate_report_configs.py`
2. `python dbt_packages/tamanu_source_dbt/scripts/check_translations.py`
3. If surveys changed: regenerate with package script

## Package Management
- Use specific version tags in `packages.yml` for production
- Run `dbt deps` after version updates
- Use package scripts for surveys and building assets

## Translation Rules
- Check for existing translations before creating new ones
