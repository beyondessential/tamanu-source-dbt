-- Singular tests for clinical__person. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__person.md.

with person as (
    select * from {{ ref('clinical__person') }}
),

-- AC-004: when present, birth_datetime's date must equal the birth-date
-- components (BL-003)
ac_004 as (
    select
        person_id,
        'AC-004' as failed_ac
    from person
    where birth_datetime is not null
        and birth_datetime::date
            != make_date(year_of_birth, month_of_birth, day_of_birth)
)

select person_id, failed_ac from ac_004
