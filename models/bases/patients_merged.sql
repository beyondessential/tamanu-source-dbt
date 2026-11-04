{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='patients',
    source_type='table'
) }}
select
    id,
    display_id,
    first_name,
    middle_name,
    last_name,
    cultural_name,
    email,
    initcap(sex::text) as sex,
    date_of_birth::date as date_of_birth,
    date_of_death::timestamp as date_of_death,
    village_id,
    (created_at at time zone '{{ var("timezone") }}')::date as registration_date,
    updated_at_sync_tick
from {{ source('tamanu', 'patients') }}
where id != '{{ var("test_patient") }}'
    and visibility_status = 'merged'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
