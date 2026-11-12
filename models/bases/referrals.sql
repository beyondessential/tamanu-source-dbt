{{ incremental_from_table(
    key='id',
    table='referrals'
) }}
select
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id,
    updated_at_sync_tick
from {{ source('tamanu', 'referrals') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
