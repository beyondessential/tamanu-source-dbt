-- MAUI-7082: incremental on analytics targets, a view everywhere else. The cursor is
-- updated_at_sync_tick: central assigns it and it only rises, unlike the facility's updated_at.
-- Rows that go stale through a parent (e.g. a deleted encounter) are not tracked: the weekly
-- full refresh removes them.


-- incremental_from_logs: changes are found in logs.changes for `table`, e.g. 'patients'.
--   key_type casts logs.changes.record_id (text) when the key isn't text, e.g. 'uuid'.
-- incremental_from_table: changes are marked by `table`'s own updated_at_sync_tick, e.g.
--   'encounters'. source is its dbt source, 'tamanu' unless set, e.g. 'logs__tamanu'.
-- key is the column that identifies a row (dbt's unique_key).
-- indexes lists extra indexes for the analytics table, each a list of columns, e.g.
--   [['record_id'], ['source_record_type', 'source_record_id']]. The key and
--   updated_at_sync_tick are always indexed. dbt creates indexes when it builds the table,
--   so a new one appears at the next full refresh.
{%- macro incremental_from_logs(key, table, key_type=none, indexes=[]) -%}
    {{- incremental_settings(key, {'from_logs': table, 'key_type': key_type}, indexes) -}}
{%- endmacro %}


{%- macro incremental_from_table(key, table, source='tamanu', indexes=[]) -%}
    {{- incremental_settings(key, {'from_table': table, 'source': source}, indexes) -}}
{%- endmacro %}


-- Shared by the two macros above: incremental on analytics, a view everywhere else.
{%- macro incremental_settings(key, options, indexes=[]) -%}
    {%- set analytics = target.name.startswith('analytics') -%}
    {%- set table_indexes = [{'columns': [key]}, {'columns': ['updated_at_sync_tick']}] -%}
    {%- for columns in indexes -%}
        {%- do table_indexes.append({'columns': columns}) -%}
    {%- endfor -%}
    {{- config(
        materialized=('incremental' if analytics else 'view'),
        incremental_strategy='delete+upsert',
        unique_key=key,
        on_schema_change='sync_all_columns',
        indexes=(table_indexes if analytics else []),
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
-- Looked up when the model is rendered and written into the SQL as a number. Left as a subquery,
-- the planner cannot tell how few rows pass the tick filter, and it reads the whole history of
-- the table to find a handful of changed records. The subquery stays as the fallback for when
-- nothing can be queried: at parse time, or before the model's table exists.
{% macro last_sync_tick() -%}
    {%- set subquery = '(select coalesce(max(updated_at_sync_tick), -1) from ' ~ this ~ ')' -%}
    {%- set loaded = adapter.get_relation(this.database, this.schema, this.identifier) if execute else none -%}
    {%- if loaded is not none -%}
        {{- run_query('select ' ~ subquery).columns[0].values()[0] -}}
    {%- else -%}
        {{- subquery -}}
    {%- endif -%}
{%- endmacro %}
