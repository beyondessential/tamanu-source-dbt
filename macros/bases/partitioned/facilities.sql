-- Body of the facility bases, which split facilities by partition: `facilities` holds standard
-- facilities (network=none) and each listed sensitive network has a base holding its own.
-- See specs/dbt-model/sensitive-facility-partition.md for the BL clauses.
{%- macro facilities_base(network=none) -%}
select
    id,
    code,
    name,
    division,
    type,
    email,
    contact_number,
    city_town,
    street_address,
    catchment_id,
    visibility_status,
    sensitive_network_id,
    updated_at_sync_tick
from {{ source('tamanu', 'facilities') }}
where deleted_at is null
    -- BL-001: a facility is in its sensitive network's partition, or standard when it has none
    and {{ facility_in_partition(network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
