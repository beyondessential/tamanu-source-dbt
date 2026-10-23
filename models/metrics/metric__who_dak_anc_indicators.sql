-- metric__who_dak_anc_indicators -- D5 metric view for the WHO SMART guidelines antenatal care
-- DAK indicators registered in documentations/metrics/who_dak_anc.yml.
-- Spec: specs/dbt-model/metric__who_dak_anc_indicators.md (BL-001..BL-013).
--
-- Reads DAK data elements from two routes: the generated who-dak-anc forms, whose question
-- codes are the DAK element ids, and a deployment's own forms mapped to DAK element ids through
-- the who_dak_anc_local_surveys var. Both land in one (submission, element) shape, so nothing
-- after element_answers knows which route an answer came by.
--
-- Sources only from bases/ and clinical__ (D10).

-- the DAK elements this model reads, by Annex A id
{%- set elements = {
    'contact_date': 'ANC.A7.DE4',
    'contact_number': 'ANC.A7.DE12',
    'gestational_age_weeks': 'ANC.B6.DE17',
} -%}

{%- set local_surveys = var('who_dak_anc_local_surveys', {}) or {} -%}

-- BL-002: ANC.A7.DE4 -> whodakanc-a7-de4
{%- set element_codes = {} -%}
{%- for column, element_id in elements.items() -%}
    {%- do element_codes.update({column: 'whodakanc-' ~ (element_id[4:] | lower | replace('.', '-'))}) -%}
{%- endfor %}

with responses as (
    select * from {{ ref('survey_responses') }}
),

answers as (
    select * from {{ ref('survey_response_answers') }}
),

