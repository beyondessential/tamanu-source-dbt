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
        -- inpatient_admission's ward (department) the patient was admitted to
        'admission_ward_id',
        -- inpatient_admission's referral source, carried as recorded
        'admission_source',
        -- inpatient_admission's admission-mode flag: a prior ED/triage/observation phase
        'is_admitted_via_emergency',
        -- inpatient_admission's principal diagnosis, grouped to its ICD-10 chapter
        'principal_diagnosis__icd10_chapter',
        -- inpatient_admission's 30-day readmission flag: true where the same patient's
        -- immediately preceding admission discharged no more than 30 days before this one
        -- started
        'is_readmission_within_30_days',
        -- program_registry_enrolment's registry: which programme the enrolment is in. One
        -- metric serves every registry a deployment configures, so the registry is a
        -- disaggregation rather than a metric_id per programme.
        'registry_code',
        -- program_registry_enrolment's cascade position -- the registry's own clinical status
        -- list, which no metric can enumerate for a registry it has not seen.
        'clinical_status_code',
        -- program_registry_enrolment's registration state, active or inactive
        'registration_status',
        -- program_registry_enrolment's currently-at: the facility or village the patient is
        -- followed at now, which is not necessarily the one that registered them
        -- (facility_id). Read with currently_at_type, which names which of the two it is.
        'currently_at_id',
        'currently_at_type',
        -- program_registry_enrolment's exit provenance: whether the enrolment's end was
        -- recorded as a deactivation or inferred from the change log. Grouped by a service
        -- auditing a retention figure, so it is part of the contract rather than incidental.
        'episode_end_source',
        -- who_dak_hiv_dsd_retention_*: whole months since the client's DSD model started, so a
        -- consumer selects Annex C's 12/24/36/48/60-month cohort rather than the model carrying
        -- five near-identical metrics.
        'months_on_dsd',
        -- who_dak_hiv_art_on_art_key_population: the DAK's key population member type. A
        -- MultiSelect, so the metric counts client-population pairs -- see its registry row.
        'key_population',
        -- encounter_diagnosis's encounter type -- splits morbidity by setting without a
        -- metric per setting. It is the encounter's type as it now stands, not the phase the
        -- diagnosis was recorded in: Tamanu updates it in place, so an ED-phase diagnosis on
        -- a patient later admitted reads as 'admission' (metric__encounter_diagnosis BL-005).
        'encounter_type',
        -- diagnosis's recorded diagnosis, as code and as readable label. Emitted ungrouped:
        -- deployments differ in what they code diagnoses with, so any chapter or block
        -- grouping is applied downstream over diagnosis_code rather than registered here.
        'diagnosis_code',
        'diagnosis',
        -- diagnosis's certainty -- confirmed, suspected and the rest of the deployment's
        -- list. Disproven and in-error diagnoses never reach the metric.
        'diagnosis_certainty',
        -- diagnosis's principal/secondary flag, so a casemix view can count each encounter
        -- once without a separate primary-diagnosis metric.
        'is_primary',
        -- birth's delivery mode, attendant, place of birth and single/plural outcome
        -- (MAUI-6838). Raw source values, ungrouped -- relabelling is the consumer's.
        'birth_delivery_type',
        'attendant_at_birth',
        'registered_birth_place',
        'birth_type',
        -- procedure's recorded procedure, as code and as readable label. Emitted ungrouped,
        -- the same reasoning as diagnosis/diagnosis_code above.
        'procedure',
        'procedure_code',
        -- procedure's completion flag
        'is_completed',
        -- immunisation_dose's antigen
        'disease',
        -- immunisation_dose's EPI-style age cohort, banded in months
        'age_group__who_epi_schedule',
        -- immunisation_dose's schedule dose position (e.g. 'Dose 1', 'Dose 2')
        'dose_label',
        -- immunisation_dose's patient home village, distinct from facility_id
        'patient_location_id',
        -- immunisation_refusal's reason a dose was not given
        'reason'
    )
