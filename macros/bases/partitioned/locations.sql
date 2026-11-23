{#- Body of `locations` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro locations_base(network=none) -%}
select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'locations') }}
where deleted_at is null
    -- BL-001: the location's facility decides its partition
    and {{ facility_id_in_partition('facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
