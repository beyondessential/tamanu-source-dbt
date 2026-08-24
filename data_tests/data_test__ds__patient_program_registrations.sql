-- Singular tests for ds__patient_program_registrations after its rebase onto
-- clinical__episode. One row per violation, tagged with the acceptance criterion it breaks.
-- See specs/dbt-model/clinical__episode.md, AC-017, AC-023 and AC-028.

{% set expected_columns = [
    'patient_program_registration_id',
    'patient_id',
    'display_id',
    'first_name',
    'last_name',
    'date_of_birth',
    'sex',
    'village_id',
    'village',
    'registering_facility_id',
    'registering_facility',
    'registered_by_id',
    'registered_by',
    'currently_at',
    'currently_at_type',
    'related_condition_ids',
    'related_conditions',
    'related_condition_category_ids',
    'related_condition_categories',
    'clinical_status_id',
    'clinical_status',
    'registration_status',
    'program_registry_id',
    'subdivision_id',
    'subdivision',
    'division_id',
    'division',
    'registration_datetime',
    'deactivated_by_id',
    'deactivated_by',
    'deactivated_datetime',
    'primary_contact_number',
    'secondary_contact_number',
    'emergency_contact_name',
    'emergency_contact_number'
] %}

{# AC-017/AC-025: the rebase moved where these columns are read from, so the column list is
   the consumer contract that must not move with them (BL-023, BL-024). Compared at compile
   time against the built relation; skipped where it does not exist yet, so a compile against
   an empty warehouse does not fail on a table it has not built. #}
{% set actual_columns = [] %}
{% if execute %}
    {% set relation = adapter.get_relation(
        database=ref('ds__patient_program_registrations').database,
        schema=ref('ds__patient_program_registrations').schema,
        identifier=ref('ds__patient_program_registrations').identifier
    ) %}
    {% if relation is not none %}
        {% set actual_columns = adapter.get_columns_in_relation(relation)
            | map(attribute='name') | list %}
    {% endif %}
{% endif %}

with ac_017 as (
    select
        'AC-017' as failed_ac,
        {{ dbt.string_literal(expected_columns | join(', ')) }} as expected_columns,
        {{ dbt.string_literal(actual_columns | join(', ')) }} as actual_columns
    where {{ 'true' if actual_columns | length > 0
             and actual_columns != expected_columns else 'false' }}
),

-- AC-023: the dataset is one row per enrolment, which is every episode plus the enrolments
-- recorded in error -- not clinical facts, so absent from clinical__episode, but listed by the
-- removed-patients report and always have been (BL-025, BL-026). It must drop nothing else and
-- duplicate nothing
ac_023 as (
    select
        'AC-023' as failed_ac,
        (counts.episodes + counts.recorded_in_error)::text as expected_columns,
        counts.dataset_rows::text as actual_columns
    from (
        select
            (select count(*) from {{ ref('clinical__episode') }}) as episodes,
            (
                select count(*) from {{ ref('int__program_enrolments') }}
                where registration_status = 'recordedInError'
            ) as recorded_in_error,
            (select count(*) from {{ ref('ds__patient_program_registrations') }})
                as dataset_rows
    ) counts
    where counts.episodes + counts.recorded_in_error != counts.dataset_rows
),

-- AC-028: the rebase reports the registration's own clinical_status_id rather than the id of the
-- joined status row (BL-022), so an id with no name means the status is gone from
-- bases/program_registry_clinical_statuses -- not that the dataset dropped a resolvable one. The
-- pre-rebase model blanked both columns together, and this is the one case where the two differ
ac_028 as (
    select
        'AC-028' as failed_ac,
        d.patient_program_registration_id as expected_columns,
        d.clinical_status_id as actual_columns
    from {{ ref('ds__patient_program_registrations') }} d
    join {{ ref('program_registry_clinical_statuses') }} s on s.id = d.clinical_status_id
    where d.clinical_status_id is not null
        and d.clinical_status is null
)

select
    failed_ac,
    expected_columns,
    actual_columns
from ac_017
union all
select
    failed_ac,
    expected_columns,
    actual_columns
from ac_023
union all
select
    failed_ac,
    expected_columns,
    actual_columns
from ac_028
