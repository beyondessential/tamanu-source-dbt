{%- set columns = [
    {'expr': "fc.record_data ->> 'display_id'", 'name': 'display_id', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'first_name'", 'name': 'first_name', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'middle_name'", 'name': 'middle_name', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'last_name'", 'name': 'last_name', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'cultural_name'", 'name': 'cultural_name', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'email'", 'name': 'email', 'is_direct_identifier': true},
    {'expr': "initcap(fc.record_data ->> 'sex')", 'name': 'sex', 'is_direct_identifier': false},
    {'expr': "(fc.record_data ->> 'date_of_birth')::date", 'name': 'date_of_birth', 'is_direct_identifier': false},
    {'expr': "(fc.record_data ->> 'date_of_death')::timestamp", 'name': 'date_of_death', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'village_id'", 'name': 'village_id', 'is_direct_identifier': false},
    {'expr': "(fc.record_data ->> 'created_at')::date", 'name': 'registration_date', 'is_direct_identifier': false}
] -%}

with filtered_changes as (
    {{ base_history_from_log('patients') }}
        and record_id != '{{ var("test_patient") }}'
{% if dbt_utils.get_relations_by_pattern('logs', 'changes_backup') %}
    union all
    {{ base_history_from_log('patients') }}
        and record_id != '{{ var("test_patient") }}'
{% endif %}
)

select
    fc.changelog_id,
    fc.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    fc.updated_by_user_id,
    fc.record_id as id
    {%- for col in columns -%}
        {%- if not (is_analytics_target() and col.is_direct_identifier) -%}
            ,
            {{ col.expr }} as {{ col.name }}
        {%- endif -%}
    {%- endfor %}
from filtered_changes fc
