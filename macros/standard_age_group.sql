{% macro standard_age_group(age_column) %}
{#
    Standard age bands: <1, 1-4, 5-14, 15-49, 50+ years.

    Kept in a dedicated, named macro so the band choice is in one place and reusable across
    datasets.

    Parameters:
    - age_column: SQL expression yielding age in whole years.

    Returns: CASE expression producing the band label, or 'Unknown age' when the age is
    null or outside 0-120 (null falls through the `between` checks to the else branch).
#}
    case
        when {{ age_column }} between 0 and 0   then '<1 year'
        when {{ age_column }} between 1 and 4   then '1-4 years'
        when {{ age_column }} between 5 and 14  then '5-14 years'
        when {{ age_column }} between 15 and 49 then '15-49 years'
        when {{ age_column }} between 50 and 120 then '50+ years'
        else 'Unknown age'
    end
{% endmacro %}
