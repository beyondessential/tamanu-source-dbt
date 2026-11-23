-- Body of the two facility bases, which split facilities by sensitivity: `facilities` holds
-- standard facilities (is_sensitive=false) and `sensitive_facilities` the ones in a sensitive
-- network (is_sensitive=true). Every live facility is in exactly one of them.
{%- macro facilities_base(is_sensitive=false) -%}
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
    and sensitive_network_id is {{ 'not null' if is_sensitive else 'null' }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
