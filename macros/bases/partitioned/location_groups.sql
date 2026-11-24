{#- Body of `location_groups` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro location_groups_base(network=none) -%}
select
    id,
    code,
    name,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'location_groups') }}
where deleted_at is null
    -- BL-001: the location group's facility decides its partition
    and {{ facility_id_in_partition('facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
