-- clinical__observation_period -- OMOP-lite OBSERVATION_PERIOD domain. One row per
-- patient with recorded clinical activity (BL-001) and bounds are the min/max event
-- dates across the five event domains (BL-002), per the OMOP EHR convention.
-- See specs/dbt-model/clinical__observation_period.md for BL-001..BL-005.

-- BL-018 (see specs/dbt-model/sensitive-facility-partition.md): each event domain from every
-- partition
with all_visit_occurrence as (
    {{ every_partition('clinical__visit_occurrence') }}
),

all_drug_exposure as (
    {{ every_partition('clinical__drug_exposure') }}
),

all_condition_occurrence as (
    {{ every_partition('clinical__condition_occurrence') }}
),

all_measurement as (
    {{ every_partition('clinical__measurement') }}
),

all_observation as (
    {{ every_partition('clinical__observation') }}
),

visits as materialized (
    -- single scan of clinical__visit_occurrence -- both start and end feed
    -- event_dates below, without referencing the ref() twice
    select
        person_id,
        visit_start_date,
        visit_end_date
    from all_visit_occurrence
),

drug_exposures as materialized (
    -- single scan of clinical__drug_exposure -- the domain carries no end-date
    -- column so the end datetime is cast to date here instead (BL-002)
    select
        person_id,
        drug_exposure_start_date,
        drug_exposure_end_datetime::date as drug_exposure_end_date
    from all_drug_exposure
),

event_dates as (
    select
        person_id,
        visit_start_date as event_date
    from visits
    where visit_start_date is not null

    union all

    -- closed-visit ends bound the period too (BL-002) and open visits
    -- contribute only their start
    select
        person_id,
        visit_end_date as event_date
    from visits
    where visit_end_date is not null

    union all

    select
        person_id,
        condition_start_date as event_date
    from all_condition_occurrence
    where condition_start_date is not null

    union all

    select
        person_id,
        measurement_date as event_date
    from all_measurement
    where measurement_date is not null

    union all

    select
        person_id,
        drug_exposure_start_date as event_date
    from drug_exposures
    where drug_exposure_start_date is not null

    union all

    select
        person_id,
        drug_exposure_end_date as event_date
    from drug_exposures
    where drug_exposure_end_date is not null

    union all

    select
        person_id,
        observation_date as event_date
    from all_observation
    where observation_date is not null
)

select
    -- one period per person: the person key is the natural period key (BL-003)
    person_id as observation_period_id,
    person_id,
    min(event_date) as observation_period_start_date,  -- BL-002
    max(event_date) as observation_period_end_date,    -- BL-002
    -- 44814724 = "Period covering healthcare encounters" (BL-004)
    44814724 as period_type_concept_id
-- no outer join to clinical__person and an event-less patient contributes no
-- rows here, so it is correctly absent from the output (BL-005)
from event_dates
group by person_id
