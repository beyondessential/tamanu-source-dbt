{#- network is passed by a metadata base whose records belong to an encounter. BL-008 (see
    specs/dbt-model/sensitive-facility-partition.md): a record's metadata follows the partition
    of the record, as it is now. Without it the base covers every record. -#}
{%- macro get_metadata_from_changes(table_name, network=none, partitioned=false) -%}
{%- if partitioned -%}
    {%- if table_name == 'encounters' -%}
        {%- set encounter_id = 'record_id' -%}
    {%- elif table_name == 'lab_request_logs' -%}
        {%- set encounter_id -%}
            (
                select mlr.encounter_id
                from {{ source('tamanu', 'lab_request_logs') }} mlrl
                join {{ source('tamanu', 'lab_requests') }} mlr on mlr.id = mlrl.lab_request_id
                where mlrl.id::text = record_id
            )
        {%- endset -%}
    {%- else -%}
        {%- set encounter_id -%}
            (
                select mr.encounter_id
                from {{ source('tamanu', table_name) }} mr
                where mr.id::text = record_id
            )
        {%- endset -%}
    {%- endif -%}
{%- endif -%}
with change_logs as (
    select
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime,
        record_deleted_at,
        -- the latest change carries the record's current deletion state: a record can be
        -- deleted and later restored, so an earlier change's deleted_at may no longer apply.
        -- Changes made in one transaction (a merge, say) share a logged_at, so the latest is a
        -- set of rows rather than one, and the deletion can sit on any of them.
        max(logged_at) over (partition by record_id) as last_logged_at
    from {{ source('logs__tamanu', 'changes') }}
    where table_name = '{{ table_name }}'
    {%- if partitioned %}
        and {{ encounter_id_in_partition(encounter_id, network) }}
    {%- endif %}
)

select
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime,
    max(record_deleted_at) filter (where logged_at = last_logged_at) as deleted_datetime
from change_logs
group by record_id
{%- endmacro %}
