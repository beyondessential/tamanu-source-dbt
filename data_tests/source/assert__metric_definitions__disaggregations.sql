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
        -- ed_visit's principal diagnosis, grouped to a WHO ICD-10 chapter
        'principal_diagnosis__icd10_chapter',
        -- ed_visit's arrival hour
        'ed_start__hour',
        -- ed_stay's encounter discharge disposition
        'discharge_disposition'
    )
