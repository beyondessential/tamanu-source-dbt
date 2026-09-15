-- ref__provider -- OMOP PROVIDER wrapper over Tamanu users (clinicians/examiners).
-- One row per user (BL-001); thin projection with no joins, so grain is users.id verbatim.
-- Native UUID PK (D1). Sources only from bases/ (D10); OMOP column naming applied (D2).
-- Specialty/care-site/demographics deliberately omitted (BL-004).
-- See specs/dbt-model/ref__provider.md for BL-001..BL-004.

with users as (
    select * from {{ ref('users') }}
)

select
    -- identity (BL-001, BL-002) -- native UUID PK, no remap to OMOP integer IDs (D1)
    u.id           as provider_id,
    u.display_name as provider_name,
    u.display_id   as provider_source_value,

    -- single-valued account role, carried to distinguish clinical from non-clinical users
    -- (specialty is a many-to-many in user_designations and is not emitted, BL-003/BL-004)
    u.role         as role

from users u
