# AI Assistant Rules for tamanu-source-dbt

## Project Overview
A dbt project transforming Tamanu healthcare data: sources/logs → bases/surveys → datasets → reports.

## Model Layers

**sources/logs** - Read-only, managed externally
**bases/surveys** - Filter deleted records and test patients
**datasets** - Denormalised, user-friendly views
**reports** - Apply translations, date formatting, and report configs

## Essential Rules

### Documentation
- **Mandatory `.yml`** for bases/surveys/datasets (not reports)
- **Mandatory `.json` config** for each report in `models/reports/config/`
- Document all columns

### Code Quality
- Run `sqlfluff fix` before committing
- Run `dbt test --profiles-dir config` before committing
- Test SQL syntax before committing
- **No ORDER BY** in bases/surveys/datasets (reports only)

### Date/Time Formatting
Use centralised variables from `dbt_project.yml`:
- `{{ var("date_format") }}`, `{{ var("datetime_format") }}`, `{{ var("time_format") }}`, etc.

### Validation Scripts (Before Committing)
1. `python scripts/validate_report_configs.py`
2. `python scripts/check_translations.py`
3. If CSV changed: `python scripts/generate_translation_macro.py`

## Translation System

**Storage**: `report_translations_standard.csv` → generates `macros/default_translations.sql`
**Usage**: `translate_label('field_name')` (auto-prefixes with `report.reporting.`)

## File Naming

- Models: `{table_name}.sql`, `{table_name}.yml`
- Reports: `{description}-line-list.sql`, config in `models/reports/config/`
- Never edit `list_tamanu_reports.md` (auto-generated)
