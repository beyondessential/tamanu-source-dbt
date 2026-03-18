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

with price_pivot as (
    select
        invoice_product_id
        {%- for row in price_lists %}
        , max(case when invoice_price_list_id = '{{ row[0] }}' then price end)
            as price_{{ loop.index }}
        {%- endfor %}
    from {{ ref('invoice_price_list_items') }}
    where is_hidden = false
    group by invoice_product_id
),

insurance_pivot as (
    select
        invoice_product_id
        {%- for row in insurance_plans %}
        , max(case when invoice_insurance_plan_id = '{{ row[0] }}' then coverage_value end)
            as cov_{{ loop.index }}
        {%- endfor %}
    from {{ ref('invoice_insurance_plan_items') }}
    group by invoice_product_id
)

select
    ip.id,
    ip.name,
    ip.insurable,
    ip.category,
    ip.source_record_id,
    ip.visibility_status
    {%- for row in price_lists %}
    , pp.price_{{ loop.index }} as "Price: {{ row[1] }}"
    {%- endfor %}
    {%- for row in insurance_plans %}
    , case
        when ip.insurable = false then 'n/a'
        else cast(
            coalesce(
                insurp.cov_{{ loop.index }},
                {%- if row[2] is not none %}{{ row[2] }}{%- else %}null{%- endif %}
            ) as text
        )
    end as "Insurance: {{ row[1] }}"
    {%- endfor %}
from {{ ref('invoice_products') }} ip
left join price_pivot pp on pp.invoice_product_id = ip.id
left join insurance_pivot insurp on insurp.invoice_product_id = ip.id
