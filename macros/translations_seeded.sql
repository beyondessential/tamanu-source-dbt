{%- macro _seed_get_relation_if_exists(identifier) -%}
    {%- set rel = adapter.get_relation(database=target.database, schema=target.schema, identifier=identifier) -%}
    {{ return(rel) }}
{%- endmacro -%}

{%- macro _seed_translation_query_from_seeds(full_string_id) -%}
    {%- set standard_seed = var('standard_translations_seed_name', 'report_translations_standard') -%}
    {%- set localised_seed = var('local_translations_seed_name', 'report_translations_localised') -%}
    {%- set std_rel = _seed_get_relation_if_exists(standard_seed) -%}
    {%- set loc_rel = _seed_get_relation_if_exists(localised_seed) -%}

    {%- set parts = [] -%}
    {%- if loc_rel -%}
        {%- do parts.append("select \"default\" as text from " ~ loc_rel ~ " where \"stringId\" = '" ~ full_string_id ~ "'") -%}
    {%- endif -%}
    {%- if std_rel -%}
        {%- do parts.append("select \"default\" as text from " ~ std_rel ~ " where \"stringId\" = '" ~ full_string_id ~ "'") -%}
    {%- endif -%}

    {%- if not parts -%}
        {{ return("select null as text") }}
    {%- endif -%}

    {{ return(parts | join('\nunion all\n')) }}
{%- endmacro -%}

{%- macro translate_label_from_seed(string_id) -%}
    {%- set prefix = var('translation_prefix', 'report.reporting') -%}
    {%- set full_string_id = prefix ~ '.' ~ string_id -%}
    {%- set query = _seed_translation_query_from_seeds(full_string_id) -%}
    {%- set result = run_query(query) -%}
    {%- if execute -%}
        {%- if result.rows | length > 0 and result.columns[0].values()[0] is not none -%}
            {{- result.columns[0].values()[0] -}}
        {%- else -%}
            {{- string_id -}}
        {%- endif -%}
    {%- endif -%}
{%- endmacro -%}

