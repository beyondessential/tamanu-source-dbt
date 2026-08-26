{#
    Age in whole years at a given date, from clinical__person's split birth date.

    Was copied verbatim into three models before it was lifted here; the fourth would have
    copied it too, without checking whether the NULL rule still held.

        {{ age_years('vd.visit_detail_start_date', 'pr') }}

    `as_at` is the date to measure at, `person_alias` the alias of a clinical__person row.

    A NULL year_of_birth yields NULL rather than an error. month_of_birth and day_of_birth are
    extracted from the same date_of_birth column in clinical__person, so they are populated
    whenever year_of_birth is -- which is why make_date never errors on a partial date.
#}
{% macro age_years(as_at, person_alias) %}
case
    when {{ person_alias }}.year_of_birth is not null then
        extract(year from age(
            {{ as_at }},
            make_date(
                {{ person_alias }}.year_of_birth,
                {{ person_alias }}.month_of_birth,
                {{ person_alias }}.day_of_birth
            )
        ))::int
end
{% endmacro %}
