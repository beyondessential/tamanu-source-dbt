with filtered_changes as (
    {{ base_history_from_log('patients') }}
)

select
    fc.changelog_id,
    fc.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    fc.updated_by_user_id,
    fc.record_data ->> 'id' as id,
    fc.record_data ->> 'display_id' as display_id,
    fc.record_data ->> 'first_name' as first_name,
    fc.record_data ->> 'middle_name' as middle_name,
    fc.record_data ->> 'last_name' as last_name,
    fc.record_data ->> 'cultural_name' as cultural_name,
    fc.record_data ->> 'email' as email,
    initcap((fc.record_data ->> 'sex')::text) as sex,
    (fc.record_data ->> 'date_of_birth')::date as date_of_birth,
    (fc.record_data ->> 'date_of_death')::timestamp as date_of_death,
    fc.record_data ->> 'village_id' as village_id,
    (fc.record_data ->> 'created_at')::date as registration_date
from filtered_changes fc
