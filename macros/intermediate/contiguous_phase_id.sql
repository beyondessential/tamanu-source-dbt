{% macro contiguous_phase_id(partition_by, dimensions, order_by) %}

{#-
    An identifier shared by consecutive rows describing the same thing, so a stream of
    per-event rows can be grouped into contiguous phases.

    A segment stream is not a phase stream, and every ward-level consumer has to bridge
    that gap. clinical__visit_detail opens a segment per encounter_history snapshot, so a
    clinician handover in one ward starts a fresh segment with the same location. The
    admission history spines open one per qualifying change, so an encounter_type change
    that moved nobody starts a fresh episode in the same location. Anything counting ward
    movements or measuring length of stay per ward must collapse those first; this is that
    step, written once.

    Usage -- group by the partition, the dimensions AND the phase id:

        select
            encounter_id,
            location_id,
            min(visit_detail_start_datetime) as phase_start,
            max(visit_detail_end_datetime)   as phase_end
        from segments
        group by
            encounter_id,
            location_id,
            {{ contiguous_phase_id('encounter_id', ['location_id'], 'visit_detail_start_datetime') }}

    Grouping by the phase id alone is wrong: the id is only unique within a dimension
    value, so two different locations in one encounter can share one. The dimensions are
    part of the key.

    Implemented as the difference of two row numbers rather than a running sum over a
    lag, because Postgres will not nest window calls -- `sum(... lag() over ...) over ()`
    is a syntax error, not a slow query.

    BL-001: a recurring value opens a new phase. A patient moved A -> B -> A gets three
    phases, not two, because the row-number difference shifts on the second visit to A.

    BL-002: nulls group. `partition by` treats two nulls as equal, so consecutive rows
    with no location are one phase and a move into or out of one is a boundary. This is
    the behaviour a `lag(...) is distinct from` form would give and a bare `!=` would not.

    BL-003: `order_by` must be the ordering the caller bounds phases by, and should be
    deterministic. Rows tied on it fall into either phase arbitrarily.

    Arguments:
      partition_by  column or expression the phases run within, usually the encounter
      dimensions    list of columns whose change ends a phase
      order_by      ordering within the partition, usually the segment start
-#}

row_number() over (partition by {{ partition_by }} order by {{ order_by }})
    - row_number() over (partition by {{ partition_by }}, {{ dimensions | join(', ') }} order by {{ order_by }})

{% endmacro %}
