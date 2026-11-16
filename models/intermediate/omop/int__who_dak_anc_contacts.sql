-- int__who_dak_anc_contacts -- one row per WHO DAK ANC contact: a woman seen for antenatal care on
-- a day, with the DAK data elements recorded for her that day.
-- See specs/dbt-model/metric__who_dak_anc_indicators.md for the BL clauses this model implements.
--
-- A contact is a contact form, or an encounter at a location group named in
-- who_dak_anc_contact_location_groups. Gestational age and gravida are worked out where not
-- recorded when who_dak_anc_calculate_gestational_age_and_gravida is on.
--
-- Sources only from bases/, clinical__ and int__who_dak_anc_submissions (D10).

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
] -%}

-- BL-017: gestational age as recorded, else, where calculation is on, the whole weeks from the LMP,
-- or from 280 days before the EDD, kept only within 0 to 45 weeks. BL-018: gravida as recorded,
-- else, where calculation is on, previous pregnancies (parity + miscarriages/abortions, Annex A's
-- ANC.B6.DE23 and ANC.B6.DE32) plus this one
{%- if var('who_dak_anc_calculate_gestational_age_and_gravida', false) -%}
    {%- set gestational_age_expression = "coalesce(a.gestational_age_weeks, "
        ~ gestational_age_weeks_from_dates('a.contact_day', 'a.lmp_date', 'a.edd_date') ~ ")" -%}
    {%- set gravida_expression = "coalesce(a.gravida, a.parity + a.miscarriages_abortions + 1)" -%}
{%- else -%}
    {%- set gestational_age_expression = "a.gestational_age_weeks" -%}
    {%- set gravida_expression = "a.gravida" -%}
{%- endif -%}

-- BL-014: location group name patterns whose encounters are contacts, as a predicate on lg.name.
-- No patterns matches no location group
{%- set contact_location_patterns = [] -%}
{%- for pattern in (var('who_dak_anc_contact_location_groups', []) or []) -%}
    {%- do contact_location_patterns.append("'" ~ (pattern | replace("'", "''")) ~ "'") -%}
{%- endfor -%}
{%- if contact_location_patterns -%}
    {%- set contact_location_predicate = "lg.name ilike any (array[" ~ (contact_location_patterns | join(", ")) ~ "])" -%}
{%- else -%}
    {%- set contact_location_predicate = "false" -%}
{%- endif %}

with submissions as (
    select * from {{ ref('int__who_dak_anc_submissions') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

locations as (
    select * from {{ ref('locations') }}
),

location_groups as (
    select * from {{ ref('location_groups') }}
),

encounter_history as (
    select * from {{ ref('encounter_history') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

-- BL-014: locations in a location group who_dak_anc_contact_location_groups names
contact_locations as (
    select
        l.id as location_id,
        l.facility_id
    from locations l
    join location_groups lg on lg.id = l.location_group_id
    where {{ contact_location_predicate }}
),

-- BL-014: an encounter is at a contact location when its own location, or any location in its
-- history, is one
contact_location_encounters as (
    select
        e.id as encounter_id,
        cl.facility_id
    from encounters e
    join contact_locations cl on cl.location_id = e.location_id

    union

    select
        eh.encounter_id,
        cl.facility_id
    from encounter_history eh
    join contact_locations cl on cl.location_id = eh.location_id
),

-- BL-015: dated by the encounter's start, excluding form-only encounters
encounter_contacts as (
    select
        e.patient_id,
        e.start_datetime::date as contact_day,
        cle.facility_id,
        e.start_datetime as source_datetime,
        e.id as source_id
    from contact_location_encounters cle
    join encounters e on e.id = cle.encounter_id
    where e.encounter_type != 'surveyResponse'
),

-- BL-004: a contact form is a contact source. BL-014: so is an encounter at a named location group
contact_sources as (
    select
        s.patient_id,
        s.contact_day,
        s.facility_id,
        s.start_datetime as source_datetime,
        s.response_id as source_id
    from submissions s
    where s.is_contact_form

    union all

    select
        patient_id,
        contact_day,
        facility_id,
        source_datetime,
        source_id
    from encounter_contacts
),

-- BL-005: one contact per patient and day. BL-010: the facility is the earliest contact source's
contacts as (
    select distinct on (patient_id, contact_day)
        patient_id,
        contact_day,
        facility_id
    from contact_sources
    order by patient_id, contact_day, source_datetime, source_id, facility_id
),

-- BL-007: elements attach from every submission for the patient on the contact day.
-- BL-008: the latest submitted wins, and an unsubmitted response (no end_datetime) sorts last.
-- BL-016: a contact with no submission that day is kept, with no elements
attached as (
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
    left join submissions s
        on s.patient_id = c.patient_id
        and s.contact_day = c.contact_day
    group by c.patient_id, c.contact_day, c.facility_id
)

select
    a.patient_id,
    a.contact_day,
    a.facility_id,
    a.contact_number,
    -- BL-017: as recorded, else worked out where calculation is on
    {{ gestational_age_expression }} as gestational_age_weeks,
    a.lmp_date,
    a.edd_date,
    -- BL-018: as recorded, else worked out where calculation is on
    {{ gravida_expression }} as gravida,
    a.miscarriages_abortions,
    a.parity,
    a.tt_dose_1_date,
    a.tt_dose_2_date,
    a.tt_dose_3_date,
    a.tt_dose_4_date,
    a.tt_dose_5_date
from attached a
left join person p on p.person_id = a.patient_id
-- BL-019: a patient recorded as male, or younger than 10 on the day, is not a contact. One with no
-- recorded sex or date of birth is kept
where lower(p.gender_source_value) is distinct from 'male'
    and coalesce({{ age_years('a.contact_day', 'p') }}, 10) >= 10
