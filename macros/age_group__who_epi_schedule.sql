{% macro age_group__who_epi_schedule(age_months_column) %}
{#
    EPI-style age cohorts, banded in whole months rather than years: <1 year (0-11 months),
    12-23 months, 24-59 months, and 5+ years (60+ months) for doses given outside the
    childhood schedule (adolescent/adult vaccines, catch-up doses).

    <1 year and 12-23 months are the two cohorts WHO/UNICEF administrative and survey
    coverage reporting use most: administrative coverage is conventionally reported against
    children under 1 year, and coverage surveys (WHO/UNICEF, DHS, MICS) validate against
    children 12-23 months so every child in the cohort has had the opportunity to complete
    the primary schedule.

    Source: https://www.who.int/news-room/questions-and-answers/item/who-unicef-estimates-of-national-immunization-coverage
    (WUENIC methodology); https://dhsprogram.com/data/Guide-to-DHS-Statistics/Vaccination.htm
    (12-23/24-35 month survey cohorts).

    Named with the age_group__ prefix so other age-banding standards group together by name
    (see also age_group__who_primary_classification, banded in years for the general
    population rather than months for early-childhood immunisation).

    Parameters:
    - age_months_column: SQL expression yielding age in whole months.

    Returns: CASE expression producing the band label, or 'Unknown age' when the age is
    null or outside 0-1440 months (0-120 years; null falls through the `between` checks to
    the else branch).
#}
    case
        when {{ age_months_column }} between 0 and 11    then '<1 year'
        when {{ age_months_column }} between 12 and 23   then '12-23 months'
        when {{ age_months_column }} between 24 and 59   then '24-59 months'
        when {{ age_months_column }} between 60 and 1440 then '5+ years'
        else 'Unknown age'
    end
{% endmacro %}
