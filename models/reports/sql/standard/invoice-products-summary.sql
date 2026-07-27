{%- set price_lists_query %}
    select name
    from {{ ref('invoice_price_lists') }}
    where visibility_status = 'current'
    order by name
{%- endset %}

{%- set insurance_plans_query %}
    select name
    from {{ ref('invoice_insurance_plans') }}
    where visibility_status = 'current'
    order by name
{%- endset %}

{%- if execute %}
    {%- set price_list_names = run_query(price_lists_query).columns[0].values() %}
    {%- set insurance_plan_names = run_query(insurance_plans_query).columns[0].values() %}
{%- else %}
    {%- set price_list_names = [] %}
    {%- set insurance_plan_names = [] %}
{%- endif %}

select
    id as "{{ translate_label('invoiceProductId') }}",
    name as "{{ translate_label('invoiceProductName') }}",
    insurable as "{{ translate_label('invoiceProductInsurable') }}",
    category as "{{ translate_label('invoiceProductCategory') }}",
    source_record_id as "{{ translate_label('invoiceProductCategoryId') }}",
    available_facilities as "{{ translate_label('invoiceProductAvailableFacilities') }}",
    visibility_status as "{{ translate_label('invoiceProductVisibilityStatus') }}",
    external_code as "{{ translate_label('invoiceProductLabExternalCode') }}"
    {%- for name in price_list_names %}
    , "Price: {{ name }}"
    {%- endfor %}
    {%- for name in insurance_plan_names %}
    , "Insurance: {{ name }}"
    {%- endfor %}
    {%- for name in price_list_names %}
    , "Price List Charging: {{ name }}"
        as "{{ translate_label('invoiceProductPriceListCharging') }}: {{ name }}"
    {%- endfor %}
from {{ ref('ds__invoice_products') }}
order by name
