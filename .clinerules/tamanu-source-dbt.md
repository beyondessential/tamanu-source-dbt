# tamanu-source-dbt
We use tamanu-source-dbt to transform our data to create datasets in a reporting schema that is optimised for performance as views.

## Model requirements
- `models/sources` describes Tamanu's schema and performs data integrity checks and where most doc blocks for documentation originates from
- `models/bases` strips out deleted data and metadata from tables and is shared with the data warehouse as the `staging` model
- `models/datasets` builds on top of `bases` models that de-normalises data so that it is easy for reporting
- `models/reports` is based on `datasets` models with customised translations applied

## Documentation requirements
- Each model except those in `reports` has a .yml file which includes name and description of the model and columns
- Ensure the documentation maintains a professional tone, is easy to understand, and presents information respectfully without condescension.

## Generated translation strings
- List to be concise and avoid duplication

## Code style
- Use `.sqlfluff` for SQL code style

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

## Testing standards
- Integrity test using dbt built-in tests
- Unit test required for business logic using dbt built-in tests or dbt-utils
