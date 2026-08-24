-- int__who_dak_hiv_form_answers -- one row per WHO DAK HIV form submission, with the data
-- elements the indicator metric reads pivoted into columns (BL-002).
--
-- The forms are generated from the DAK's Web Annex A data dictionary by tupaia-data-product
-- (tamanu/who-dak/hiv/), so a question code is the DAK data element id: HIV.D.DE38 -> the
-- program data element `pde-whodakhiv-d-de38`. That mapping is why the indicator definitions
-- in Annex C can be read against these answers at all, and it is the only place in the chain
-- where a code is hardcoded -- so it is done once, here, rather than in the metric.
--
-- Answers arrive as text in survey_response_answers.body whatever the question type, so each
-- column casts to the type Annex A declares. A malformed answer casts to NULL rather than
-- failing the build: one client's mistyped date must not stop a deployment's reporting.
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-002..BL-004.

{% set elements = {
    'hiv_status': 'whodakhiv-b-de115',
    'hiv_test_date': 'whodakhiv-b-de110',
    'hiv_test_result': 'whodakhiv-b-de111',
    'hiv_test_result_returned_date': 'whodakhiv-b-de60',
    'hiv_diagnosis_date': 'whodakhiv-b-de71',
    'on_art': 'whodakhiv-d-de38',
    'art_start_date': 'whodakhiv-d-de39',
    'baseline_cd4_count': 'whodakhiv-d-de367',
    'baseline_cd4_test_date': 'whodakhiv-d-de368',
    'viral_load_sample_date': 'whodakhiv-d-de194',
    'viral_load_result': 'whodakhiv-d-de387',
    'viral_load_reason': 'whodakhiv-d-de391',
    'dsd_eligible': 'whodakhiv-d-de760',
    'dsd_eligibility_assessed_date': 'whodakhiv-d-de761',
    'dsd_enrolled': 'whodakhiv-d-de762',
    'dsd_start_date': 'whodakhiv-d-de763',
    'art_stopped_date': 'whodakhiv-d-de41',
    'art_stopped_reason': 'whodakhiv-d-de217',
    'regimen_substitution_reason': 'whodakhiv-d-de418',
    'substitution_first_line_date': 'whodakhiv-d-de481',
    'substitution_second_line_date': 'whodakhiv-d-de487',
    'substitution_third_line_date': 'whodakhiv-d-de493',
    'key_population': 'whodakhiv-b-de50',
} %}

with responses as (
    select * from {{ ref('survey_responses') }}
),

answers as (
    select * from {{ ref('survey_response_answers') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

locations as (
    select * from {{ ref('locations') }}
),

surveys as (
    select * from {{ ref('surveys') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

-- the DAK program's own submissions. The program code is idified by the importer
-- (`who-dak-hiv` -> `whodakhiv`), so the survey id prefix is what identifies them (BL-002)
dak_responses as (
    select
        r.id as response_id,
        r.end_datetime as submitted_datetime,
        s.code as survey_code,
        e.patient_id,
        l.facility_id
    from responses r
    join surveys s on s.id = r.survey_id
    join encounters e on e.id = r.encounter_id
    left join locations l on l.id = e.location_id
    where s.id like 'program-whodakhiv-%'
),

-- one column per data element the indicators read. A form asks a question at most once, so
-- max() picks the single answer rather than aggregating several (BL-003)
pivoted as (
    select
        a.response_id,
    {%- for column, code in elements.items() %}
        max(case when a.data_element_id = 'pde-{{ code }}' then nullif(trim(a.body), '') end)
            as {{ column }}_raw{{ "," if not loop.last }}
    
{%- endfor %}
    from answers a
    where a.data_element_id in (
            {%- for code in elements.values() %}
                'pde-{{ code }}'{{ "," if not loop.last }}
            {%- endfor %}
        )
    group by a.response_id
),

typed as (
    select
    r.response_id,
    r.patient_id,
    r.facility_id,
    r.survey_code,
    r.submitted_datetime,

    p.gender_source_value as sex,
    p.year_of_birth,
    p.month_of_birth,
    p.day_of_birth,

    -- BL-004: cast to what Annex A declares. try_cast is not available on this adapter, so
    -- each cast is guarded by the pattern the type requires; anything else reads NULL
    v.hiv_status_raw as hiv_status,
    v.hiv_test_result_raw as hiv_test_result,
    v.viral_load_reason_raw as viral_load_reason,
    v.art_stopped_reason_raw as art_stopped_reason,
    v.regimen_substitution_reason_raw as regimen_substitution_reason,
    -- a MultiSelect answer, so this is a JSON array of the values the client selected.
    -- int__who_dak_hiv_key_populations unnests it; nothing else should parse it
    v.key_population_raw as key_population_json,


    {% for column in ['hiv_test_date', 'hiv_test_result_returned_date', 'hiv_diagnosis_date',
                      'art_start_date', 'baseline_cd4_test_date', 'viral_load_sample_date',
                      'dsd_eligibility_assessed_date', 'dsd_start_date', 'art_stopped_date',
                      'substitution_first_line_date', 'substitution_second_line_date',
                      'substitution_third_line_date'] %}
        case
            when v.{{ column }}_raw ~ '^\d{4}-\d{2}-\d{2}' then left(v.{{ column }}_raw, 10)::date
        end as {{ column }},
    {% endfor %}

    {% for column in ['baseline_cd4_count', 'viral_load_result'] %}
        case
            when v.{{ column }}_raw ~ '^-?\d+(\.\d+)?$' then v.{{ column }}_raw::numeric
        end as {{ column }},
    {% endfor %}

    -- a Binary question stores 'Yes'/'No' in the body, not a boolean literal
{% for column in ['on_art', 'dsd_eligible', 'dsd_enrolled'] %}
    case
        when lower(v.{{ column }}_raw) in ('yes', 'true') then true
        when lower(v.{{ column }}_raw) in ('no', 'false') then false
    end as {{ column }}{{ "," if not loop.last }}

{% endfor %}

    from dak_responses r
    join pivoted v on v.response_id = r.response_id
    join person p on p.person_id = r.patient_id
)

select
    *,
    -- BL-023: ART.9 counts a regimen substitution on any line, so the three dates collapse to
    -- the earliest recorded one -- which line it was is not part of the indicator. least()
    -- ignores NULLs in Postgres, so a client with only a third-line date gets that one
    least(
        substitution_first_line_date,
        substitution_second_line_date,
        substitution_third_line_date
    ) as regimen_substitution_date
from typed
