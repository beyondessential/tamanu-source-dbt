{%- set network = none -%}
-- metric__who_dak_anc_indicators -- D5 metric view for the WHO SMART guidelines antenatal care
-- DAK indicators registered in documentations/metrics/who_dak_anc.yml.
-- Spec: specs/dbt-model/metric__who_dak_anc_indicators.md (BL-001..BL-013).
--
-- One row per antenatal care contact. The contacts and their DAK data elements
-- come from int__who_dak_anc_contacts, which reads them from int__who_dak_anc_submissions.
--
-- Sources only from clinical__ and int__ (D10).

with contacts as (
    select * from {{ partition_ref('int__who_dak_anc_contacts', network) }}
),

person as (
    select * from {{ ref('clinical__person') }}
)

select
    'who_dak_anc_contact'::text as metric_id,
    -- BL-001: the standard definition, with no deployment variant
    null::text as variant_id,
    (c.patient_id || ';' || to_char(c.contact_day, 'YYYY-MM-DD'))::varchar as subject_id,
    c.contact_day as period_start,
    c.contact_day as period_end,
    'day'::text as period_granularity,
    -- BL-012: one contact per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,

    c.facility_id,
    c.patient_id::varchar as person_id,
    -- BL-011: whole years on the contact day, unbanded
    {{ age_years('c.contact_day', 'p') }} as age_years,
    c.contact_number,
    c.gestational_age_weeks,
    c.lmp_date,
    c.edd_date,
    c.gravida,
    c.miscarriages_abortions,
    c.parity,
    c.tt_dose_1_date,
    c.tt_dose_2_date,
    c.tt_dose_3_date,
    c.tt_dose_4_date,
    c.tt_dose_5_date

from contacts c
left join person p on p.person_id = c.patient_id
