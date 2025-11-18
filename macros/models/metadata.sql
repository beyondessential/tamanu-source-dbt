{%- macro get_metadata_from_changes(table_name) -%}
select 
    record_id as id,
    min(logged_at) as created_datetime,
    max(logged_at) as updated_datetime
from {{ source('logs__tamanu', 'changes') }}
where table_name = '{{ table_name }}'
group by record_id
{%- endmacro %}

