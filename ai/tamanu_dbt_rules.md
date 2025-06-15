# Cline Rules for tamanu-source-dbt

## Project Overview
tamanu-source-dbt is used to transform data to create datasets in a reporting schema that is optimised for performance as views. This is a dbt (data build tool) project that processes Tamanu healthcare system data.

## Core Principles
- Always follow the established data flow: sources → bases → datasets → reports
- Maintain data integrity and quality at each transformation layer
- Prioritize performance and readability in SQL code
- Ensure comprehensive documentation for all models

## Model Layer Requirements
When working with models, always respect the following hierarchy:

### `models/sources`
- Describes Tamanu's schema and performs data integrity checks
- Origin point for most documentation blocks
- **Never modify source definitions as this is defined in another repository.**

### `models/bases` 
- Strips out deleted data and metadata from tables
- Shared with the data warehouse as the `staging` model
- **Always filter out soft-deleted records and test patients using appropriate conditions**

### `models/datasets`
- Builds on top of `bases` models
- De-normalises data for easy reporting consumption
- **Focus on creating user-friendly, denormalized views**

### `models/reports`
- Based on `datasets` models with customised translations applied
- **Apply translations consistently using established patterns**

## Documentation Requirements
- **Mandatory**: Each model except those in `reports` must have a corresponding .yml file
- Include comprehensive name and description for both the model and all columns
- Maintain professional, clear, and respectful tone in all documentation
- Reference existing doc blocks when possible to maintain consistency
- **Always document new columns when adding them to existing models**

## Translation Management
- Keep translation string lists concise and avoid duplication
- **Always check for existing translations before creating new ones**
- Follow established naming conventions for translation keys

## Code Style Standards
- **Mandatory**: Use `.sqlfluff` for SQL code style enforcement
- Run `sqlfluff fix` before committing changes
- Follow consistent indentation and formatting patterns
- Use meaningful aliases and avoid ambiguous column references
- **Always test SQL syntax before committing**

## History model pattern
When creating `*_history` models in `models/bases/`:

### SQL file structure
- Query the `logs__tamanu.changes` source table
- Filter by `table_name = 'target_table_name'` and `version >= '2.33'`
- Extract fields from JSON `record_data` using `->>'field_name'` syntax
- Cast timestamp fields using `::timestamp`
- Include `c.id` and `c.record_updated_at::timestamp` as standard fields
- Follow naming convention: `{table_name}_history.sql`

### YAML file structure
- Set `latest_version: 1` and include `versions` section
- Enable contract enforcement with `contract: enforced: true`
- Tag with same tags as original model plus `history` tag
- Document all columns with references to existing doc blocks from base model
- Use `data_type: text` for extracted JSON fields, `timestamp` for date fields, `uuid` for id
- Add constraints: `not_null` and `unique` for id, `not_null` for record_updated_at
- Follow naming convention: `{table_name}_history.yml`

### Example pattern
```sql
-- Version >= 2.33
select
    c.id,
    c.record_updated_at::timestamp,
    (c.record_data->>'date_field')::timestamp as datetime,
    c.record_data->>'text_field' as text_field
from {{ source("logs__tamanu", "changes") }} c
where c.table_name = 'target_table_name'
    and c.version >= '2.33'
```

## Testing Standards
- **Required**: Implement integrity tests using dbt built-in tests for all models
- **Required**: Unit tests for business logic using dbt built-in tests or dbt-utils
- Test critical relationships and constraints
- **Always run `dbt test` before finalizing changes**
- Document test failures and resolution steps

## File Management Guidelines
- Follow established naming conventions: `{table_name}.sql` and `{table_name}.yml`
- Place files in appropriate directories based on model layer
- **Never delete files without understanding downstream dependencies**
- Use `dbt deps` to manage package dependencies

## Development Workflow
1. Understand the data flow and existing model dependencies
2. Create or modify models following layer-appropriate patterns
3. Add comprehensive documentation in .yml files
4. Implement appropriate tests
5. Run `sqlfluff fix` for code formatting
6. Execute `dbt test` to validate changes
7. Use `dbt run` to build and verify models
