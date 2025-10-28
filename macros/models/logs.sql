{%- macro base_history_from_log(table_name) -%}
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from {{ source("logs__tamanu", "changes") }}
    where table_name = '{{ table_name }}'
        and record_id not in (
            select id::text
            from {{ resolve_input_model(table_name) }} t 
            where t.deleted_at notnull
        )
{%- endmacro %}

{%- macro base_history_from_log_backup(table_name) -%}
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from {{ source("logs__tamanu", "changes_backup") }}
    where table_name = '{{ table_name }}'
        and record_id not in (
            select id::text
            from {{ resolve_input_model(table_name) }} t 
            where t.deleted_at notnull
        )
{%- endmacro %}
