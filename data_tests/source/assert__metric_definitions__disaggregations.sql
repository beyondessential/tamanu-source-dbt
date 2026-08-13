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
        'dhis_ncd_category',
        -- ed_visit's admission outcome, carried as a disaggregation on
        -- metric__emergency_visit's per-encounter rows rather than as its own metric_id.
        'is_admitted',
        -- ed_visit's triage acuity category
        'triage_score',
        -- ed_visit's principal diagnosis, grouped to a WHO ICD-10 chapter
        'principal_diagnosis__icd10_chapter',
        -- ed_visit's arrival hour
        'ed_start__hour',
        -- ed_visit's total length of stay, and ed_stay's emergency department portion,
        -- each split at four hours. Separate names because the two are not comparable.
        'length_of_stay__4_hours_band',
        'ed_time__4_hours_band',
        -- ed_stay's encounter discharge disposition
        'discharge_disposition'
    )
