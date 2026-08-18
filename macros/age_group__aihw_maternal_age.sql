{% macro age_group__aihw_maternal_age(age_column) %}
{#
    AIHW maternal age bands, as used in the National Perinatal Data Collection and reported
    in "Australia's mothers and babies": under 20, 20-24, 25-29, 30-34, 35-39, 40 and over.

    Source: AIHW, Australia's mothers and babies -- Maternal age,
    https://www.aihw.gov.au/reports/mothers-babies/australias-mothers-babies/contents/overview-and-demographics/maternal-age

    Five-year bands across the reproductive range, with open tails. The tails are the two
    groups AIHW reports on separately as carrying elevated risk: under 20, and 35 and over
    (with 40 and over tracked in its own right). WHO's five-year groups agree through the
    middle but close both ends -- 15-19 through 45-49, women of reproductive age being 15-49
    -- so a deployment reporting to WHO rather than to a perinatal collection wants a sibling
    macro rather than this one.

    Use this, not age_group__who_primary_classification, for an obstetric population. That
    one is a general-population grouping: its 25-44 band alone swallows most mothers, and its
    45-59, 60-74 and 75+ bands stay empty, so a chart of it reads as two bars and four gaps.

    WHO reports the adolescent birth rate for 10-14 and 15-19 as two separate indicators. A
    deployment doing adolescent surveillance should split 'Under 20 years' along that line in
    its own macro -- one presentation under 15 is clinically significant, so that band being
    empty is information rather than noise. Kept whole here to stay faithful to AIHW.

    Named with the age_group__ prefix so age-banding standards group together by name (see
    age_group__who_primary_classification, and macros/msf/msf_calculate_age_group.sql, which
    is pinned to MSF's own DHIS2 category-option values and is not part of this family).

    Parameters:
    - age_column: SQL expression yielding age in whole years.

    Returns: CASE expression producing the band label, or 'Unknown age' when the age is null
    or outside 0-120 (null falls through the `between` checks to the else branch).
#}
    case
        when {{ age_column }} between 0 and 19   then 'Under 20 years'
        when {{ age_column }} between 20 and 24  then '20-24 years'
        when {{ age_column }} between 25 and 29  then '25-29 years'
        when {{ age_column }} between 30 and 34  then '30-34 years'
        when {{ age_column }} between 35 and 39  then '35-39 years'
        when {{ age_column }} between 40 and 120 then '40+ years'
        else 'Unknown age'
    end
{% endmacro %}
