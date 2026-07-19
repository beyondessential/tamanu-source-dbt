-- int__triage_observations -- unpivots the wide triages row into one row per recorded
-- triage element (tall shape), for the triage branch of clinical__observation.
-- Elements: the acuity score, and the chief/secondary complaints (resolved to their
-- reference_data names, type = 'triageReason'). Blank/unrecorded elements are dropped.
-- Values are kept as text here; the numeric cast happens in clinical__observation.

with triages as (
    select * from {{ ref('triages') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

triage_elements as (
    select
        t.id as triage_id,
        t.encounter_id,
        t.clinician_id,
        -- triage_time is application-required on the triage form, so it's the canonical
        -- "when"; a null here is a data-quality issue AC-006 should surface, not paper over
        t.triage_datetime as observation_datetime,
        t.score,
        cc.name as chief_complaint,
        sc.name as secondary_complaint
    from triages t
    left join reference_data cc on cc.id = t.chief_complaint_id
    left join reference_data sc on sc.id = t.secondary_complaint_id
)

-- one row per recorded element; blanks are dropped
select
    te.triage_id,
    te.encounter_id,
    te.clinician_id,
    te.observation_datetime,
    m.observation_source_value,
    m.observation_source_name,
    m.value_source_value
from triage_elements te
cross join lateral (values
    ('triage_score',        'Triage score',        te.score),
    ('chief_complaint',     'Chief complaint',     te.chief_complaint),
    ('secondary_complaint', 'Secondary complaint', te.secondary_complaint)
) as m (observation_source_value, observation_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
