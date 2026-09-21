{#- One row per encounter: the earliest discharge recorded against it.

    Deduped with `not exists` rather than `distinct on (d.encounter_id)`. DISTINCT ON is a
    pushdown barrier, so a caller filtering by encounter_id had to build and sort this whole
    table first; a plain `where` lets that filter reach the index on discharges.

    `(created_at, id)` rather than created_at alone, so a tie resolves to the same row every
    run. -#}
select
    d.id,
    d.note,
    d.encounter_id,
    d.discharger_id as discharged_by_id,
    d.disposition_id,
    d.created_at at time zone '{{ var("timezone") }}' as created_datetime
from {{ source('tamanu', 'discharges') }} d
join {{ source('tamanu', 'encounters') }} e on e.id = d.encounter_id
where d.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    and not exists (
        select 1
        from {{ source('tamanu', 'discharges') }} d2
        where d2.encounter_id = d.encounter_id
            and d2.deleted_at is null
            and (d2.created_at, d2.id) < (d.created_at, d.id)
    )
