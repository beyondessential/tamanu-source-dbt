-- int__who_dak_anc_submissions -- one row per native or mapped WHO DAK ANC form submission, with
-- the DAK data elements it carries, cast to Annex A's types.
-- See specs/dbt-model/metric__who_dak_anc_indicators.md for the BL clauses this model implements.
--
-- Reads DAK data elements from two routes: the generated who-dak-anc forms, whose question codes
-- are the DAK element ids, and a deployment's own forms mapped to DAK element ids through the
-- who_dak_anc_local_surveys var. Both land in one (submission, element) shape, so nothing after
-- element_answers knows which route an answer came by.
--
-- Sources only from bases/ (D10).

-- the DAK elements this model reads, by Annex A id
{%- set elements = {
    'contact_date': 'ANC.A7.DE4',
    'contact_number': 'ANC.A7.DE12',
    'gestational_age_weeks': 'ANC.B6.DE17',
    'lmp_date': 'ANC.B6.DE14',
    'edd_date': 'ANC.B6.DE22',
    'gravida': 'ANC.B6.DE24',
    'miscarriages_abortions': 'ANC.B6.DE25',
    'parity': 'ANC.B6.DE32',
    'tt_dose_1_date': 'ANC.B10.DE166',
    'tt_dose_2_date': 'ANC.B10.DE168',
    'tt_dose_3_date': 'ANC.B10.DE170',
    'tt_dose_4_date': 'ANC.B10.DE172',
    'tt_dose_5_date': 'ANC.B10.DE174',
    'closure_reason': 'ANC.End.1',
    'delivery_date': 'ANC.End.12',
    'miscarriage_abortion_date': 'ANC.End.38',
    'death_date': 'ANC.End.39',
} -%}

-- BL-009: Annex A's type for every element. contact_date is read separately, as the
-- submission's day
{%- set element_types = {
    'contact_number': 'integer',
    'gestational_age_weeks': 'numeric',
    'lmp_date': 'date',
    'edd_date': 'date',
    'gravida': 'integer',
    'miscarriages_abortions': 'integer',
    'parity': 'integer',
    'tt_dose_1_date': 'date',
    'tt_dose_2_date': 'date',
    'tt_dose_3_date': 'date',
    'tt_dose_4_date': 'date',
    'tt_dose_5_date': 'date',
    'closure_reason': 'text',
    'delivery_date': 'date',
    'miscarriage_abortion_date': 'date',
    'death_date': 'date',
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

encounters as (
    select * from {{ ref('encounters') }}
),

locations as (
    select * from {{ ref('locations') }}
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

-- every native or mapped ANC submission, with the patient and facility of its encounter. The
-- surveys are named as literals so the survey_id index narrows the responses
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
    {%- for survey_id in local_surveys %}
        or r.survey_id = '{{ survey_id }}'
    {%- endfor %}
),

-- every answer on an ANC submission, read once and shared by both routes below
anc_answers as (
    select
        a.response_id,
        s.survey_id,
        pde.code as question_code,
        nullif(trim(a.body), '') as body
    from {{ ref('survey_response_answers') }} a
    join anc_submissions s on s.response_id = a.response_id
    join {{ ref('program_data_elements') }} pde on pde.id = a.data_element_id
),

-- one row per (submission, DAK element), whichever route it came by
element_answers as (
    -- BL-002: native forms, whose question code is the DAK element's
    select
        aa.response_id,
        aa.question_code as element_code,
        aa.body
    from anc_answers aa
    where aa.survey_id like 'program-whodakanc-%'
        and aa.question_code in (
            {%- for code in element_codes.values() %}
                '{{ code }}'{{ "," if not loop.last }}
            {%- endfor %}
        )

    union all

    -- BL-003: a mapped answer is read exactly as the native answer to its DAK element
    select
        aa.response_id,
        m.element_code,
        aa.body
    from anc_answers aa
    join local_map m
        on m.survey_id = aa.survey_id
        and m.local_code = aa.question_code
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
)

-- BL-009: cast to Annex A's types. try_cast is not available on this adapter, so each cast is
-- guarded by what its type requires and anything else reads NULL
select
    s.response_id,
    s.survey_id,
    s.patient_id,
    s.facility_id,
    s.start_datetime,
    s.end_datetime,
    s.is_contact_form,
    {%- for column, data_type in element_types.items() %}
        {%- if data_type == 'text' %}
            v.{{ column }}_raw as {{ column }},
        {%- elif data_type == 'date' %}
            {{ safe_iso_date('v.' ~ column ~ '_raw') }} as {{ column }},
        {%- else %}
            case
                {%- if data_type == 'integer' %}
                    -- a whole number that fits an integer, which a Number question may store with a
                    -- trailing .0
                    when v.{{ column }}_raw ~ '^\d{1,9}(\.0+)?$' then v.{{ column }}_raw::numeric::integer
                {%- else %}
                    when v.{{ column }}_raw ~ '^\d+(\.\d+)?$' then v.{{ column }}_raw::numeric
                {%- endif %}
            end as {{ column }},
        {%- endif %}
    {%- endfor %}
    -- BL-006: the recorded contact date, else the submission's own start date. A non-contact
    -- form carries no contact date, so its day is when it was filled in
    coalesce(
        {{ safe_iso_date('v.contact_date_raw') }},
        s.start_datetime::date
    ) as contact_day
from anc_submissions s
left join pivoted v on v.response_id = s.response_id
