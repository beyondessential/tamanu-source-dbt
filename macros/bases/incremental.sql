-- MAUI-7082: incremental on analytics targets, a view everywhere else. The cursor is
-- updated_at_sync_tick: central assigns it and it only rises, unlike the facility's updated_at.


-- source_table:        Tamanu table whose changed records are this model's keys
-- key_type:            cast for record_id (text) when the key isn't text, e.g. 'uuid'
-- encounter_id_column: column holding the encounter id; rows of removed encounters are deleted
{%- macro incremental_config_for_analytics(unique_key, source_table=none, key_type=none, encounter_id_column=none) -%}
    {%- set analytics = target.name.startswith('analytics') -%}
    {{- config(
        materialized=('incremental' if analytics else 'view'),
        incremental_strategy='delete+upsert',
        unique_key=unique_key,
        on_schema_change='fail',
        indexes=([{'columns': [unique_key]}, {'columns': ['updated_at_sync_tick']}] if analytics else []),
        delete_upsert_source_table=source_table,
        delete_upsert_key_type=key_type,
        delete_upsert_encounter_id_column=encounter_id_column
    ) -}}
{%- endmacro %}


-- Like delete+insert, but also deletes keys that went stale without being in the batch
-- (soft-deleted records, removed encounters).
{% macro get_incremental_delete_upsert_sql(arg_dict) -%}
    {%- set target_relation = arg_dict['target_relation'] -%}
    {%- set key = arg_dict['unique_key'] -%}
    {%- set source_table = config.get('delete_upsert_source_table') -%}
    {%- set encounter_id_column = config.get('delete_upsert_encounter_id_column') -%}
    {%- set columns = get_quoted_csv(arg_dict['dest_columns'] | map(attribute='name')) -%}

    delete from {{ target_relation }}
    where {{ key }} in (
        select {{ key }} from {{ arg_dict['temp_relation'] }}
        {%- if source_table %}
        union
        {{ changed_since_last_run(source_table, key_type=config.get('delete_upsert_key_type')) }}
        {%- endif %}
        {%- if encounter_id_column %}
        union
        -- encounters deleted or moved to the test patient (a restore needs a full refresh)
        select t.{{ key }}
        from {{ target_relation }} t
        where t.{{ encounter_id_column }} in (
            select e.id
            from {{ source('tamanu', 'encounters') }} e
            where e.updated_at_sync_tick >= (select coalesce(max(updated_at_sync_tick), -1) from {{ this }})
                and (e.deleted_at is not null or e.patient_id = '{{ var("test_patient") }}')
        )
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
