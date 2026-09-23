-- metric__lab_test -- D5 metric view for the lab_test indicator registered in
-- documentations/metrics/lab.yml: lab_test (MAUI-6837; renamed from lab_request, MAUI-6909).
--
-- Per-lab-test (subject) grain: one row per lab test *ordered*, whether or not it ever
-- produced a result, value_numeric 1, so a consumer aggregates at whatever grain it needs. A
-- lab request can bundle several tests (e.g. a panel), so the grain is the individual test,
-- not the request -- the same "bundle vs. line" distinction metric__pharmacy_order draws
-- against pharmacy orders. is_panel_request preserves the order-level view (BL-003).
--
-- BL-004: the order side is read from bases/lab_requests and bases/lab_tests directly, NOT
-- from a clinical__ model. Decision (Juliana, 2026-09-23): the OMOP clinical models record
-- what has clinically happened, and an order is an intent, not an occurrence -- a test
-- requested and never resulted has no place in the clinical layer. D10-compliant: D10 forbids
-- reading public.*, not bases/. Results remain clinical events and are read from
-- clinical__measurement (BL-008).
--
-- This is the change from the model's previous shape, which sourced only from
-- clinical__measurement's lab branch. That branch keeps tests carrying a reading under a
-- request that was not withdrawn (its own BL-009/BL-011), so requested-but-unresulted and
-- cancelled tests were absent by construction -- making "tests requested versus completed",
-- the headline indicator of MAUI-6837, unanswerable. Every row the previous model emitted is
-- still emitted here, as the subset where the results join hits; this model's membership is
-- strictly wider, since BL-005 also keeps the withdrawn statuses that branch excludes.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__lab_test.md for BL-001..BL-012.

with lab_requests as (
    select * from {{ ref('lab_requests') }}
),

lab_tests as (
    select * from {{ ref('lab_tests') }}
),

