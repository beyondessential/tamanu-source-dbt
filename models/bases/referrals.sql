{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='referrals',
    source_type='table'
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
