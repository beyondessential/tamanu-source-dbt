-- Tamanu user id -> the clinician's display name.
--
-- A `map__` relation rather than a direct join to bases/users, because a consumer resolving
-- a clinician id reads this from the same schema as the metric it is joining to. Only
-- `public_tupaia`-routed relations are readable there, and bases/users carries staff email
-- and phone number -- routing that view to `public_tupaia` would hand contact details to
-- every consumer that can read a metric. This projects the two columns a label needs and
-- nothing else. Same mechanism as the locations/location_groups routing in dbt_project.yml,
-- and the reason for the narrower relation is the difference.
--
-- Universal: every deployment names clinicians the same way, so there is nothing per-
-- deployment to maintain and this lives in tamanu-source-dbt rather than in a deployment's
-- own project.
--
-- View-over-bases rather than a seed so it stays current as users are added and renamed.

select
    id as clinician_id,
    display_name as clinician_name
from {{ ref('users') }}
