# Claude AI Assistant Guidelines

This document provides conventions and standards for Claude when working on the Tamanu Source DBT repository.

## Language & Style

- **Use Australian English spelling** in all documentation, comments, and outputs (e.g., "summarise", "organisation", "colour")
- **Keep comments, descriptions, and outputs concise** - be direct and avoid unnecessary verbosity
- **Do not use emoji** in any code, documentation, or outputs

## Repository Context

This is a DBT (Data Build Tool) repository for transforming and modelling data from the Tamanu healthcare system. The codebase is predominantly SQL with Python utilities.

### Project Structure

- `models/sources/` - Read-only source definitions from Tamanu database
- `models/bases/` - Staging models that filter soft-deleted records and test patients
- `models/surveys/` - Form-based data collection models
- `models/datasets/` - Denormalised, user-friendly views (prefix: `ds__`)
- `models/intermediate/` - Ephemeral models for intermediate transformations
- `models/reports/` - Final reporting views with translations
- `models/reconstructs/` - Incremental models for reconstruction
- `macros/` - Reusable SQL macros
- `tests/` - Data validation tests
- `scripts/` - Python utilities

## SQL Standards

### Naming Conventions

**Files:**
- Base models: `{table_name}.sql` (e.g., `patients.sql`)
- Dataset models: `ds__{description}.sql` (e.g., `ds__admissions.sql`)
- Intermediate models: `int__{description}.sql`
- Report models: `{description}-line-list.sql` (hyphen-separated)

**Columns:**
- Use `snake_case` for all column names
- Suffix IDs with `_id` (e.g., `patient_id`, `encounter_id`)
- Use descriptive suffixes: `_datetime`, `_date`, `_name`, `_ids`
- For human-readable versions: `{field}_name` (e.g., `facility_name`)

### Formatting Standards (SQLFluff)

- **Dialect:** PostgreSQL
- **Indentation:** 4 spaces
- **Keywords:** Lowercase (select, from, where, join)
- **Table aliasing:** Implicit (no `as` keyword)
- **Column aliasing:** Explicit (must use `as` keyword)
- **Max line length:** Unlimited

**CTE Structure:**
```sql
with cte_name_1 as (
    select
        column1 as column1_alias,
        column2 as column2_alias
    from {{ ref('model_name') }}
    where deleted_at is null
),

cte_name_2 as (
    select
        col1,
        col2
    from cte_name_1
)

select
    col1,
    col2
from cte_name_2
```

### Common Patterns

**Standard Filters (Base Models Only):**

These filters are only applied at the base model level. Once filtered at the base, downstream models (datasets, reports) inherit the clean data and do not need to reapply these filters.

```sql
where deleted_at is null
    and id != '{{ var("test_patient") }}'
    and visibility_status != 'merged'
```

**Datetime Formatting (use variables):**
```sql
to_char(field, '{{ var("date_format") }}')           -- YYYY-MM-DD
to_char(field, '{{ var("datetime_format") }}')       -- YYYY-MM-DD HH24:MI:SS
to_char(field, '{{ var("time_format") }}')           -- HH24:MI
```

**Array Aggregation:**
```sql
array_agg(column_id order by datetime) filter (where condition) as column_ids,
string_agg(column_name, ', ' order by datetime) filter (where condition) as columns
```

**Window Functions:**
```sql
row_number() over (
    partition by encounter_id
    order by datetime
) as sequence_number
```

## Documentation Requirements

### YAML Files (Required for bases/surveys/datasets)

```yaml
version: 2

models:
  - name: model_name
    description: '{{ doc("table__model_name") }}'
    config:
      tags:
        - tag_name
    columns:
      - name: column_name
        data_type: data_type
        description: "{{ doc('model_name__column_name') }}"
        tags:
          - sensitivity_tag
```

**Column Tags:**
- `direct_identifier` - PII (personally identifiable information)
- `quasi_identifier` - Quasi-identifiers
- `clinical` - Clinical data

**Reports do NOT require YAML documentation files.**

## Python Standards

### File Structure
```python
import sys
import os
from pathlib import Path

def main():
    """Concise function description."""
    try:
        # Implementation
        pass
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
```

### Common Patterns
- Use `Path` for cross-platform file operations
- Include try-except blocks with meaningful error messages
- Keep utility functions in `scripts/utils/`

## Development Workflow

### Before Committing
1. Run `sqlfluff fix models` to format SQL
2. Run `dbt test` to validate models
3. For reports: validate configs with `python scripts/validate_report_configs.py`
4. Check translations: `python scripts/check_translations.py`

### Key Rules
- **No query-level ORDER BY** in bases/surveys/datasets - only in reports (see ORDER BY guidance below)
- Use **explicit aliases** for columns (required by SQLFluff)
- **Comprehensive documentation** required for bases/surveys/datasets
- Test models before committing
- Check dependencies before deleting models

### ORDER BY Usage Guidelines

**When ORDER BY is allowed (do NOT flag as an issue):**
- Within window functions: `row_number() over (partition by x order by y)`
- Within array aggregations: `array_agg(column order by datetime)`
- Within string aggregations: `string_agg(column, ', ' order by datetime)`
- In report models: Final query-level ORDER BY for user-facing output

**When ORDER BY should be flagged:**
- Query-level ORDER BY in bases/surveys/datasets that unnecessarily sorts the final output
- Only flag if the ORDER BY is solely for sorting the result set, not for functional purposes

## Code Review Focus

When reviewing pull requests, prioritise:

1. **Correctness** - Does the logic accurately transform the data?
2. **Security** - Are there any SQL injection risks or data exposure issues?
3. **Performance** - Are there inefficient joins, missing filters, or unnecessary computations?
4. **Conventions** - Does the code follow the naming and formatting standards?
5. **Documentation** - Are YAML files complete with appropriate tags?
6. **Testing** - Are there adequate tests for the changes?

### Common Issues to Check

- Missing `deleted_at is null` or test patient filters in **base models** (not required in downstream models)
- Incorrect datetime formatting (should use variables)
- Missing YAML documentation for bases/surveys/datasets
- Missing sensitivity tags for PII columns
- Query-level ORDER BY in non-report models (ORDER BY within functions is acceptable)
- Implicit column aliases (should be explicit)
- American spelling in documentation

### Template Files and Placeholders

Report configuration templates may contain placeholder text such as `"query": "replace this"`. These are **intentional** and used as templates. The query will be compiled into a complete file during the build process. Do not flag these as bugs or issues in code reviews.

## Reference Files

- `/ai/tamanu_source_dbt_rules.md` - Comprehensive AI assistant rules
- `/dbt_project.yml` - Project configuration and variables
- `/.sqlfluff` - SQL linting configuration
- `/README.md` - Project overview
