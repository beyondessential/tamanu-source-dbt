-- derived__episode_pregnancy_samoa_contacts -- one row per samoa_moh_2026 antenatal care contact,
-- with the pregnancy episode it belongs to and its place in it.
-- See specs/dbt-model/derived__episode_pregnancy_samoa.md for the BL clauses this model implements.
--
-- Sources only from int__ and derived__ (D10).

-- BL-011: the samoa_moh_2026 contacts
with contacts as (
    select * from {{ ref('int__who_dak_anc_contacts') }}
    where variant_id = 'samoa_moh_2026'
),

episodes as (
    select * from {{ ref('derived__episode_pregnancy_samoa') }}
),

-- BL-003: a contact belongs to the pregnancy whose first-to-last contact span contains its day
assigned as (
    select
        e.episode_id,
        c.patient_id,
        c.contact_day,
        c.facility_id,
        c.gestational_age_weeks as contact_gestational_age_weeks,
        e.lmp_date,
        e.edd_date
    from contacts c
    join episodes e
        on e.subject_id = c.patient_id
        and c.contact_day between e.episode_start_date and e.last_contact_date
)

select
    a.episode_id,
    'samoa_moh_2026'::text as variant_id,
    a.patient_id::varchar as subject_id,
    a.contact_day,
    a.facility_id,
    -- BL-008: the contact's position in its pregnancy, from 1
    row_number() over (partition by a.episode_id order by a.contact_day asc)::integer as episode_contact_number,
    -- BL-009: as recorded or worked out that day, else whole weeks from the pregnancy's LMP, or from
    -- 280 days before its EDD, kept only within 0 to 45 weeks
    coalesce(
        a.contact_gestational_age_weeks,
        {{ gestational_age_weeks_from_dates('a.contact_day', 'a.lmp_date', 'a.edd_date') }}
    ) as gestational_age_weeks
from assigned a
