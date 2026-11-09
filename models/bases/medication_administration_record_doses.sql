-- See specs/dbt-model/ds__prescription_administrations.md for BL-010.
{{ incremental_config(
    key='id',
    source='medication_administration_record_doses',
    source_type='table'
) }}
select
    d.id,
    d.mar_id,
    d.dose_index,
    d.dose_amount,
    d.given_time::timestamp as given_datetime,
    d.given_by_user_id,
    d.recorded_by_user_id,
    d.reason_for_change,
    d.updated_at_sync_tick
from {{ source('tamanu', 'medication_administration_record_doses') }} d
-- every dose hangs off a MAR record and, through it, a prescription
join {{ source('tamanu', 'medication_administration_records') }} mar on mar.id = d.mar_id
join {{ source('tamanu', 'prescriptions') }} p on p.id = mar.prescription_id
-- BL-010: exclude deleted and removed doses, and doses whose MAR record or
-- prescription is deleted
where d.deleted_at is null
    and d.is_removed is not true
    and mar.deleted_at is null
    and p.deleted_at is null
    and not exists (
        select 1
        from {{ source('tamanu', 'encounter_prescriptions') }} ep
        join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
        where ep.prescription_id = p.id
            and ep.deleted_at is null
            and e.deleted_at is null
            and e.patient_id = '{{ var("test_patient") }}'
    )
    {%- if is_incremental() %}
    and d.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
