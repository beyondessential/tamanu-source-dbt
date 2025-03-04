{%- macro translate_string(string_id, default_column_name=null) -%}
    {%- set language = var('language') -%}
    {%- set query -%}
        select text from {{ source('tamanu', 'translated_strings') }}
        where string_id= '{{ string_id }}' and language= '{{ language }}'
    {%- endset -%}
    {%- set result = run_query(query) -%}
    {%- if execute -%}
        {{- (result.columns[0].values()[0] if result.rows | length > 0 else default_column_name) | trim -}}
    {%- endif -%}
{%- endmacro -%}
