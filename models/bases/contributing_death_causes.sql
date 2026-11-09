{{ incremental_config(
    key='id',
    source='contributing_death_causes',
    source_type='table'
) }}
select
    cdc.id,
    cdc.time_after_onset,
    cdc.patient_death_data_id,
    cdc.condition_id,
    cdc.updated_at_sync_tick
from {{ source('tamanu', 'contributing_death_causes') }} cdc
join {{ source('tamanu', 'patient_death_data') }} pdd on pdd.id = cdc.patient_death_data_id
where cdc.deleted_at is null
    and pdd.deleted_at is null
    and pdd.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and cdc.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
