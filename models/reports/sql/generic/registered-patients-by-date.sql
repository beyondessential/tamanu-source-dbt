with patients as (
    select {{
        select_with_transform(
            from='translated_ds__patients', 
            select=[
                translate_string('', 'Registration date'),
                translate_string('general.sex.label','Sex')
            ],
            update={
                translate_string('', 'Registration date'): 'date'
            }
        )
    }}
    from {{ ref("translated_ds__patients") }}
    where
        case
            when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
            else "{{ translate_string('', 'Registration date') }}" >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        end
        and
        case
            when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
            else "{{ translate_string('', 'Registration date') }}" <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
        end
)

select
    "{{ translate_string('', 'Registration date') }}",
    count(
        case when "{{ translate_string('general.sex.label','Sex') }}" = 'male' then 1 end
    ) as "{{ translate_string('', 'Males created') }}",
    count(
        case when "{{ translate_string('general.sex.label','Sex') }}" = 'female' then 1 end
    ) as "{{ translate_string('', 'Females created') }}"
from patients
group by "{{ translate_string('', 'Registration date') }}"
