{%- macro base_history_from_log(table_name) -%}
    select 
        c.id as changelog_id,
        c.logged_at,
        c.updated_by_user_id,
        c.record_id,
        c.record_data
    from {{ source("logs__tamanu", "changes") }} c
    where c.table_name = '{{ table_name }}'
        and c.record_id != any(
            select id::text
            from {{ table_name }} t 
            where t.deleted_at notnull
        )
{%- endmacro %}
