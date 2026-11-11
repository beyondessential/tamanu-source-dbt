-- metric__birth -- D5 metric view for the four maternity/newborn indicators registered in
-- documentations/metrics/maternity.yml: birth, low_birth_weight, preterm_birth,
-- low_apgar_5min (MAUI-6838).
-- Spec: specs/dbt-model/metric__birth.md (BL-001..BL-017).
-- See specs/dbt-model/metric__birth.md for the BL clauses this model implements.
--
-- Per-birth (subject) grain: one row per registered live birth, per metric_id, value_numeric
-- 1, so a consumer aggregates at whatever grain it needs (BL-013). low_birth_weight,
-- preterm_birth and low_apgar_5min are each a `where` subset of birth sharing the same base,
-- so a subject appears once per metric_id it qualifies for.
--
-- Subsets are separate metric_ids rather than boolean disaggregation columns (ed_visit's
-- is_admitted) because each depends on a measure that is often unrecorded: a boolean would
-- have to collapse "not low birth weight" and "weight not recorded" into one false.
--
-- No visit/encounter concept applies: patient_birth_data is a standalone birth-registration
-- table, not visit-scoped (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with patient_birth_data as (
    select * from {{ ref('patient_birth_data') }}
),

patients as (
    select * from {{ ref('patients') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

patient_additional_data as (
    select * from {{ ref('patient_additional_data') }}
),

patient_conditions as (
    select * from {{ ref('patient_conditions') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

-- BL-017: patients with a recorded condition coded as diabetes -- ICD-10 E10-E14 (diabetes
-- mellitus) or O24 (diabetes in pregnancy). Matched on the code's first three characters,
-- upper-cased, the way diagnosis__icd10_chapter matches, so no deployment's list of condition
-- ids has to be kept here. Any recorded condition counts, resolved or not: the legacy
-- definition this replaces did not look at resolution either. bases/patient_conditions
-- already drops deleted rows. `distinct` holds it to one row per patient, so the join below
-- cannot fan a birth out where the mother has several such conditions.
diabetic_patients as (
    select distinct pc.patient_id
    from patient_conditions pc
    join reference_data rd
        on rd.id = pc.condition_id
    where left(upper(rd.code), 3) between 'E10' and 'E14'
        or left(upper(rd.code), 3) = 'O24'
),

-- BL-016: the newborn's mother, through patient_additional_data.mother_id, resolved against
-- bases/patients so a deleted or merged mother record counts as no mother. Only her date of
-- birth and diabetes flag leave this CTE -- her id is used to join and then dropped, so no
-- row of this model carries an identifier of the mother.
mothers as (
    select
        pad.patient_id as newborn_id,
        m.date_of_birth as mother_date_of_birth,
        dp.patient_id is not null as is_diabetic
    from patient_additional_data pad
    join patients m
        on m.id = pad.mother_id
    left join diabetic_patients dp
        on dp.patient_id = m.id
),

-- BL-002: inner join to patients drops soft-deleted, merged and test patients.
-- BL-003: period_start is the date of birth, falling back to the registration date where the
-- patient record carries no date of birth. birth_time is deliberately absent: at day
-- granularity it cannot change the result, since date_of_birth + birth_time truncates to the
-- same day as date_of_birth alone.
-- BL-004: sex is the newborn's own clinical__person.gender_source_value.
-- BL-010: facility is carried as the recorded birth_facility_id and left nullable -- a home
-- or other-place birth genuinely has none, and dropping those rows would bias "deliveries by
-- place" toward facility births. Deliberately not joined to bases/facilities: that base
-- filters deleted_at is null, so a birth at a since-retired facility would come back NULL and
-- land in the home/other-place bucket -- a data gap wearing the costume of a real home birth,
-- which is precisely what BL-010 promises a NULL here never is.
births as (
    select
        pbd.patient_id as subject_id,
        date_trunc(
            'day',
            coalesce(
                p.date_of_birth::timestamp,
                pbd.registration_date::timestamp
            )
        ) as period_start,
        pbd.birth_facility_id as facility_id,
        per.gender_source_value as sex,
        -- BL-015: the newborn's own home village, from their clinical__person record.
        per.location_id as patient_location_id,
        pbd.birth_delivery_type,
        pbd.attendant_at_birth,
        pbd.registered_birth_place,
        pbd.birth_type,
        pbd.birth_weight,
        pbd.gestational_age_estimate,
        pbd.apgar_score_five_minutes,
        -- BL-016: the mother's age in whole years on the newborn's date of birth. NULL where
        -- no mother is linked, or either date of birth is missing.
        extract(year from age(p.date_of_birth, mo.mother_date_of_birth))::int as mother_age_years,
        -- BL-017: false, not NULL, where no mother is linked -- the same array-filter reason
        -- as BL-009.
        coalesce(mo.is_diabetic, false) as is_mother_diabetic
    from patient_birth_data pbd
    join patients p on p.id = pbd.patient_id
    join person per on per.person_id = pbd.patient_id
    -- BL-016: left join -- a birth with no linked mother still counts. One
    -- patient_additional_data row per patient, the same assumption clinical__person's own join
    -- makes, so this cannot fan out (AC-001 is the backstop).
    left join mothers mo on mo.newborn_id = pbd.patient_id
),

-- D5 wide format: one row per (metric_id, subject_id). birth is every row; the three
-- subsets below are each a `where` filter over the same base, unioned together (BL-005,
-- BL-006, BL-007).
metric_rows as (
    select
        'birth'::text as metric_id,
        *
    from births

    union all

    -- BL-005: low_birth_weight, numerator only -- WHO/UNICEF threshold. A birth with no
    -- recorded weight emits no row here, and is not subtracted from birth's count.
    select
        'low_birth_weight'::text as metric_id,
        *
    from births
    where birth_weight is not null and birth_weight < 2.5

    union all

    -- BL-006: preterm_birth, numerator only -- WHO threshold, same caveat as above.
    select
        'preterm_birth'::text as metric_id,
        *
    from births
    where gestational_age_estimate is not null and gestational_age_estimate < 37

    union all

    -- BL-007: low_apgar_5min, numerator only -- WHO Newborn Health guidance threshold,
    -- same caveat as above.
    select
        'low_apgar_5min'::text as metric_id,
        *
    from births
    where apgar_score_five_minutes is not null and apgar_score_five_minutes < 7
)

select
    metric_id,
    null::text as variant_id,
    subject_id::varchar as subject_id,
    period_start,
    -- BL-003: a birth is a point event, not a stay -- period_end equals period_start rather
    -- than signalling "still open" the way an encounter's NULL period_end does.
    period_start as period_end,
    'day'::text as period_granularity,
    -- BL-013: one birth per row, so the count contribution is always 1.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-009: raw source values, ungrouped -- relabelling to a human-readable form is a
    -- presentation choice left to the consumer's data table. All four are nullable in
    -- patient_birth_data and all four coalesce to 'Not recorded', the sibling metrics'
    -- convention (ed_visit's triage_score, procedure's procedure_code): Tupaia's array filter
    -- drops NULL rows, so a raw NULL would disappear the birth from a "by delivery type" card
    -- and stop the split reconciling with the birth total. Unlike facility_id (BL-010), a NULL
    -- here carries no meaning of its own -- it is an unfilled field, not a home birth.
    coalesce(birth_delivery_type, 'Not recorded') as birth_delivery_type,
    coalesce(attendant_at_birth, 'Not recorded') as attendant_at_birth,
    coalesce(registered_birth_place, 'Not recorded') as registered_birth_place,
    coalesce(birth_type, 'Not recorded') as birth_type,
    -- BL-014: measures, not dimensions -- continuous, so banding is the consumer's.
    birth_weight,
    gestational_age_estimate,
    apgar_score_five_minutes,
    -- BL-015: the newborn's home village as a Tamanu id, untranslated like facility_id and
    -- deliberately not coalesced -- NULL means the record carries no village, the same rule as
    -- metric__immunisation_dose's patient_location_id, so the two join to one village list.
    patient_location_id,
    -- BL-016: a measure, not a dimension -- banding (e.g. age_group__aihw_maternal_age) is the
    -- consumer's.
    mother_age_years,
    -- BL-017
    is_mother_diabetic
from metric_rows
