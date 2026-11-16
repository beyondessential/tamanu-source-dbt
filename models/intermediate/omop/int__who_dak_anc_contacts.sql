-- int__who_dak_anc_contacts -- one row per WHO DAK ANC contact: a woman seen for antenatal care on
-- a day, with the DAK data elements recorded for her that day.
-- See specs/dbt-model/metric__who_dak_anc_indicators.md for the BL clauses this model implements.
--
-- Sources only from int__who_dak_anc_submissions (D10).

-- the DAK elements attached to a contact, read from int__who_dak_anc_submissions
{%- set contact_elements = [
    'contact_number',
    'gestational_age_weeks',
    'lmp_date',
    'edd_date',
    'gravida',
    'miscarriages_abortions',
    'parity',
    'tt_dose_1_date',
    'tt_dose_2_date',
    'tt_dose_3_date',
    'tt_dose_4_date',
    'tt_dose_5_date',
] %}

with submissions as (
    select * from {{ ref('int__who_dak_anc_submissions') }}
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
    order by patient_id, contact_day, start_datetime, response_id, facility_id
)

-- BL-007: elements attach from every submission for the patient on the contact day.
-- BL-008: the latest submitted wins, and an unsubmitted response (no end_datetime) sorts last
select
    c.patient_id,
    c.contact_day,
    c.facility_id,
    {%- for column in contact_elements %}
        (array_agg(
            s.{{ column }}
            order by s.end_datetime desc nulls last, s.start_datetime desc, s.response_id desc
        ) filter (where s.{{ column }} is not null))[1] as {{ column }}{{ "," if not loop.last }}
    {%- endfor %}
from contacts c
join submissions s
    on s.patient_id = c.patient_id
    and s.contact_day = c.contact_day
group by c.patient_id, c.contact_day, c.facility_id
