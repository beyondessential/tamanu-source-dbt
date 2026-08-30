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
    target, else 0. A patient in neither cohort also returns 0, not NULL, so
    callers must restrict rows to the diabetic or hypertensive cohort before
    aggregating -- this macro grades a row and does not define the denominator.
#}
    -- Diabetes is scored in its own nested case: a diabetic patient must meet
    -- <130 and can never be rescored against the laxer <140 target.
    case
        when {{ has_diabetes }} = 1 then
            case
                when {{ sbp }} < 130 and {{ dbp }} < 90 then 1
                else 0
            end
        when {{ has_htn }} = 1 then
            case
                when {{ sbp }} < 140 and {{ dbp }} < 90 then 1
                else 0
            end
        else 0
    end
{% endmacro %}
