{{ config(severity='warn') }}

-- One row per procedure whose own location is at a different facility from its encounter's
-- location. ds__procedures and each sensitive network's copy of it require both facilities to
-- be in their own partition, so a row with crosses_sensitivity_partition true is in no dataset.
-- Only facilities in a partition the deployment has resolve, so a procedure with either side
-- at a facility in an unlisted sensitive network is not checked.
with all_facilities as (
    {{ every_partition('facilities', ['id', 'sensitive_network_id']) }}
),

all_procedures as (
    {{ every_partition('procedures', ['id', 'encounter_id', 'location_id']) }}
),

all_encounters as (
    {{ every_partition('encounters', ['id', 'location_id']) }}
),

all_locations as (
    {{ every_partition('locations', ['id', 'facility_id']) }}
)

select
    pc.id as procedure_id,
    pc.encounter_id,
    procedure_facility.id as procedure_facility_id,
    encounter_facility.id as encounter_facility_id,
    coalesce(procedure_facility.sensitive_network_id, '') != coalesce(encounter_facility.sensitive_network_id, '')
        as crosses_sensitivity_partition
from all_procedures pc
join all_encounters e
    on e.id = pc.encounter_id
join all_locations procedure_location
    on procedure_location.id = pc.location_id
join all_facilities procedure_facility
    on procedure_facility.id = procedure_location.facility_id
join all_locations encounter_location
    on encounter_location.id = e.location_id
join all_facilities encounter_facility
    on encounter_facility.id = encounter_location.facility_id
where procedure_facility.id != encounter_facility.id
