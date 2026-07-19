{{ config(
    materialized = ('view' if target.name.startswith('reporting_') else 'table'),
    tags = ['clinical'],
) }}

-- clinical__observation_period -- OMOP-lite OBSERVATION_PERIOD domain. One row per
-- patient with recorded clinical activity (BL-001); bounds are the min/max event
-- dates across the five event domains (BL-002), per the OMOP EHR convention.
-- See specs/dbt-model/clinical__observation_period.md for BL-001..BL-005.

with event_dates as (
    select
        person_id,
        visit_start_date as event_date
    from {{ ref('clinical__visit_occurrence') }}
    where visit_start_date is not null

    union all

    -- closed-visit ends bound the period too (BL-002); open visits contribute
    -- only their start
    select
        person_id,
        visit_end_date as event_date
    from {{ ref('clinical__visit_occurrence') }}
    where visit_end_date is not null

    union all

    select
        person_id,
        condition_start_date as event_date
    from {{ ref('clinical__condition_occurrence') }}
    where condition_start_date is not null

    union all

    select
        person_id,
        measurement_date as event_date
    from {{ ref('clinical__measurement') }}
    where measurement_date is not null

    union all

    select
        person_id,
        drug_exposure_start_date as event_date
    from {{ ref('clinical__drug_exposure') }}
    where drug_exposure_start_date is not null

    union all

    -- the domain carries no end-date column; cast the end datetime (BL-002)
    select
        person_id,
        drug_exposure_end_datetime::date as event_date
    from {{ ref('clinical__drug_exposure') }}
    where drug_exposure_end_datetime is not null

    union all

    select
        person_id,
        observation_date as event_date
    from {{ ref('clinical__observation') }}
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
-- no outer join to clinical__person, so an event-less patient contributes no
-- rows here and is correctly absent from the output (BL-005)
from event_dates
group by person_id
