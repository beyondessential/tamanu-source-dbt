-- See specs/dbt-model/ds__prescription_administrations.md for BL-001..BL-002.
{{ incremental_from_table(
    key='id',
    table='medication_administration_records'
) }}
select
    mar.id,
    mar.prescription_id,
    mar.status,
    mar.due_at::timestamp as due_datetime,
    mar.recorded_at::timestamp as recorded_datetime,
    mar.recorded_by_user_id,
    mar.reason_not_given_id,
    mar.changing_status_reason,
    mar.is_auto_generated,
    mar.is_error,
    mar.error_notes,
    mar.updated_at_sync_tick
from {{ source('tamanu', 'medication_administration_records') }} mar
join {{ source('tamanu', 'prescriptions') }} p on p.id = mar.prescription_id
-- BL-001: exclude deleted records and records whose prescription is deleted
where mar.deleted_at is null
    and p.deleted_at is null
    -- BL-002: exclude records on a prescription of the test patient
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
    and mar.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
