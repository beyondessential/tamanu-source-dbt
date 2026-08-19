-- DHIS2 Data Elements for the NCD Indicators report. One row per
-- (data element, indicator); joined in the report layer on
-- indicator = metric__ncd_indicators.metric_id.
--
-- The 31 UIDs are shared across MSF OCA deployments (global to the MSF OCA
-- DHIS2 instance), confirmed against the NCD indicators source sheet. Built only
-- when var('msf_oca_dhis2') is true. The disaggregation each indicator uses is chosen in
-- the report layer per config: consultations / diagnoses / exits / referrals join
-- map__dhis_coc_disease_age_sex; active-care / measurement / cohort join the
-- age x sex COC map.
--
-- The four `exit_*_total` rows are the not-disaggregated-by-diagnosis siblings of
-- exit_ltfu / exit_deceased / exit_transferred / exit_other -- separate DHIS2 data
-- elements for the same program-exit events, reported without a disease-category
-- breakdown, so they join the age x sex COC map instead.
select * from (
    values
    -- Consultations
    ('ikSttyNueq4', 'consultations_new'),
    ('a61MeKyQPEb', 'consultations_followup'),

    -- Diagnoses
    ('pWFIhkyjkqd', 'diagnoses'),
    ('A4UOHgAAk6Y', 'diagnoses_new'),

    -- Active care
    ('TGfoSq64wXr', 'patients_active'),
    ('URrPYOHZ4i1', 'patients_new'),

    -- Program exits
    ('u2RPykkuQ9n', 'exit_ltfu'),
    ('ApzxVSP0YAO', 'exit_deceased'),
    ('AcK20EAaBSm', 'exit_transferred'),
    ('fLY5ILuLJwH', 'exit_other'),

    -- Program exits (not disaggregated by diagnosis)
    ('tHEKnb10d3D', 'exit_ltfu_total'),
    ('W7VmjaTuJqC', 'exit_deceased_total'),
    ('nxneni1Dtu5', 'exit_transferred_total'),
    ('VLNtPSIvQIR', 'exit_other_total'),

    -- Referrals
    ('O44JlJopQkf', 'referred_specialist'),

    -- Quality of care / protocol implementation
    ('K52dGJ8RttI', 'htn_bp_measured'),
    ('Ba260yPzUKx', 'htn_bp_controlled'),
    ('DvTer1QNdo8', 'diabetes_bp_measured'),
    ('N8GdW5EwW9z', 'diabetes_bp_controlled'),
    ('JP15MQTCn0W', 'diabetes_hba1c_measured'),
    ('XkmJ1vHj2HD', 'diabetes_hba1c_controlled'),

    -- 6-month cohort outcomes (percentages)
    ('hn6habO9qFJ', 'cohort_6m_retention_percent'),
    ('eswZVoZnISL', 'cohort_6m_htn_bp_measured_percent'),
    ('k0sHeJle3I6', 'cohort_6m_htn_bp_control_percent'),
    ('gC3M47SBzX4', 'cohort_6m_diabetes_bp_measured_percent'),
    ('TrKqBMvh5Xe', 'cohort_6m_diabetes_bp_control_percent'),
    ('knwlHOOykVt', 'cohort_6m_diabetes_hba1c_measured_percent'),
    ('YbMBZB2xu20', 'cohort_6m_diabetes_hba1c_control_percent'),

    -- 6-month cohort outcomes (active counts)
    ('XsE1vfPR5jK', 'cohort_6m_patients_active'),
    ('cCc6RsBn3zX', 'cohort_6m_htn_active'),
    ('Gd08YGU581r', 'cohort_6m_diabetes_active')
) t (id, indicator)
