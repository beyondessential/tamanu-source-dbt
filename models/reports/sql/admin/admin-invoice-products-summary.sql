{%- set price_lists_query %}
    select id, name
    from {{ ref('invoice_price_lists') }}
    order by name
{%- endset %}

{%- set insurance_plans_query %}
    select id, name, default_coverage
    from {{ ref('invoice_insurance_plans') }}
    order by name
{%- endset %}

{%- if execute %}
    {%- set price_lists = run_query(price_lists_query) %}
    {%- set insurance_plans = run_query(insurance_plans_query) %}
{%- else %}
    {%- set price_lists = [] %}
    {%- set insurance_plans = [] %}
{%- endif %}

select
    id as "{{ translate_label('invoiceProductId') }}",
    name as "{{ translate_label('invoiceProductName') }}",
    insurable as "{{ translate_label('invoiceProductInsurable') }}",
    category as "{{ translate_label('invoiceProductCategory') }}",
    source_record_id as "{{ translate_label('invoiceProductCategoryId') }}",
    visibility_status as "{{ translate_label('invoiceProductVisibilityStatus') }}"
    {%- for row in price_lists %}
    , max(case when invoice_price_list_id = '{{ row[0] }}' then price end) as "Price: {{ row[1] }}"
    {%- endfor %}
    {%- for row in insurance_plans %}
    , case
        when insurable = false then 'n/a'
        else cast(
            coalesce(
                max(case when invoice_insurance_plan_id = '{{ row[0] }}' then coverage_value end),
                {%- if row[2] is not none %}{{ row[2] }}{%- else %}null{%- endif %}
            ) as text
        )
    end as "Insurance: {{ row[1] }}"
    {%- endfor %}
from {{ ref('ds__invoice_products') }}
group by
    id,
    name,
    insurable,
    category,
    source_record_id,
    visibility_status
order by name
