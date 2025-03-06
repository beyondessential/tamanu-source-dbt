{%- macro get_nth_weekday(nth_weekday) -%}
    case {{ nth_weekday }}
        when -1 then 'last ' when 1 then 'first ' when 2 then 'second '
        when 3 then 'third ' when 4 then 'fourth ' else ''
    end
{%- endmacro -%}

{%- macro get_schedule_prefix(interval, frequency) -%}
    concat(
        case when "{{ interval }}" = 1 then
                case {{ frequency }}
                    when 'WEEKLY' then 'Weekly on a '
                    when 'MONTHLY' then 'Monthly on the '
                end
            else concat('Every ', "{{ interval }}",
                case {{ frequency }}
                    when 'WEEKLY' then ' weeks on '
                    when 'MONTHLY' then ' months on the '
                end
            )
        end
    )
{%- endmacro -%}

{%- macro get_day_name(day) -%}
    case {{ day }}
        when 'MO' then 'Monday'
        when 'TU' then 'Tuesday'
        when 'WE' then 'Wednesday'
        when 'TH' then 'Thursday'
        when 'FR' then 'Friday'
         when 'SA' then 'Saturday'
        when 'SU' then 'Sunday'
        else {{ day }}
    end
{%- endmacro -%}

{%- macro unnest_and_map(days_array) -%}
    array_to_string(
        array(select {{ get_day_name('unnest_day') }} from unnest({{ days_array }}) as unnest_day),
        ', '
    )
{%- endmacro -%}

{%- macro get_recurrence_description(interval, frequency, days_of_week, nth_weekday) -%}
    concat(
        {{ get_schedule_prefix(interval, frequency) }},
        {{ get_nth_weekday(nth_weekday) }},
        {{ unnest_and_map(days_of_week) }}
    )
{%- endmacro -%}