lab_test_types as (
    select * from {{ ref('lab_test_types') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

-- BL-008: the result, where one exists. Filtered to the lab branch so the join key
-- (measurement_id = lab_tests.id) cannot collide with the vitals or birth-data id spaces.
measurement as (
    select * from {{ ref('clinical__measurement') }}
    where measurement_type_source_value = 'lab'
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-002: department is the ACTIVE SEGMENT's department at the moment the test was ordered,
-- not the encounter's current one (BL-010). The FSM Dental consumer (MAUI-6909) reads this to
-- scope lab activity to Dental; before this change it read encounters.department_id, which
-- Tamanu updates in place, so a test ordered in Dental on a patient later moved to a ward
-- reported the ward. bases/lab_requests carries its own department_id (the requesting
-- department) -- a third value again, not used here.
departments as (
    select * from {{ ref('departments') }}
),

-- BL-003, BL-005: the grain anchor -- every ordered test, resulted or not. bases/lab_tests
-- already excludes soft-deleted tests, requests and encounters, and the test patient, so the
-- only membership rule added here is the status filter.
--
-- BL-005: 'deleted' and 'entered-in-error' assert the order never happened, so they are
-- excluded. 'cancelled', 'invalidated', 'rejected' and 'sample-not-collected' are KEPT -- each
-- was genuinely ordered, and they are half the requested-versus-completed story. This is a
-- deliberate departure from clinical__measurement's lab branch (its BL-011), which excludes
-- all six, and is why the results join below is a LEFT join. coalesce so a NULL status means
-- "keep" rather than silently dropping the row, matching that model's own guard.
ordered_tests as (
    select
        lt.id as lab_test_id,
        lt.lab_test_type_id,
        -- BL-006: the test's own completion, which is what completion and turnaround both key
        -- on. Request status is read only for membership (BL-005), never for completion.
        lt.completed_datetime,
        lr.requested_datetime,
        lr.status,
        lr.encounter_id,
        lr.lab_test_category_id,
        lr.lab_test_panel_request_id
    from lab_tests lt
    join lab_requests lr on lr.id = lt.lab_request_id
    where coalesce(lr.status, '') not in ('deleted', 'entered-in-error')
),

-- BL-010: the segment the patient was actually in when the test was ordered. The derivation
-- is shared -- see macros/visit_detail__as_of.sql for the as-of rule and the first-segment
-- clamp. Anchored on requested_datetime rather than completed_datetime: the question is where
-- the test was ordered, and a still-pending or cancelled test has no completion event to
-- anchor to at all.
active_segment as (
    {{ visit_detail__as_of('ordered_tests', 'lab_test_id', 'requested_datetime', 'encounter_id') }}
),

tests as (
    select
        ot.lab_test_id,
        -- BL-002: the order timestamp, request-level and denormalised onto every test of the
        -- request -- every test in a request is ordered together. Completion is NOT shared
        -- that way: it is per-test (BL-006).
        ot.requested_datetime,
        -- BL-006: a test is completed when it has its own completion timestamp. Decision
        -- (2026-09-24): deliberately NOT the request reaching 'published'. Completion is a
        -- property of the individual test, and this metric's grain is the test -- a request
        -- can be published while one of its tests was never run. On Tokelau that is 426 of
        -- 2502 tests. Keying both completion and turnaround on the same timestamp is also what
        -- lets a consumer average turnaround by filtering is_completed.
        (ot.completed_datetime is not null) as is_completed,
        ot.completed_datetime,
        -- BL-003: whether the test arrived as part of a panel, so a consumer counting clinical
        -- acts rather than laboratory workload can separate them from single orders.
        (ot.lab_test_panel_request_id is not null) as is_panel_request,
        loc.facility_id,
        -- BL-010: the OMOP Visit concept of the segment the test was ordered in -- 9201
        -- Inpatient, 9202 Outpatient, 9203 Emergency. This is what a consumer filters to scope
        -- to a setting, and it is why no sibling metric per setting is needed. Emitted as the
        -- concept id rather than a label: the mapping is definitional and universal
        -- (map__omop_visit_type, which also carries concept_name), so labelling belongs at the
        -- data-table layer, the same division facility_id takes.
        --
        -- Note the grouping is not 1:1 with encounter_type -- 9202 covers clinic, imaging and
        -- vaccination, and 9203 covers emergency, observation and triage -- so filtering
        -- encounter_type is NOT equivalent to filtering this column.
        vd.visit_detail_concept_id,
        -- BL-010: the segment's own encounter_type, finer than the concept above, for a
        -- consumer that wants (say) vaccination encounters specifically.
        vd.visit_detail_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- BL-011: age in whole years at the request; the NULL rule lives in the macro
        {{ age_years('ot.requested_datetime::date', 'pr') }} as age_years,
        -- BL-002
        coalesce(dept.name, 'Not recorded') as department,
        -- BL-008: identity from the test type itself, not from the measurement's
        -- measurement_source_* -- so it resolves for an unresulted test too, which is the
        -- whole point of this model.
        ltt.code as lab_test_type_code_raw,
        ltt.name as lab_test_type_raw,
        cat.name as lab_test_category_raw,
        -- BL-008: the result as recorded, where one exists. Already carries the
        -- point-of-care encoded result: clinical__measurement resolves a result-bearing test
        -- type through map__lab_test_result_encoding into value_source_value (its BL-009), so
        -- this model needs no join of its own to pick those up.
        m.value_source_value as result_raw
    from ordered_tests ot
    -- BL-008: LEFT -- an ordered test with no result must survive. This is what the previous
    -- shape could not express.
    left join measurement m
        on m.measurement_id = ot.lab_test_id
    left join lab_test_types ltt
        on ltt.id = ot.lab_test_type_id
    left join reference_data cat
        on cat.id = ot.lab_test_category_id
    -- BL-010: inner join -- a test whose encounter does not resolve to a segment is a genuine
    -- anomaly, excluded rather than attributed to a NULL facility, the same "excluded rather
    -- than guessed" convention every other metric in this repo uses. An encounter whose
    -- encounter_type is missing from map__omop_visit_type loses its segments entirely
    -- (clinical__visit_detail BL-003), which would drop the test -- guarded at source by
    -- data_test__map__omop_visit_type_coverage.
    join active_segment seg
        on seg.lab_test_id = ot.lab_test_id
    join visit_detail vd
        on vd.visit_detail_id = seg.visit_detail_id
    -- BL-010: facility is the segment's own location, not the encounter's current one
    join locations loc
        on loc.id = vd.care_site_id
    join person pr
        on pr.person_id = vd.person_id
    -- BL-002: the segment's own department
    left join departments dept
        on dept.id = vd.department_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'minute' --
-- the model reports a request-to-completion interval, not a point-in-time event, so unlike
-- the previous shape there is a period to close (BL-002).
select
    'lab_test'::text as metric_id,
    null::text as variant_id,
    lab_test_id::varchar as subject_id,
    -- BL-002: when the order was placed. The previous shape used the measurement date, which
    -- is coalesce(completed, published, requested) -- three different events in one column,
    -- from which no turnaround can be derived.
    requested_datetime as period_start,
    -- BL-002, BL-006: the test's own completion, NULL until then.
    completed_datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-003: one test per row, so the count contribution is always 1. Additive, so a data
    -- table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    visit_detail_concept_id,
    encounter_type,
    sex,
    is_completed,
    is_panel_request,
    department,
    -- BL-008: test identity, category and result as recorded and ungrouped -- classifying any
    -- of them is a presentation choice a deployment may set differently, so it happens at the
    -- data-table layer, the same division metric__encounter_diagnosis BL-006 makes for
    -- diagnosis. Each is coalesced so none is ever NULL: Tupaia exposes them as array filters,
    -- and an array filter silently drops a NULL row.
    coalesce(lab_test_type_code_raw, 'Not recorded') as lab_test_type_code,
    coalesce(lab_test_type_raw, lab_test_type_code_raw, 'Not recorded') as lab_test_type,
    coalesce(lab_test_category_raw, 'Not recorded') as lab_test_category,
    -- BL-009: emitted raw and unclassified. Deciding which recorded values mean "positive" is
    -- a deployment vocabulary question, so it is the consumer's, applied over this column at
    -- the data-table layer -- the same division BL-008 makes for test type and category. The
    -- metric deliberately stores no positivity flag and no rate: a stored proportion sums
    -- incorrectly wherever a disaggregation is collapsed (D5 rate scale).
    coalesce(result_raw, 'Not recorded') as result,
    -- BL-011: unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it.
    age_years,
    -- BL-007: request placed to test completed, in whole minutes. NULL unless completed -- a
    -- pending test has no turnaround, not a turnaround of zero, so it must leave a mean's
    -- denominator as well as its numerator. Emitted per test so the consumer averages it,
    -- following metric__inpatient_admission's length_of_stay__minutes (its BL-015);
    -- pre-aggregating here would average averages once a card groups by facility.
    --
    -- A completion recorded before its own request yields a NEGATIVE duration, and it is
    -- emitted as one -- 22 tests on Tokelau, the worst about a day, consistent with backdated
    -- entry. Deliberately not nulled, clamped or filtered (decision, 2026-09-24): the model's
    -- job is to report what was recorded, not to quietly repair it. A deployment that cannot
    -- see its bad timestamps has no reason to fix them, and every workaround here would hide
    -- the problem in the one place it is visible. The ac_..._turnaround_not_negative test is
    -- the signal: it warns with the row count, and that count going to zero is what "cleaned"
    -- looks like.
    case
        when is_completed
            then floor(extract(epoch from (completed_datetime - requested_datetime)) / 60)::integer
    end as turnaround__minutes
from tests
