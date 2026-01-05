{%- macro get_metadata_from_changes(table_name) -%}
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from {{ source('logs__tamanu', 'changes') }}
    where table_name = '{{ table_name }}'
    {% if dbt_utils.get_relations_by_pattern(
        schema_pattern='logs',
        table_pattern='changes_backup') %}
    union all
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from {{ source('logs__tamanu', 'changes_backup') }}
    where table_name = '{{ table_name }}'
    {% endif %}
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
{%- endmacro %}
