{#- One row per encounter, the earliest discharge recorded against it.

    Deduped with `not exists` rather than `distinct on (d.encounter_id)`, which is what
    this used to be. The row returned is the same; the reason for the change is that
    PostgreSQL cannot push a qualifier through DISTINCT ON. A caller asking for one
    encounter's discharge therefore had to build and sort this entire table first --
    on a deployment with 850k discharges that is a 59MB external merge sort to serve a
    few hundred rows, and it showed up as 39% of the encounter summary's runtime
    (MAUI-6917). A plain `where` is pushdown-safe, so the caller's encounter_id filter
    reaches the index scan on discharges instead. Measured at that scale, a scoped left
    join went from 1582ms to 7ms with identical output.

    `(created_at, id)` rather than `created_at` alone: DISTINCT ON with
    `order by encounter_id, created_at` picked arbitrarily between two discharges
    recorded in the same instant, so the row could change between runs. This picks the
    same one every time. -#}
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
