{#
    Each user's current designations as one row per user: user_id, and designations, the
    designation names alphabetical and joined with ', ' (e.g. 'Dentist, Medical Officer').

    A user can hold several designations (user_designations is many-to-many), so a model
    joining clinicians to their designations collapses them here first -- joining
    user_designations directly would fan a row out once per designation.

    Tamanu keeps no designation history, so these are the designations held now. Only
    reference data of type 'designation' counts. A user with none has no row, so a caller
    left joins and supplies its own fallback.

        clinician_designations as (
            {{ user_designation_names() }}
        )
#}
{% macro user_designation_names() %}
    select
        ud.user_id,
        string_agg(distinct designation.name, ', ' order by designation.name) as designations
    from {{ ref('user_designations') }} ud
    join {{ ref('reference_data') }} designation
        on designation.id = ud.designation_id
        and designation.type = 'designation'
    group by ud.user_id
{% endmacro %}
