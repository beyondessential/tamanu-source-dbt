-- int__who_dak_hiv_registry_outcomes -- one row each time a client's registration in the ART
-- program registry enters a death or transferred out clinical status, as the HIV treatment
-- outcome that status records.
--
-- The registry's clinical status is where a death or a transfer out is recorded, whether on the
-- registry page or by the DAK follow-up form's treatment outcome (HIV.H.DE41), which sets the
-- status. A form answer holding one of the DAK's outcomes is an outcome too, and both feed the
-- outcomes int__who_dak_hiv_client_month_state reads.
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-061.

{% set death_status_ids = var('who_dak_hiv_death_status_ids', []) %}
{% set transferred_out_status_ids = var('who_dak_hiv_transferred_out_status_ids', []) %}
{% set outcome_status_ids = death_status_ids + transferred_out_status_ids %}

with status_log as (
    select
        cl.changelog_id,
        cl.id as registration_id,
        cl.patient_id,
        cl.logged_at,
        cl.clinical_status_id,
        lag(cl.clinical_status_id) over (
            partition by cl.id
            order by cl.logged_at_utc asc, cl.record_updated_at_utc asc, cl.changelog_id asc
        ) as previous_clinical_status_id
    from {{ ref('patient_program_registrations_change_logs') }} cl
    where cl.program_registry_id = '{{ var("art_episode_registry_id") }}'
)

-- BL-061: each time a registration enters a death or transferred out status, dated when it was
-- logged. A registration recorded in error records no outcome
select
    'registry:' || sl.changelog_id as response_id,
    sl.patient_id,
    sl.logged_at as submitted_datetime,
    case
        when sl.clinical_status_id in ('{{ death_status_ids | join("', '") }}')
            then 'Death (documented)'
        else 'Transferred out'
    end as hiv_treatment_outcome
from status_log sl
where sl.clinical_status_id in ('{{ outcome_status_ids | join("', '") }}')
    and sl.clinical_status_id is distinct from sl.previous_clinical_status_id
    and not exists (
        select 1
        from {{ ref('patient_program_registrations') }} ppr
        where ppr.id = sl.registration_id
            and ppr.registration_status = 'recordedInError'
    )
