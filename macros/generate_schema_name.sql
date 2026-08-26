{#
    Overrides dbt's default schema resolution so a `+schema:` config names an
    ABSOLUTE schema rather than a suffix.

    dbt's built-in behaviour concatenates `target.schema` with the custom name, so
    `+schema: public_tupaia` against the `analytics_*` targets (profile schema
    `analytics`) resolves to `analytics_public_tupaia`. The Tupaia-facing schema is
    `public_tupaia` exactly -- tupaia-data-product generates data table SQL that reads
    `FROM public_tupaia.metric__…` -- so the custom name is used verbatim.

    A blank or absent `+schema:` falls back to the target's own schema, which is what
    every model setting no `+schema:` relies on. It also matters for the target-aware
    configs that set one: they render to `''` off the analytics replica, and the default
    macro would turn that into `reporting_` -- a real schema, with a trailing underscore --
    because `''` is not `none`. Here it correctly means `reporting`.
#}
{%- macro generate_schema_name(custom_schema_name, node) -%}
    {%- set custom = custom_schema_name | default('', true) | trim -%}
    {%- if custom == '' -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom }}
    {%- endif -%}
{%- endmacro -%}
