select
    id,
    created_at as created_datetime,
    updated_at as updated_datetime
    {%- set columns = [
        {'expr': 'display_id', 'name': 'display_id', 'is_direct_identifier': true},
        {'expr': 'first_name', 'name': 'first_name', 'is_direct_identifier': true},
        {'expr': 'middle_name', 'name': 'middle_name', 'is_direct_identifier': true},
        {'expr': 'last_name', 'name': 'last_name', 'is_direct_identifier': true},
        {'expr': 'cultural_name', 'name': 'cultural_name', 'is_direct_identifier': true},
        {'expr': 'email', 'name': 'email', 'is_direct_identifier': true},
        {'expr': 'initcap(sex::text)', 'name': 'sex', 'is_direct_identifier': false},
        {'expr': 'date_of_birth::date', 'name': 'date_of_birth', 'is_direct_identifier': false},
        {'expr': 'date_of_death::timestamp', 'name': 'date_of_death', 'is_direct_identifier': false},
        {'expr': 'village_id', 'name': 'village_id', 'is_direct_identifier': false}
    ] -%}
    {%- for col in columns -%}
        {%- if not (is_analytics_target() and col.is_direct_identifier) -%}
            ,
            {{ col.expr }} as {{ col.name }}
        {%- endif -%}
    {%- endfor %}
from {{ source('tamanu', 'patients') }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
    and visibility_status != 'merged'
