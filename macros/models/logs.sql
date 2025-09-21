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
            from {{ resolve_input_model(table_name, source_type=var('base_model_source_type', 'source')) }} t 
            where t.deleted_at notnull
        )
{%- endmacro %}
