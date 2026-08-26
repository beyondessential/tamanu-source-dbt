select
    md.metric_id,
    trim(d) as offending_disaggregation
from {{ ref('metric_definitions') }} md
cross join lateral unnest(string_to_array(md.disaggregations, ',')) as t(d)
where trim(d) not in (
        'age_group',
        'age_group__who_primary_classification',
        'sex',
        'facility_id',
        -- opd_visit's raw location, one level finer than facility -- lets a consumer join
        -- to an area/clinic lookup later without this model resolving that join itself.
        -- First metric__ disaggregation finer than facility.
        'location_id',
        'dhis_ncd_category',
        -- ed_visit's admission outcome, carried as a disaggregation on
        -- metric__emergency_visit's per-encounter rows rather than as its own metric_id.
        'is_admitted',
        -- ed_visit's triage acuity category
        'triage_score',
        -- ed_visit's arrival hour
        'ed_start__hour',
        -- ed_stay's encounter discharge disposition
        'discharge_disposition',
        -- encounter_diagnosis's encounter type -- splits morbidity by setting without a
        -- metric per setting. It is the encounter's type as it now stands, not the phase the
        -- diagnosis was recorded in: Tamanu updates it in place, so an ED-phase diagnosis on
        -- a patient later admitted reads as 'admission' (metric__encounter_diagnosis BL-005).
        'encounter_type',
        -- encounter_diagnosis's recorded diagnosis, as code and as readable label. Emitted
        -- ungrouped: deployments differ in what they code diagnoses with, so any chapter or
        -- block grouping is applied downstream over diagnosis_code rather than registered here.
        'diagnosis_code',
        'diagnosis',
        -- encounter_diagnosis's certainty -- confirmed, suspected and the rest of the
        -- deployment's list. Disproven and in-error diagnoses never reach the metric.
        'diagnosis_certainty',
        -- encounter_diagnosis's principal/secondary flag, so a casemix view can count each
        -- encounter once without a separate primary-diagnosis metric.
        'is_primary',
        -- birth's delivery mode, attendant, place of birth and single/plural outcome
        -- (MAUI-6838). Raw source values, ungrouped -- relabelling is the consumer's.
        'birth_delivery_type',
        'attendant_at_birth',
        'registered_birth_place',
        'birth_type'
    )
