-- derived__episode_pregnancy_samoa -- one row per pregnancy of a woman in antenatal care, under
-- Samoa Ministry of Health's definition: assembled from her antenatal care contacts and closed by
-- its outcome.
-- See specs/dbt-model/derived__episode_pregnancy_samoa.md for the BL clauses this model implements.
--
-- Sources only from bases/ and int__ (D10).

-- the DAK elements carried from the pregnancy's contacts
{%- set episode_elements = [
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

-- BL-011: the antenatal care contacts
with contacts as (
    select * from {{ ref('int__who_dak_anc_contacts') }}
),

submissions as (
    select * from {{ ref('int__who_dak_anc_submissions') }}
),

patients as (
    select * from {{ ref('patients') }}
),

patient_additional_data as (
    select * from {{ ref('patient_additional_data') }}
),

-- BL-005: the events that end a pregnancy, ranked by BL-006's order
outcome_events as (
    -- BL-006 (1): an end-of-pregnancy form, dated by its outcome, else by its own day
    select
        s.patient_id,
        coalesce(s.delivery_date, s.miscarriage_abortion_date, s.death_date, s.contact_day) as event_date,
        s.closure_reason,
        'end_form'::text as closure_source,
        1 as priority
    from submissions s
    where s.closure_reason is not null
        or s.delivery_date is not null
        or s.miscarriage_abortion_date is not null
        or s.death_date is not null

    union all

    -- BL-006 (2): a child whose record names her as mother, born that day
    select
        pad.mother_id as patient_id,
        child.date_of_birth as event_date,
        'Live birth'::text as closure_reason,
        'birth_record'::text as closure_source,
        2 as priority
    from patient_additional_data pad
    join patients child on child.id = pad.patient_id
    where pad.mother_id is not null
        and child.date_of_birth is not null

    union all

    -- BL-006 (3): her death
    select
        p.id as patient_id,
        p.date_of_death::date as event_date,
        'Woman died'::text as closure_reason,
        'death'::text as closure_source,
        3 as priority
    from patients p
    where p.date_of_death is not null
),

-- BL-010: a contact in the 42 days after an end-of-pregnancy form's outcome or a child's birth is
-- postnatal
postnatal_contacts as (
    select distinct
        c.patient_id,
        c.contact_day
    from contacts c
    join outcome_events oe
        on oe.patient_id = c.patient_id
        and oe.closure_source in ('end_form', 'birth_record')
        and oe.event_date < c.contact_day
        and oe.event_date + 42 >= c.contact_day
),

antenatal_contacts as (
    select c.*
    from contacts c
    left join postnatal_contacts pc
        on pc.patient_id = c.patient_id
        and pc.contact_day = c.contact_day
    where pc.patient_id is null
),

contact_days as (
    select
        c.*,
        lag(c.contact_day) over (partition by c.patient_id order by c.contact_day) as previous_contact_day
    from antenatal_contacts c
),

-- BL-002: contacts with an outcome event on or after her previous contact and before this one
contacts_after_outcome as (
    select distinct
        cd.patient_id,
        cd.contact_day
    from contact_days cd
    join outcome_events oe
        on oe.patient_id = cd.patient_id
        and oe.event_date >= cd.previous_contact_day
        and oe.event_date < cd.contact_day
),

-- BL-002: a contact starts a pregnancy when it is her first, when more than 140 days have passed
-- since her previous contact, or when an outcome event fell between the two
pregnancy_starts as (
    select
        cd.*,
        case
            when cd.previous_contact_day is null then 1
            when cd.contact_day - cd.previous_contact_day > 140 then 1
            when cao.patient_id is not null then 1
            else 0
        end as starts_pregnancy
    from contact_days cd
    left join contacts_after_outcome cao
        on cao.patient_id = cd.patient_id
        and cao.contact_day = cd.contact_day
),

numbered as (
    select
        ps.*,
        sum(ps.starts_pregnancy) over (
            partition by ps.patient_id
            order by ps.contact_day
            rows between unbounded preceding and current row
        ) as pregnancy_number
    from pregnancy_starts ps
),

-- BL-003: the pregnancy's span and contacts. BL-004: each element is the latest recorded at one of
-- its contacts
episodes as (
    select
        n.patient_id,
        n.pregnancy_number,
        min(n.contact_day) as episode_start_date,
        max(n.contact_day) as last_contact_date,
        count(*)::integer as contact_count,
        array_agg(n.contact_day order by n.contact_day asc) as contact_days,
        (array_agg(n.facility_id order by n.contact_day asc))[1] as first_contact_facility_id,
        {%- for column in episode_elements %}
            (array_agg(
                n.{{ column }} order by n.contact_day desc
            ) filter (where n.{{ column }} is not null))[1] as {{ column }}{{ "," if not loop.last }}
        {%- endfor %}
    from numbered n
    group by n.patient_id, n.pregnancy_number
),

bounded as (
    select
        e.*,
        lead(e.episode_start_date) over (
            partition by e.patient_id order by e.episode_start_date
        ) as next_episode_start_date
    from episodes e
),

-- BL-006: the highest-ranked outcome event from her first contact up to 140 days after her last,
-- and before her next pregnancy starts, the earliest winning a tie
outcomes as (
    select distinct on (b.patient_id, b.pregnancy_number)
        b.patient_id,
        b.pregnancy_number,
        oe.event_date,
        oe.closure_reason,
        oe.closure_source
    from bounded b
    join outcome_events oe
        on oe.patient_id = b.patient_id
        and oe.event_date >= b.episode_start_date
        and oe.event_date <= b.last_contact_date + 140
        and (b.next_episode_start_date is null or oe.event_date < b.next_episode_start_date)
    order by b.patient_id asc, b.pregnancy_number asc, oe.priority asc, oe.event_date asc
),

-- BL-006 (4): with no outcome, lost to follow-up once another pregnancy has started or more than
-- 140 days have passed since her last contact. BL-007: open while neither applies
closed as (
    select
        b.*,
        o.event_date as outcome_date,
        o.closure_reason as outcome_reason,
        o.closure_source as outcome_source,
        o.event_date is null
        and (
            b.next_episode_start_date is not null
            or {{ get_current_date() }} - b.last_contact_date > 140
        ) as is_lost_to_follow_up
    from bounded b
    left join outcomes o
        on o.patient_id = b.patient_id
        and o.pregnancy_number = b.pregnancy_number
)

select
    'episode_pregnancy_samoa'::text as metric_id,
    -- BL-011: a definition of its own, not a variant of one
    null::text as variant_id,
    (b.patient_id || ';' || to_char(b.episode_start_date, 'YYYY-MM-DD'))::varchar as episode_id,
    b.patient_id::varchar as subject_id,
    -- the standard OMOP concept is deferred to the future vocab__ layer
    null::integer as episode_concept_id,
    b.episode_start_date,
    case
        when b.outcome_date is not null then b.outcome_date
        when b.is_lost_to_follow_up then b.last_contact_date
    end as episode_end_date,
    case
        when b.outcome_date is not null then b.outcome_reason
        when b.is_lost_to_follow_up then 'Lost to follow-up'
    end as closure_reason,
    case
        when b.outcome_date is not null then b.outcome_source
        when b.is_lost_to_follow_up then 'no_contact'
    end as closure_source,
    b.first_contact_facility_id,
    b.last_contact_date,
    b.contact_count,
    b.contact_days,
    {%- for column in episode_elements %}
    b.{{ column }}{{ "," if not loop.last }}
    {%- endfor %}
from closed b
