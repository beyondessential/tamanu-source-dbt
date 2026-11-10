{%- macro get_metadata_from_changes(table_name) -%}
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
)

select
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime,
    max(record_deleted_at) filter (where logged_at = last_logged_at) as deleted_datetime
from change_logs
group by record_id
{%- endmacro %}
