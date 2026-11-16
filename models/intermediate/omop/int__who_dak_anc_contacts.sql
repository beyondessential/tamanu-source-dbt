-- int__who_dak_anc_contacts -- one row per WHO DAK ANC contact and definition: a woman seen for
-- antenatal care on a day, with the DAK data elements recorded for her that day.
-- See specs/dbt-model/metric__who_dak_anc_indicators.md for the BL clauses this model implements.
--
-- The DAK definition (variant_id NULL) counts contact forms and shows the elements as recorded.
-- Where a deployment sets the who_dak_anc_samoa_moh_2026 var, the samoa_moh_2026 definition also
-- counts encounters at the antenatal clinic location groups it names, works out gestational age
-- and gravida where they are not recorded, and leaves out patients younger than 10.
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

-- BL-020: the samoa_moh_2026 definition, on when its var is set
{%- set samoa_variant_id = 'samoa_moh_2026' -%}
{%- set samoa_config = var('who_dak_anc_samoa_moh_2026', none) -%}

-- BL-014: location group name patterns whose encounters are samoa_moh_2026 contacts, as a
-- predicate on lg.name. No patterns matches no location group
{%- set contact_location_patterns = [] -%}
{%- for pattern in ((samoa_config or {}).get('contact_location_groups') or []) -%}
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

-- BL-020: the definitions this deployment builds. The DAK's always, samoa_moh_2026 when set
definitions as (
    select null::text as variant_id
    {%- if samoa_config is not none %}
    union all
    select '{{ samoa_variant_id }}'::text
    {%- endif %}
),

-- BL-014: locations in a location group the samoa_moh_2026 var names
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

-- BL-015: dated by the encounter's start, excluding form-only encounters and patients recorded
-- as male
encounter_contacts as (
    select
        e.patient_id,
        e.start_datetime::date as contact_day,
        cle.facility_id,
        e.start_datetime as source_datetime,
        e.id as source_id
    from contact_location_encounters cle
    join encounters e on e.id = cle.encounter_id
    left join person p on p.person_id = e.patient_id
    where e.encounter_type != 'surveyResponse'
        and lower(p.gender_source_value) is distinct from 'male'
),

-- BL-004: a contact form is a contact under every definition. BL-014: an encounter at a named
-- location group is a contact under samoa_moh_2026
contact_sources as (
    select
        d.variant_id,
        s.patient_id,
        s.contact_day,
        s.facility_id,
        s.start_datetime as source_datetime,
        s.response_id as source_id
    from submissions s
    cross join definitions d
    where s.is_contact_form

    union all

    select
        '{{ samoa_variant_id }}'::text as variant_id,
        patient_id,
        contact_day,
        facility_id,
        source_datetime,
        source_id
    from encounter_contacts
),

-- BL-005: one contact per definition, patient and day. BL-010: the facility is the earliest
-- contact source's
contacts as (
    select distinct on (variant_id, patient_id, contact_day)
        variant_id,
        patient_id,
        contact_day,
        facility_id
    from contact_sources
    order by variant_id, patient_id, contact_day, source_datetime, source_id, facility_id
),

-- BL-007: elements attach from every submission for the patient on the contact day.
-- BL-008: the latest submitted wins, and an unsubmitted response (no end_datetime) sorts last.
-- BL-016: a contact with no submission that day is kept, with no elements
attached as (
    select
        c.variant_id,
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
    group by c.variant_id, c.patient_id, c.contact_day, c.facility_id
)

select
    a.variant_id,
    a.patient_id,
    a.contact_day,
    a.facility_id,
    a.contact_number,
    -- BL-017: as recorded, else under samoa_moh_2026 the whole weeks from the LMP, or from 280 days
    -- before the EDD, kept only within 0 to 45 weeks
    coalesce(
        a.gestational_age_weeks,
        case
            when a.variant_id = '{{ samoa_variant_id }}'
                then {{ gestational_age_weeks_from_dates('a.contact_day', 'a.lmp_date', 'a.edd_date') }}
        end
    ) as gestational_age_weeks,
    a.lmp_date,
    a.edd_date,
    -- BL-018: as recorded, else under samoa_moh_2026 previous pregnancies (parity +
    -- miscarriages/abortions, Annex A's ANC.B6.DE23 and ANC.B6.DE32) plus this one
    coalesce(
        a.gravida,
        case
            when a.variant_id = '{{ samoa_variant_id }}'
                then a.parity + a.miscarriages_abortions + 1
        end
    ) as gravida,
    a.miscarriages_abortions,
    a.parity,
    a.tt_dose_1_date,
    a.tt_dose_2_date,
    a.tt_dose_3_date,
    a.tt_dose_4_date,
    a.tt_dose_5_date
from attached a
left join person p on p.person_id = a.patient_id
-- BL-019: under samoa_moh_2026, a patient younger than 10 on the day is not a contact. One with
-- no date of birth is kept
where a.variant_id is distinct from '{{ samoa_variant_id }}'
    or coalesce({{ age_years('a.contact_day', 'p') }}, 10) >= 10
