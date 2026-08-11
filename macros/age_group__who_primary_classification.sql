{% macro age_group__who_primary_classification(age_column) %}
{#
    WHO "primary" age classification bands, labelled by range rather than the WHO category
    name: 0-14 (Children), 15-24 (Youth), 25-44 (Young Adults), 45-59 (Middle Age),
    60-74 (Elderly / Older Persons), 75+ (Seniors).

    Source: https://wellfr.com/understanding-the-who-classification-of-age-groups-according-to-who
    (an aggregator page, not a primary who.int publication -- cited as the exact source
    referenced when this band set was chosen; revisit if a more authoritative WHO document
    defining these same bands is found).

    Named with the age_group__ prefix so other age-banding standards added later group
    together by name (see also macros/msf/msf_calculate_age_group.sql, which is pinned to
    MSF's own DHIS2 category-option values and is not part of this family).

    Parameters:
    - age_column: SQL expression yielding age in whole years.

    Returns: CASE expression producing the band label, or 'Unknown age' when the age is
    null or outside 0-120 (null falls through the `between` checks to the else branch).
#}
    case
        when {{ age_column }} between 0 and 14   then '0-14 years'
        when {{ age_column }} between 15 and 24  then '15-24 years'
        when {{ age_column }} between 25 and 44  then '25-44 years'
        when {{ age_column }} between 45 and 59  then '45-59 years'
        when {{ age_column }} between 60 and 74  then '60-74 years'
        when {{ age_column }} between 75 and 120 then '75+ years'
        else 'Unknown age'
    end
{% endmacro %}
