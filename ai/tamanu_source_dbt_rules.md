# AI Assistant Rules for tamanu-source-dbt

## Project Overview
A dbt project that transforms Tamanu healthcare system data into optimised reporting datasets following the data flow: sources/logs → bases/surveys → datasets → reports.

## Model Layer Hierarchy

### `models/sources` & `models/logs`
- **Read-only**: Never modify source/log definitions (managed externally)
- Sources use `public` schema, logs use `logs__tamanu` source and `logs` schema
- Origin point for documentation blocks

### `models/bases` & `models/surveys`
- Filter out soft-deleted records and test patients
- Bases shared as `staging` models in data warehouse
- Surveys handle form-based data collection

### `models/datasets`
- Build on bases models
- Create denormalised, user-friendly views

### `models/reports`
- Apply translations using established patterns
- Apply date formatting
- **Required**: Each report needs corresponding `.json` config file in `models/reports/config/`

## Essential Requirements

### Documentation
- **Mandatory**: `.yml` file for each model in `models/bases`, `models/surveys`, and `models/datasets`
- **Reports do not require `.yml` files**
- Include comprehensive name/description for model and all columns
- Document new columns when adding to existing models
- Use Australian English spelling

### Code Quality
- **Mandatory**: Run `sqlfluff fix` before committing
- Use meaningful aliases, avoid ambiguous references
- Test SQL syntax before committing
- **Sort order should only be applied in `models/reports`** - Do not use ORDER BY clauses in `models/bases`, `models/surveys`, or `models/datasets` as these are intermediate transformations
- **Use centralised date/time formatting variables** from `dbt_project.yml` in all reports: `to_char(field, '{{ var("date_format") }}')` for dates, `to_char(field, '{{ var("datetime_format") }}')` for datetimes, `to_char(field, '{{ var("datetime_without_seconds_format") }}')` for datetimes without seconds, `to_char(field, '{{ var("time_format") }}')` for times, and `to_char(field, '{{ var("yearmonth_format") }}')` for year-month values.


### Testing & Validation
- **Required**: Implement dbt built-in tests for all models
- Run `dbt test` before finalising changes
- **Required**: Validate report configs with `python scripts/validate_report_configs.py`
- **Required**: Validate translation consistency with `python scripts/check_translations.py`

## File Management
- Follow naming: `{table_name}.sql` and `{table_name}.yml`
- Place in appropriate layer directories
- Never delete without checking dependencies
- **Never manually edit** `list_tamanu_reports.md` (auto-generated)

## Development Workflow
1. Understand data flow and dependencies
2. Create/modify models following layer patterns
3. Add comprehensive documentation (`.yml` files for bases/surveys/datasets, `.json` config for reports)
4. Implement tests
5. **If adding new translation strings**: Add to `report_translations_standard.csv`, run `python scripts/generate_translated_strings_sql.py`, then `dbt run --select translated_strings_default`
6. Run `sqlfluff fix` (requires database environment variables)
7. Execute `dbt test --profiles-dir config`
8. Validate report configurations with `python scripts/validate_report_configs.py`
9. **Validate translation consistency**: Run `python scripts/check_translations.py` to ensure all translate_label calls have corresponding CSV entries
10. Use `dbt run` to verify

## Translation System
- **CSV File**: Translation strings stored in `report_translations_standard.csv`
- **Dynamic Generation**: Use `python scripts/generate_translated_strings_sql.py` to generate `translated_strings_default.sql` from CSV
- **Fallback Hierarchy**: Translation system checks database translations first, then falls back to default model, then string ID
- **Adding Translations**: Add new entries to CSV file, run generation script, then `dbt run --select translated_strings_default`
- **Usage**: Use `translate_label('fieldName')` in reports - automatically references `report.reporting.fieldName` format
- **Testing**: Run `dbt test --select translated_strings_default` to validate translation data quality
- **Validation**: Use `python scripts/check_translations.py` to ensure all `translate_label` calls have corresponding entries in CSV file - identifies missing translations and provides file-by-file analysis

## Report Configuration
- **Schema documentation**: See `documentations/tamanu-report-configuration-schema.md` for detailed report configuration requirements
- **Config location**: Report JSON configs must be placed in `models/reports/config/`
- **Validation**: Always validate with `python scripts/validate_report_configs.py` after creating or modifying report configs
