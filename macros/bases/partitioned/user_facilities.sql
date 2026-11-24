{#- Body of `user_facilities` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro user_facilities_base(network=none) -%}
select
    id,
    user_id,
    facility_id,
    updated_at_sync_tick
from {{ source('tamanu', 'user_facilities') }}
where deleted_at is null
    -- BL-001: the facility decides the row's partition
    and {{ facility_id_in_partition('facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
