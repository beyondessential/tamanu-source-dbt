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
    ip.id,
    ip.name,
    ip.insurable,
    ip.category,
    ip.source_record_id,
    ip.visibility_status
    {%- for row in price_lists %}
    , max(case when ipli.invoice_price_list_id = '{{ row[0] }}' then ipli.price end)
        as "Price: {{ row[1] }}"
    {%- endfor %}
    {%- for row in insurance_plans %}
    , case
        when ip.insurable = false then 'n/a'
        else cast(
            coalesce(
                max(case when iipi.invoice_insurance_plan_id = '{{ row[0] }}' then iipi.coverage_value end),
                {%- if row[2] is not none %}{{ row[2] }}{%- else %}null{%- endif %}
            ) as text
        )
    end as "Insurance: {{ row[1] }}"
    {%- endfor %}
from {{ ref('invoice_products') }} ip
left join {{ ref('invoice_price_list_items') }} ipli
    on ipli.invoice_product_id = ip.id
    and ipli.is_hidden = false
left join {{ ref('invoice_insurance_plan_items') }} iipi
    on iipi.invoice_product_id = ip.id
group by
    ip.id,
    ip.name,
    ip.insurable,
    ip.category,
    ip.source_record_id,
    ip.visibility_status