data_elements as (
    select * from {{ ref('program_data_elements') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

locations as (
    select * from {{ ref('locations') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

-- BL-003: (local survey, local data element code) -> DAK question code, from the var
local_map as (
    {%- for survey_id, survey in local_surveys.items() %}
        {%- for element_id, local_code in (survey.get('data_elements') or {}).items() %}
    select
        '{{ survey_id }}'::text as survey_id,
        '{{ local_code }}'::text as local_code,
        '{{ "whodakanc-" ~ (element_id[4:] | lower | replace(".", "-")) }}'::text as element_code
    union all
        {%- endfor %}
    {%- endfor %}
    -- names the columns when the var is empty
    select
        null::text as survey_id,
        null::text as local_code,
        null::text as element_code
    where false
),

-- BL-004: the native Registration form and every mapped survey flagged is_contact
contact_surveys as (
    select 'program-whodakanc-registration'::text as survey_id
    {%- for survey_id, survey in local_surveys.items() if survey.get('is_contact') %}
    union all
    select '{{ survey_id }}'::text
    {%- endfor %}
),

-- every native or mapped ANC submission, with the patient and facility of its encounter
anc_submissions as (
    select
        r.id as response_id,
        r.survey_id,
        r.start_datetime,
        r.end_datetime,
        e.patient_id,
        -- BL-010: nullable -- a submission whose encounter has no location still counts
        l.facility_id,
        r.survey_id in (select cs.survey_id from contact_surveys cs) as is_contact_form
    from responses r
    join encounters e on e.id = r.encounter_id
    left join locations l on l.id = e.location_id
    where r.survey_id like 'program-whodakanc-%'
        or r.survey_id in (select lm.survey_id from local_map lm)
        or r.survey_id in (select cs.survey_id from contact_surveys cs)
),

-- one row per (submission, DAK element), whichever route it came by
element_answers as (
    -- BL-002: native forms, whose question code is the DAK element's
    select
        a.response_id,
        pde.code as element_code,
        nullif(trim(a.body), '') as body
    from answers a
    join anc_submissions s on s.response_id = a.response_id
    join data_elements pde on pde.id = a.data_element_id
    where s.survey_id like 'program-whodakanc-%'
        and pde.code in (
            {%- for code in element_codes.values() %}
                '{{ code }}'{{ "," if not loop.last }}
            {%- endfor %}
        )

    union all

    -- BL-003: a mapped answer is read exactly as the native answer to its DAK element
    select
        a.response_id,
        m.element_code,
        nullif(trim(a.body), '') as body
    from answers a
    join anc_submissions s on s.response_id = a.response_id
    join data_elements pde on pde.id = a.data_element_id
    join local_map m
        on m.survey_id = s.survey_id
        and m.local_code = pde.code
),

-- one row per submission, one column per element. A form asks a question at most once
pivoted as (
    select
        response_id,
    {%- for column, code in element_codes.items() %}
        max(case when element_code = '{{ code }}' then body end) as {{ column }}_raw
        {{- "," if not loop.last }}
    {%- endfor %}
    from element_answers
    group by response_id
),

-- BL-009: cast to Annex A's types. try_cast is not available on this adapter, so each cast is
-- guarded by the pattern its type requires and anything else reads NULL
submissions as (
    select
        s.response_id,
        s.patient_id,
        s.facility_id,
        s.start_datetime,
        s.end_datetime,
        s.is_contact_form,
        case
            when v.contact_number_raw ~ '^\d+$' then v.contact_number_raw::integer
        end as contact_number,
        case
            when v.gestational_age_weeks_raw ~ '^\d+(\.\d+)?$' then v.gestational_age_weeks_raw::numeric
        end as gestational_age_weeks,
        -- BL-006: the recorded contact date, else the submission's own start date. A non-contact
        -- form carries no contact date, so its day is when it was filled in
        coalesce(
            case
                when v.contact_date_raw ~ '^\d{4}-\d{2}-\d{2}' then left(v.contact_date_raw, 10)::date
            end,
            s.start_datetime::date
        ) as contact_day
    from anc_submissions s
    left join pivoted v on v.response_id = s.response_id
),

-- BL-005: one contact per patient per day with a contact form. BL-010: the facility is the
-- earliest contact form's
contacts as (
    select distinct on (patient_id, contact_day)
        patient_id,
        contact_day,
        facility_id
    from submissions
    where is_contact_form
    order by patient_id, contact_day, start_datetime, response_id
),

-- BL-007: elements attach from every submission for the patient on the contact day.
-- BL-008: the latest submitted wins; an unsubmitted response (no end_datetime) sorts last
contact_elements as (
    select
        c.patient_id,
        c.contact_day,
        (array_agg(
            s.contact_number
            order by s.end_datetime desc nulls last, s.start_datetime desc, s.response_id desc
        ) filter (where s.contact_number is not null))[1] as contact_number,
        (array_agg(
            s.gestational_age_weeks
            order by s.end_datetime desc nulls last, s.start_datetime desc, s.response_id desc
        ) filter (where s.gestational_age_weeks is not null))[1] as gestational_age_weeks
    from contacts c
    join submissions s
        on s.patient_id = c.patient_id
        and s.contact_day = c.contact_day
    group by c.patient_id, c.contact_day
)

select
    'who_dak_anc_contact'::text as metric_id,
    -- BL-001: the standard definition, with no deployment variant
    null::text as variant_id,
    (c.patient_id || ';' || to_char(c.contact_day, 'YYYY-MM-DD'))::varchar as subject_id,
    c.contact_day as period_start,
    c.contact_day as period_end,
    'day'::text as period_granularity,
    -- BL-012: one contact per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,

    c.facility_id,
    c.patient_id::varchar as person_id,
    -- BL-011: whole years on the contact day, unbanded. clinical__person carries the date of
    -- birth as its parts (birth_datetime is set only where a birth time was recorded), all three
    -- from the one date_of_birth column, so make_date never sees a partial date
    case
        when p.year_of_birth is not null then
            extract(year from age(
                c.contact_day,
                make_date(p.year_of_birth, p.month_of_birth, p.day_of_birth)
            ))::integer
    end as age_years,
    ce.contact_number,
    ce.gestational_age_weeks

from contacts c
join contact_elements ce
    on ce.patient_id = c.patient_id
    and ce.contact_day = c.contact_day
left join person p on p.person_id = c.patient_id
