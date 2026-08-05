-- DHIS2 Data Elements for the MSF OCA chronic-care OPD consultations dataset.
-- One row per (data element, indicator); joined in the report layer on
-- indicator = metric_id (dhis_datavalue_union de_map). Same flat (id, indicator)
-- shape as map__dhis_de_ncd_indicators.
--
-- The 53 UIDs are global to the MSF OCA DHIS2 instance (not deployment-specific):
-- 6 of the 7 chronic-disease follow-up UIDs are shared verbatim with the other
-- MSF OCA OPD deployment, confirming the DE library is common. Disabled in this
-- repo; an MSF OCA deployment re-enables maps/msf_oca in its own dbt_project.yml.
--
-- Indicator slug = <category>_<consultation_type>, consultation_type in
-- {new, followup}. Category slugs align with the other deployment's general-OPD
-- map where a UID is shared (respiratory, diabetes_i/ii, epilepsy, hypertension,
-- other_opd), so that deployment can adopt this map without renaming.
select * from (
    values
    -- HIV / TB -- recorded in Tamanu, so both new and follow-up consultations
    ('PCkRKT2IfGP', 'hiv_new'),                                 -- DE_ADIA_049  HIV and HIV-related illnesses
    ('ZpkUnq12WJs', 'hiv_followup'),                            -- DE_ADIF_064  HIV and HIV-related illnesses
    ('wuc2SxlEEtM', 'tb_new'),                                  -- DE_ADIA_096  Tuberculosis (pulmonary and extra-pulmonary)
    ('afpSyJgEDcb', 'tb_followup'),                             -- DE_ADIF_094  Tuberculosis (pulmonary and extra-pulmonary)
    -- Chronic disease -- follow-up only: first presentation happens in the general
    -- clinic (an external system), so Tamanu only ever sees the follow-up visit
    ('tmZnDb2zXv2', 'anaemia_followup'),                        -- DE_ADIF_005  Anaemia
    ('vRYmx3pxmUG', 'diabetes_i_followup'),                     -- DE_ADIF_093  Diabetes I
    ('qeBtAeq52KT', 'diabetes_ii_followup'),                    -- DE_ADIF_048  Diabetes II
    ('c2yEpoxrIdd', 'epilepsy_followup'),                       -- DE_ADIF_047  Epilepsy
    ('eIsz5t1Yygg', 'hypertension_followup'),                   -- DE_ADIF_043  Hypertension
    ('vtB0XkglrIi', 'other_opd_followup'),                      -- DE_ADIF_060  Other chronic diseases
    ('gIxpLqQejvb', 'respiratory_followup'),                    -- DE_ADIF_007  Asthma or COPD
    -- Psychiatric diagnoses -- recorded in Tamanu, so both new and follow-up
    ('YgP0ZcX6Usc', 'psych_adjustment_new'),                    -- DE_ADIA_111  Adjustment disorder
    ('giCYfMIIpeN', 'psych_adjustment_followup'),               -- DE_ADIF_105  Adjustment disorder
    ('H8e9WopnxPN', 'psych_anxiety_new'),                       -- DE_ADIA_106  Anxiety and fear-related disorders
    ('KLptt9uMsZ1', 'psych_anxiety_followup'),                  -- DE_ADIF_101  Anxiety and fear-related disorders
    ('v8egyNEordr', 'psych_bipolar_new'),                       -- DE_ADIA_112  Bipolar disorder (incl. mania)
    ('gjiqGkf0axr', 'psych_bipolar_followup'),                  -- DE_ADIF_106  Bipolar disorder (incl. mania)
    ('UCjOU1ZB5KT', 'psych_childhood_behavioural_new'),         -- DE_ADIA_118  Childhood behavioral disorder (incl. ADHD, conduct disorder)
    ('YRptpGuZiur', 'psych_childhood_behavioural_followup'),    -- DE_ADIF_109  Childhood behavioral disorder (incl. ADHD, conduct disorder)
    ('Nh5jtOn0Xje', 'psych_childhood_emotional_new'),           -- DE_ADIA_119  Childhood emotional disorder
    ('UbyNBSvobmm', 'psych_childhood_emotional_followup'),      -- DE_ADIF_110  Childhood emotional disorder
    ('R21l48jzjPr', 'psych_depressive_new'),                    -- DE_ADIA_110  Depressive disorders
    ('vdG88tKFdAe', 'psych_depressive_followup'),               -- DE_ADIF_104  Depressive disorders
    ('NmC2Uwm3gCr', 'psych_dissociative_new'),                  -- DE_ADIA_105  Dissociative disorders (incl. psychogenic seizures)
    ('iEKvfIEk0Nz', 'psych_dissociative_followup'),             -- DE_ADIF_100  Dissociative disorders (incl. psychogenic seizures)
    ('c0zHWqCoCoV', 'psych_elimination_new'),                   -- DE_ADIA_109  Elimination disorders (Enuresis/ Encopresis)
    ('xSe56ttAi9Y', 'psych_elimination_followup'),              -- DE_ADIF_103  Elimination disorders (Enuresis/ Encopresis)
    ('W7yOiHCblX7', 'psych_epilepsy_seizures_new'),             -- DE_ADIA_122  Epilepsy/seizures
    ('OT8nQr33NpI', 'psych_epilepsy_seizures_followup'),        -- DE_ADIF_112  Epilepsy/seizures
    ('JSHrHK0wH5e', 'psych_mups_new'),                          -- DE_ADIA_108  Medically unexplained physical symptoms (MUPS)
    ('zGjLQ5t1E4l', 'psych_mups_followup'),                     -- DE_ADIF_102  Medically unexplained physical symptoms (MUPS)
    ('LjQxiZb5YC7', 'psych_neurocognitive_new'),                -- DE_ADIA_121  Neurocognitive disorders
    ('YdtNCYEvkUs', 'psych_neurocognitive_followup'),           -- DE_ADIF_111  Neurocognitive disorders
    ('SFIkyA8emVg', 'psych_neurodevelopmental_new'),            -- DE_ADIA_077  Neurodevelopmental disorder
    ('VqRfIQaksTS', 'psych_neurodevelopmental_followup'),       -- DE_ADIF_078  Neurodevelopmental disorder
    ('HTu1osSbNkI', 'psych_ocd_new'),                           -- DE_ADIA_103  Obsessive-compulsive and related disorders
    ('Z4iYF55p0sh', 'psych_ocd_followup'),                      -- DE_ADIF_098  Obsessive-compulsive and related disorders
    ('bY0FTln3dZC', 'psych_other_psych_new'),                   -- DE_ADIA_123  Other psychiatric disorders
    ('E62wANkKALy', 'psych_other_psych_followup'),              -- DE_ADIF_113  Other psychiatric disorders
    ('IXFBuI9qLIE', 'psych_postpartum_nonpsychotic_new'),       -- DE_ADIA_116  Post-partum symptoms without psychotic features
    ('PU3LfAMuEzH', 'psych_postpartum_nonpsychotic_followup'),  -- DE_ADIF_108  Post-partum symptoms without psychotic features
    ('eYJvL9tkhX3', 'psych_postpartum_psychosis_new'),          -- DE_ADIA_115  Post-partum psychosis
    ('vyMEOIXq8b0', 'psych_postpartum_psychosis_followup'),     -- DE_ADIF_107  Post-partum psychosis
    ('aNmkPFcBiIW', 'psych_prolonged_grief_new'),               -- DE_ADIA_104  Prolonged grief/ loss
    ('CPnegJRotvd', 'psych_prolonged_grief_followup'),          -- DE_ADIF_099  Prolonged grief/ loss
    ('D0ZMUcfKise', 'psych_psychosis_acute_new'),               -- DE_ADIA_069  Psychosis, acute
    ('dXDK7rmjiaR', 'psych_psychosis_acute_followup'),          -- DE_ADIF_070  Psychosis, acute
    ('oCVxK8IwYEE', 'psych_psychosis_chronic_new'),             -- DE_ADIA_070  Psychosis, chronic
    ('WDGUKaKB8UU', 'psych_psychosis_chronic_followup'),        -- DE_ADIF_071  Psychosis, chronic
    ('Kz1MiEsCxok', 'psych_ptsd_new'),                          -- DE_ADIA_068  Post-traumatic stress disorder
    ('kZVmdVSDCCg', 'psych_ptsd_followup'),                     -- DE_ADIF_069  Post-traumatic stress disorder
    ('sw3DhYYQMgb', 'psych_substance_use_new'),                 -- DE_ADIA_076  Substance use disorders
    ('mCuqnCtrFZ1', 'psych_substance_use_followup')             -- DE_ADIF_077  Substance use disorders
) t (id, indicator)
