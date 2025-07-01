{%- macro base_history_from_log(table_name) -%}
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_id,
        record_data
    from {{ source("logs__tamanu", "changes") }}
    where table_name = '{{ table_name }}'
        and record_id != any(
            select id::text
            from {{ table_name }} t 
            where t.deleted_at notnull
        )
{%- endmacro %}
