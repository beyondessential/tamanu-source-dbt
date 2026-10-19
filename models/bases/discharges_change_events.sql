-- BL-014: thin projection of the discharge change log -- source filters, no window functions,
-- so consumers can filter it and have the predicate reach the (table_name, record_id) index.
-- The windowed reconstruction lives in discharges_change_log_events(), which cannot be
-- filtered that way (see specs/reports/audit-discharge-line-list.md).
select
    c.id as changelog_id,
    c.record_id as discharge_id,
    d.encounter_id,
    c.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    c.record_updated_at at time zone '{{ var("timezone") }}' as record_updated_at,
    -- sort-only: local logged_at and record_updated_at repeat an hour at a DST fall-back, so
    -- order history by these
    c.logged_at at time zone 'UTC' as logged_at_utc,
    c.record_updated_at at time zone 'UTC' as record_updated_at_utc,
    c.updated_by_user_id,
    c.record_data
from {{ source('logs__tamanu', 'changes') }} c
join {{ source('tamanu', 'discharges') }} d
    on d.id = c.record_id
    and d.deleted_at is null
join {{ source('tamanu', 'encounters') }} e
    on e.id = d.encounter_id
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
where
    c.table_name = 'discharges'
    and c.record_deleted_at is null
