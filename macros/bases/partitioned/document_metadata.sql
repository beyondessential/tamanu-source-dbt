{#- Body of `document_metadata` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro document_metadata_base(network=none) -%}
select
    id,
    name,
    type,
    created_at at time zone '{{ var("timezone") }}' as created_datetime,
    patient_id,
    encounter_id
from {{ source('tamanu', 'document_metadata') }}
where deleted_at is null
    -- BL-005: the row follows its encounter's partition, standard when it has none
    and {{ encounter_id_in_partition('encounter_id', network) }}
{%- endmacro %}
