{%- macro get_metadata_from_changes(table_name) -%}
with combined_changes as (
    select 
        record_id,
        logged_at
    from {{ source('logs__tamanu', 'changes') }}
    where table_name = '{{ table_name }}'
    {% if dbt_utils.get_relations_by_pattern('logs', 'changes_backup') %}
        union all
        select 
            record_id,
            logged_at
        from {{ source('logs__tamanu', 'changes_backup') }}
        where table_name = '{{ table_name }}'
    {% endif %}
)
select 
    cc.record_id as id,
    min(cc.logged_at) as created_datetime,
    max(cc.logged_at) as updated_datetime
from combined_changes cc
group by cc.record_id
{%- endmacro %}
