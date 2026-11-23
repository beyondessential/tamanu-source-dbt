-- MAUI-7082: incremental on analytics targets, a view everywhere else. The cursor is
-- updated_at_sync_tick: central assigns it and it only rises, unlike the facility's updated_at.
-- Rows that go stale through a parent (e.g. a deleted encounter) are not tracked: the weekly
-- full refresh removes them.


-- incremental_from_logs: changes are found in logs.changes for `table`, e.g. 'patients'.
--   key_type casts logs.changes.record_id (text) when the key isn't text, e.g. 'uuid'.
-- incremental_from_table: changes are marked by `table`'s own updated_at_sync_tick, e.g.
--   'encounters'. source is its dbt source, 'tamanu' unless set, e.g. 'logs__tamanu'.
-- key is the column that identifies a row (dbt's unique_key).
{%- macro incremental_from_logs(key, table, key_type=none) -%}
    {{- incremental_settings(key, {'from_logs': table, 'key_type': key_type}) -}}
{%- endmacro %}


{%- macro incremental_from_table(key, table, source='tamanu') -%}
    {{- incremental_settings(key, {'from_table': table, 'source': source}) -}}
{%- endmacro %}


-- Shared by the two macros above: incremental on analytics, a view everywhere else.
{%- macro incremental_settings(key, options) -%}
    {%- set analytics = target.name.startswith('analytics') -%}
    {{- config(
        materialized=('incremental' if analytics else 'view'),
        incremental_strategy='delete+upsert',
        unique_key=key,
        on_schema_change='sync_all_columns',
        indexes=([{'columns': [key]}, {'columns': ['updated_at_sync_tick']}] if analytics else []),
        incremental=options
    ) -}}
{%- endmacro %}


-- Like delete+insert, but also deletes keys that went stale without being in the batch
-- (soft-deleted records).
{% macro get_incremental_delete_upsert_sql(arg_dict) -%}
    {%- set target_relation = arg_dict['target_relation'] -%}
    {%- set key = arg_dict['unique_key'] -%}
    {%- set options = config.get('incremental') or {} -%}
    {%- set source_table = options.get('from_logs') or options.get('from_table') -%}
    {%- set columns = get_quoted_csv(arg_dict['dest_columns'] | map(attribute='name')) -%}

    delete from {{ target_relation }}
    where {{ key }} in (
        select {{ key }} from {{ arg_dict['temp_relation'] }}
        {%- if source_table %}
        union
        {{ changed_since_last_run(
            source_table,
            source_type=('logs' if options.get('from_logs') else 'table'),
            key=key,
            key_type=options.get('key_type'),
            source_name=options.get('source') or 'tamanu'
        ) }}
        {%- endif %}
    );

    insert into {{ target_relation }} ({{ columns }})
    select {{ columns }}
    from {{ arg_dict['temp_relation'] }}
{%- endmacro %}


-- Records of table_name changed since the last run, soft deletes included: from logs.changes,
-- or from the table's own tick. key is the column, and source_name the dbt source, in 'table' mode.
{% macro changed_since_last_run(table_name, source_type='logs', key='id', key_type=none, source_name='tamanu') -%}
    {%- if source_type == 'table' %}
    select t.{{ key }}
    from {{ source(source_name, table_name) }} t
    where t.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- else %}
    select c.record_id{% if key_type %}::{{ key_type }}{% endif %}
    from {{ source('logs__tamanu', 'changes') }} c
    where c.table_name = '{{ table_name }}'
        and c.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}


-- The highest tick already loaded, -1 when empty. Compare with >= not >: rows from one sync
-- session share a tick, and rereading it is harmless.
{% macro last_sync_tick() -%}
    (select coalesce(max(updated_at_sync_tick), -1) from {{ this }})
{%- endmacro %}
