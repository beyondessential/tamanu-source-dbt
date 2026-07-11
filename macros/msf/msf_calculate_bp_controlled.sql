{% macro msf_calculate_bp_controlled(sbp, dbp, has_diabetes, has_htn) %}
{#
    Blood-pressure control flag for MSF NCD quality-of-care indicators.

    MSF protocol targets (shared across MSF deployments — Syria and Kule use
    identical thresholds per their NCD indicator sheets):
    - diabetic patients:      SBP < 130 AND DBP < 90
    - hypertensive patients:  SBP < 140 AND DBP < 90
    Diabetes takes precedence when a patient has both conditions (the
    stricter target applies).

    Parameters are SQL expressions: sbp/dbp numeric, has_diabetes/has_htn
    1/0 flags. Returns 1 when the most recent BP meets the applicable
    target, else 0.
#}
    case
        when {{ has_diabetes }} = 1
            and {{ sbp }} < 130
            and {{ dbp }} < 90
        then 1
        when {{ has_htn }} = 1
            and {{ sbp }} < 140
            and {{ dbp }} < 90
        then 1
        else 0
    end
{% endmacro %}
