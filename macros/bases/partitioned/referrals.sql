{#- Body of `referrals` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro referrals_base(network=none) -%}
select
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id,
    updated_at_sync_tick
from {{ source('tamanu', 'referrals') }}
where deleted_at is null
    -- BL-005: the referral follows its initiating encounter's partition
    and {{ encounter_id_in_partition('initiating_encounter_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
