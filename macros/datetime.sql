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
{# Interprets the stored naive timestamp as the central TZ, then converts to the
   user-selected TZ. When :timezone is empty this is a no-op by design — the
   round-trip normalises the output to a naive timestamp for to_char. #}
{%- if flags.WHICH == 'compile' -%}
(({{ field }} at time zone '{{ var("timezone") }}') at time zone coalesce(nullif(:timezone, ''), '{{ var("timezone") }}'))
{%- else -%}
{{ field }}
{%- endif -%}
{%- endmacro -%}

{%- macro from_user_selected_timezone(bound) -%}
{# Maps a naive date/timestamp bound, expressed in the user-selected TZ, onto the absolute
   timestamptz scale that a raw `logged_at` sits on. The counterpart to
   to_user_selected_timezone: that one converts the column so it can be displayed, this one
   converts the bound so a range predicate can leave the column bare and stay prunable.
   Outside compile there is no :timezone parameter, so the central TZ applies on both sides
   and the two macros stay consistent -- which the BL-030 safety net depends on.

   `timestamp at time zone` is not injective, so the pair is equivalent only in zones with no
   DST transition at local midnight. Where one exists (America/Havana, America/Santiago) a
   midnight bound is ambiguous and an event in the repeated hour can fall outside the
   converted bound while satisfying the final WHERE -- the one direction the safety net
   cannot recover. No Tamanu deployment zone transitions at midnight. #}
{%- if flags.WHICH == 'compile' -%}
(({{ bound | trim }})::timestamp at time zone coalesce(nullif(:timezone, ''), '{{ var("timezone") }}'))
{%- else -%}
(({{ bound | trim }})::timestamp at time zone '{{ var("timezone") }}')
{%- endif -%}
{%- endmacro -%}
