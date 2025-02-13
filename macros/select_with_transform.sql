{%- macro select_with_transform(from, except, update, select=None) -%}
    {%- set columns = select if select else adapter.get_columns_in_relation(ref(from)) | map(attribute="name") | list -%}
    {%- set filtered_columns = columns | reject( "in", except) | list -%}
    {%- set date_format = var('date_format') -%}
    {%- set updated_columns = [] -%}
    {%- for col_name in filtered_columns %}
        {%- if col_name in update %}
            {%- set column_type = update[col_name] %}
            {%- if column_type == 'date' %}
                {%- do updated_columns.append('to_char("' + col_name + '", \'' + date_format + '\') as "' + col_name + '"') %}
            {%- elif column_type == 'number' %}
                {%- do updated_columns.append('"col_name"::number as "' + col_name + '"') %}
            {%- elif column_type == 'text' %}
                {%- do updated_columns.append('"col_name"::text as "' + col_name + '"') %}
            {%- else %}
                {%- do updated_columns.append('"' + col_name + '"') %}
            {%- endif %}
        {%- else %}
            {%- do updated_columns.append('"' + col_name + '"') %}
        {%- endif %}
    {%- endfor %}   
    {{ updated_columns | join(',\n') }}
{%- endmacro -%}
