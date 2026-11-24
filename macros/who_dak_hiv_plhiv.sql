{#
    The clients the WHO HIV indicators treat as living with HIV, one row per client, read from a
    relation of int__who_dak_hiv_form_answers' shape (specs/dbt-model/metric__who_dak_hiv_indicators.md,
    BL-008).

        plhiv as (
            {{ who_dak_hiv_plhiv('answers') }}
        )

    Every ART and DSD numerator in Annex C is gated on "HIV status"='HIV-positive'. The DAK carries
    that element on the HTS form (HIV.B.DE115), not on the care visit, so a client seen only in care
    would fail a literal reading of the gate. A care-visit submission is taken as equivalent
    evidence: the DAK's care and treatment process is for people living with HIV, and excluding them
    would report zero on deployments that use the care form alone.
#}
{% macro who_dak_hiv_plhiv(answers) %}
    select distinct patient_id
    from {{ answers }}
    where hiv_status = 'HIV-positive'
        or hiv_test_result = 'HIV-positive'
        or survey_code = 'carevisit'
{% endmacro %}
