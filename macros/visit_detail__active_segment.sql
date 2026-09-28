{#
    The clinical__visit_detail segment active at each event's own timestamp, one row per event.

        active_segment as (
            {{ visit_detail__active_segment('events', 'event_id', 'event_datetime') }}
        )

    `events` is a CTE carrying `event_id`, `event_datetime` and the encounter id in
    `visit_occurrence_id_column`. It returns `event_id` and `visit_detail_id`, and needs a
    `visit_detail` CTE selecting from clinical__visit_detail.

    The rule is clinical__procedure_occurrence BL-005 (specs/dbt-model/
    clinical__procedure_occurrence.md): the latest segment already started by the event's
    timestamp, clamped to the encounter's earliest segment where the event predates every
    segment. The join carries no timestamp condition, so the order by picks the as-of segment
    where one qualifies and falls back to the earliest otherwise.

    The visit_detail_id tie-breaks are split by branch: among segments sharing a start datetime,
    the as-of branch takes the last and the clamp branch the first, matching the
    (start_datetime, visit_detail_id) order clinical__visit_detail chains its own segments by.

    An event whose encounter has no segment returns no row, so a consumer's join decides whether
    it is kept with a NULL segment or dropped.
#}
{% macro visit_detail__active_segment(events, event_id, event_datetime, visit_occurrence_id_column='visit_occurrence_id') %}
    select distinct on (o.{{ event_id }})
        o.{{ event_id }},
        vd.visit_detail_id
    from {{ events }} o
    join visit_detail vd
        on vd.visit_occurrence_id = o.{{ visit_occurrence_id_column }}
    order by
        o.{{ event_id }},
        (vd.visit_detail_start_datetime <= o.{{ event_datetime }}) desc,
        case when vd.visit_detail_start_datetime <= o.{{ event_datetime }}
                then vd.visit_detail_start_datetime
        end desc,
        case when vd.visit_detail_start_datetime > o.{{ event_datetime }}
                then vd.visit_detail_start_datetime
        end asc,
        case when vd.visit_detail_start_datetime <= o.{{ event_datetime }}
                then vd.visit_detail_id
        end desc,
        case when vd.visit_detail_start_datetime > o.{{ event_datetime }}
                then vd.visit_detail_id
        end asc
{% endmacro %}
