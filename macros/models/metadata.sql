{%- macro get_metadata_from_changes(table_name) -%}
with change_logs as (
    select 
        record_id,
        logged_at,
        record_created_at, 
        record_updated_at
    from {{ source('logs__tamanu', 'changes') }}
    where table_name = '{{ table_name }}'
    {% if dbt_utils.get_relations_by_pattern(
        schema_pattern='logs__tamanu',
        table_pattern='changes_backup'
    ) | length > 0 %}
    union all
    select 
        record_id,
        logged_at,
        record_created_at, 
        record_updated_at
    from {{ source('logs__tamanu', 'changes_backup') }}
    where table_name = '{{ table_name }}'
    {% endif %}
)
select 
    record_id as id,
    min(coalesce(record_created_at, logged_at)) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
{%- endmacro %}
