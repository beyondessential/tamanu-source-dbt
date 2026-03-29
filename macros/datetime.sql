{%- macro _get_current(datetime_type, native_function) -%}
    {%- set var_name = 'test_current_' ~ datetime_type -%}
    {%- if var(var_name, none) -%}
        '{{ var(var_name) }}'::{{ datetime_type }}
    {%- else -%}
        {{ native_function }}
    {%- endif -%}
{%- endmacro -%}

{%- macro get_current_date() -%}
    {{ _get_current('date', 'current_date') }}
{%- endmacro -%}

{%- macro get_current_timestamp() -%}
    {{ _get_current('timestamp', 'now()') }}
{%- endmacro -%}

{%- macro to_user_selected_timezone(field) -%}
{%- if flags.WHICH == 'compile' -%}
(({{ field }} at time zone '{{ var("timezone") }}') at time zone coalesce(nullif(:timezone, ''), '{{ var("timezone") }}'))
{%- else -%}
(({{ field }} at time zone '{{ var("timezone") }}') at time zone '{{ var("timezone") }}')
{%- endif -%}
{%- endmacro -%}
