{{ config(severity='warn') }}

-- One row per procedure whose own location is at a different facility from its encounter's
-- location. ds__procedures and ds__sensitive_procedures each require both facilities to be in
-- their own partition, so a row with crosses_sensitivity_partition true is in neither dataset.
-- Without has_sensitive_facility only standard facilities resolve, so a procedure with either
-- side at a sensitive facility is not checked.
with all_facilities as (
    select
        id,
        false as is_sensitive
    from {{ ref('facilities') }}
    {%- if var('has_sensitive_facility', false) %}
        union all
        select
            id,
            true as is_sensitive
        from {{ ref('sensitive_facilities') }}
    {%- endif %}
)

select
    pc.id as procedure_id,
    pc.encounter_id,
    procedure_facility.id as procedure_facility_id,
    encounter_facility.id as encounter_facility_id,
    procedure_facility.is_sensitive != encounter_facility.is_sensitive as crosses_sensitivity_partition
from {{ ref('procedures') }} pc
join {{ ref('encounters') }} e
    on e.id = pc.encounter_id
join {{ ref('locations') }} procedure_location
    on procedure_location.id = pc.location_id
join all_facilities procedure_facility
    on procedure_facility.id = procedure_location.facility_id
join {{ ref('locations') }} encounter_location
    on encounter_location.id = e.location_id
join all_facilities encounter_facility
    on encounter_facility.id = encounter_location.facility_id
where procedure_facility.id != encounter_facility.id
