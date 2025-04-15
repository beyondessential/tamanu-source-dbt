{%- macro translate_string(string_id, default_column_name=null) -%}
    {%- set language = var('language') -%}
    {%- set full_string_id = 'report.reporting.' ~ string_id -%}
    
    {%- set query -%}
        select text 
        from {{ source('tamanu', 'translated_strings') }}
        where string_id = '{{ full_string_id }}' 
        and language = '{{ language }}'
    {%- endset -%}
    
    {%- set result = run_query(query) -%}
    
    {%- if execute -%}
        {%- if result.rows | length > 0 -%}
            {{- result.columns[0].values()[0] -}}
        {%- else -%}
            {{- default_column_name -}}
        {%- endif -%}
    {%- endif -%}
{%- endmacro -%}
