{% macro age_group__aihw_maternal_age(age_column) %}
{#
    AIHW maternal age bands, as used in the National Perinatal Data Collection and reported
    in "Australia's mothers and babies": under 20, 20-24, 25-29, 30-34, 35-39, 40 and over.

    Source: AIHW, Australia's mothers and babies -- Maternal age,
    https://www.aihw.gov.au/reports/mothers-babies/australias-mothers-babies/contents/overview-and-demographics/maternal-age

    For an obstetric population: a maternity service, or any report whose denominator is
    mothers. Five-year bands across the reproductive range, with open tails at the two groups
    AIHW reports on separately as carrying elevated risk -- under 20, and 35 and over, with 40
    and over tracked in its own right.

    Agrees with WHO's five-year groups from 20 to 39, so a value here is comparable with WHO
    age-specific fertility reporting across that span. WHO closes both ends (15-19 through
    45-49, women of reproductive age being 15-49); AIHW's open tails suit a single service's
    volume, where a closed 45-49 band is usually empty.

    For adolescent surveillance, split 'Under 20 years' at 15 in a sibling macro: WHO reports
    10-14 and 15-19 as separate indicators, and one presentation under 15 is clinically
    significant enough that an empty band is information.

    The labels do not sort into age order: 'Under 20 years' sorts after every numeric label,
    so a consumer ordering on the label column alone puts the youngest band last. AIHW's
    wording is kept because a maternal age band has no meaningful lower bound, so the consumer
    supplies an explicit order. age_group__who_primary_classification sorts correctly for free
    ('0-14 years' through '75+ years') and needs no such handling.

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
