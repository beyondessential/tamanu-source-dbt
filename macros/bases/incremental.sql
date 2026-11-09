-- MAUI-7082: incremental on analytics targets, a view everywhere else. The cursor is
-- updated_at_sync_tick: central assigns it and it only rises, unlike the facility's updated_at.
-- Rows that go stale through a parent (e.g. a deleted encounter) are not tracked: the weekly
-- full refresh removes them.


-- key:          column that identifies a row (dbt's unique_key)
-- source:       Tamanu table whose changed records are this model's keys
-- key_type:     cast for record_id (text) when the key isn't text, e.g. 'uuid'
{%- macro incremental_config(key, source=none, key_type=none) -%}
    {%- set analytics = target.name.startswith('analytics') -%}
    {{- config(
        materialized=('incremental' if analytics else 'view'),
        incremental_strategy='delete+upsert',
        unique_key=key,
        on_schema_change='fail',
        indexes=([{'columns': [key]}, {'columns': ['updated_at_sync_tick']}] if analytics else []),
        incremental={'source': source, 'key_type': key_type}
    ) -}}
{%- endmacro %}


-- Like delete+insert, but also deletes keys that went stale without being in the batch
-- (soft-deleted records).
{% macro get_incremental_delete_upsert_sql(arg_dict) -%}
    {%- set target_relation = arg_dict['target_relation'] -%}
    {%- set key = arg_dict['unique_key'] -%}
    {%- set options = config.get('incremental') or {} -%}
    {%- set source_table = options.get('source') -%}
    {%- set columns = get_quoted_csv(arg_dict['dest_columns'] | map(attribute='name')) -%}

    delete from {{ target_relation }}
    where {{ key }} in (
        select {{ key }} from {{ arg_dict['temp_relation'] }}
        {%- if source_table %}
        union
        {{ changed_since_last_run(source_table, key_type=options.get('key_type')) }}
        {%- endif %}
    );

    insert into {{ target_relation }} ({{ columns }})
    select {{ columns }}
    from {{ arg_dict['temp_relation'] }}
{%- endmacro %}


-- Records with a change-log row since the last run, soft deletes included. >= not >: rows
-- from one sync session share a tick, and rereading it is harmless.
{% macro changed_since_last_run(table_name, key_type=none) -%}
    select c.record_id{% if key_type %}::{{ key_type }}{% endif %}
    from {{ source('logs__tamanu', 'changes') }} c
    where c.table_name = '{{ table_name }}'
        and c.updated_at_sync_tick >= (select coalesce(max(updated_at_sync_tick), -1) from {{ this }})
{%- endmacro %}
