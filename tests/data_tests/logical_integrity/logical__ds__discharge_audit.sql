-- Cross-model invariants for ds__discharge_audit.
-- Each branch returns rows only when the invariant is broken.

-- AC-001: every discharged, non-sensitive encounter with a discharge record is represented,
-- and nothing beyond that set is. The patients join belongs on this side too, or a discharge
-- belonging to a deleted or merged patient counts here but not in the dataset.
with expected as (
    select count(*) as row_count
    from {{ ref('discharges') }} d
    join {{ ref('encounters') }} e on e.id = d.encounter_id
    join {{ ref('patients') }} p on p.id = e.patient_id
    join {{ ref('locations') }} l on l.id = e.location_id
    join {{ ref('facilities') }} f on f.id = l.facility_id
    where not f.is_sensitive
),

actual as (
    select count(*) as row_count
    from {{ ref('ds__discharge_audit') }}
)

select
    'ac_001_discharge_audit_row_count' as failed_ac,
    expected.row_count as expected_value,
    actual.row_count as actual_value
from expected
cross join actual
where expected.row_count != actual.row_count

union all

-- AC-002: one row per encounter
select
    'ac_002_discharge_audit_one_row_per_encounter' as failed_ac,
    count(*) as expected_value,
    count(distinct encounter_id) as actual_value
from {{ ref('ds__discharge_audit') }}
having count(*) != count(distinct encounter_id)

union all

-- AC-003: the recorded date and time is always populated
select
    'ac_003_discharge_audit_recorded_datetime_not_null' as failed_ac,
    0 as expected_value,
    count(*) as actual_value
from {{ ref('ds__discharge_audit') }}
where discharge_recorded_datetime is null
having count(*) > 0
