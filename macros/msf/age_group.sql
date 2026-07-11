{% macro calculate_age_group(age_column, categorisation='ncd') %}
{#
    Age-band CASE expression for MSF DHIS2 reporting disaggregations.

    Band labels match the category-option values in the MSF OCA DHIS2
    instance (map__dhis_coc_* mapping views in the deployment repos), so the
    output joins directly to COC mappings.

    Parameters:
    - age_column: SQL expression yielding age in whole years
    - categorisation: named band set
        - 'ncd': <5, 5-14, 15-49, 50+ (default) — NCD indicator reports
        - 'opd': <5, 5-14, 15+ — general OPD reports
      Add new named sets here as deployments need them; do not repurpose
      existing names, since deployed reports depend on their labels.

    Returns: CASE expression producing the band label, 'Unknown age' when the
    age is null or outside 0-120.
#}
    {% if categorisation == 'ncd' %}
    case
        when {{ age_column }} between 0 and 4 then '<5 years'
        when {{ age_column }} between 5 and 14 then '5-14 years'
        when {{ age_column }} between 15 and 49 then '15-49 years'
        when {{ age_column }} between 50 and 120 then '50+ years'
        else 'Unknown age'
    end
    {% elif categorisation == 'opd' %}
    case
        when {{ age_column }} between 0 and 4 then '<5 years'
        when {{ age_column }} between 5 and 14 then '5-14 years'
        when {{ age_column }} between 15 and 120 then '15+ years'
        else 'Unknown age'
    end
    {% else %}
    {{ exceptions.raise_compiler_error("Invalid categorisation: '" ~ categorisation ~ "'. Valid options are 'ncd' or 'opd'.") }}
    {% endif %}
{% endmacro %}
