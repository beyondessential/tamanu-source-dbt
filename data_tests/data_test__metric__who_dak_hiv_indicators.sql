-- Acceptance criteria for metric__who_dak_hiv_indicators that no column-grain test can express.
-- One row per failing criterion, so a failure names which one broke.
--
-- See specs/dbt-model/metric__who_dak_hiv_indicators.md.

with metric as (
    select * from {{ ref('metric__who_dak_hiv_indicators') }}
),

-- AC-021: every registered numerator counts a subset of its denominator's population, on the
-- same subject and in the same month (BL-028). A numerator row without its denominator row is a
-- rate above 100% waiting to be charted, and Annex C's own wording admits it in two places -- so
-- the pairing is asserted here rather than trusted to the predicates staying in step.
pairs as (
    select * from (
        values
        ('who_dak_hiv_hts_test_positive', 'who_dak_hiv_hts_test'),
        ('who_dak_hiv_hts_client_positive', 'who_dak_hiv_hts_client_tested'),
        ('who_dak_hiv_art_viral_suppression', 'who_dak_hiv_art_routine_viral_load'),
        ('who_dak_hiv_art_late_initiation', 'who_dak_hiv_art_cd4_at_initiation'),
        ('who_dak_hiv_dsd_enrolled', 'who_dak_hiv_dsd_eligible'),
        ('who_dak_hiv_dsd_retained', 'who_dak_hiv_dsd_retention_eligible'),
        ('who_dak_hiv_art_toxicity', 'who_dak_hiv_art_on_art')
    ) as t (numerator_metric_id, denominator_metric_id)
),

ac_021 as (
    select
        n.metric_id,
        n.subject_id,
        n.period_start,
        'AC-021' as failed_ac
    from pairs p
    join metric n on n.metric_id = p.numerator_metric_id
    left join metric d
        on d.metric_id = p.denominator_metric_id
        and d.subject_id = n.subject_id
        and d.period_start = n.period_start
    where d.subject_id is null
)

select metric_id, subject_id, period_start, failed_ac from ac_021
