{#
    Gestational age in whole weeks on a day, from the last menstrual period, or from 280 days
    before the expected date of delivery when there is no LMP. NULL outside 0 to 45 weeks, or
    when neither date is known.

        {{ gestational_age_weeks_from_dates('c.contact_day', 'a.lmp_date', 'a.edd_date') }}
#}
{% macro gestational_age_weeks_from_dates(as_at, lmp_date, edd_date) %}
case
    when floor(({{ as_at }} - coalesce({{ lmp_date }}, {{ edd_date }} - 280)) / 7.0) between 0 and 45
        then floor(({{ as_at }} - coalesce({{ lmp_date }}, {{ edd_date }} - 280)) / 7.0)
end
{% endmacro %}
