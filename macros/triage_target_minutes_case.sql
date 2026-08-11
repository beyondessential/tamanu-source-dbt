{#
Renders the target waiting time in minutes for a triage category, from
var('triage_target_minutes').

Nothing here raises. Anything the map does not cover yields NULL, which blanks that row's
target and its compliance verdict rather than failing the report:

  - a triage score outside the map (dirty or unexpected reference data, an empty score)
  - a category the map omits
  - a map entry whose value is not a whole, non-negative number of minutes -- skipped, so a
    malformed override degrades to "no verdict for that category" instead of breaking the build

A triage score is mandatory in the triage form, but Triage.score is a plain nullable TEXT
column in the model, so nothing below the UI guarantees one. Blanking a row is therefore the
safer failure mode for a standard report running against deployments and history this repo
cannot see. AC-003 in data_tests/data_test__ds__emergency_triage.sql is the backstop: it
surfaces a category between 1 and 5 with no target at test time.
#}
{%- macro triage_target_minutes_case(score_field) -%}
case {{ score_field }}
{%- for score, minutes in var('triage_target_minutes').items() %}
{%- if minutes is integer and minutes >= 0 %}
    when '{{ score }}' then {{ minutes }}
{%- endif %}
{%- endfor %}
end
{%- endmacro -%}
