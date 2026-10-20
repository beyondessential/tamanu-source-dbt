{%- set price_lists_query %}
    select id, name
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
    {%- set price_lists = run_query(price_lists_query) %}
    {%- set insurance_plan_names = run_query(insurance_plans_query).columns[0].values() %}
{%- else %}
    {%- set price_lists = [] %}
    {%- set insurance_plan_names = [] %}
{%- endif %}

with claimed_facilities as (
    -- Facilities explicitly named by a current price list
    select distinct rules ->> 'facilityId' as facility_id
    from {{ ref('invoice_price_lists') }}
    where visibility_status = 'current'
        and (rules ->> 'facilityId') is not null
),

applicable_price_lists as (
    -- Price lists that apply to the selected facility, mirroring
    -- matchesFacilityWithExclusionaryLogic: a list naming the facility matches it,
    -- and a list with no facility matches unless another list names the facility.
    -- No facility selected means every price list applies.
    select ipl.id
    from {{ ref('invoice_price_lists') }} ipl
    where ipl.visibility_status = 'current'
        and case
            when {{ parameter('facilityId') }} is null then true
            when (ipl.rules ->> 'facilityId') is not null
                then (ipl.rules ->> 'facilityId') = {{ parameter('facilityId') }}
            else not exists (
                select 1
                from claimed_facilities cf
                where cf.facility_id = {{ parameter('facilityId') }}
            )
        end
)

select
    id as "{{ translate_label('invoiceProductId') }}",
    name as "{{ translate_label('invoiceProductName') }}",
    insurable as "{{ translate_label('invoiceProductInsurable') }}",
    category as "{{ translate_label('invoiceProductCategory') }}",
    source_record_id as "{{ translate_label('invoiceProductCategoryId') }}",
    available_facilities as "{{ translate_label('invoiceProductAvailableFacilities') }}",
    visibility_status as "{{ translate_label('invoiceProductVisibilityStatus') }}",
    external_code as "{{ translate_label('invoiceProductLabExternalCode') }}"
    {%- for row in price_lists %}
        ,
        case
            when '{{ row[0] }}' in (select id from applicable_price_lists)
                then "Price: {{ row[1] }}"
        end as "Price: {{ row[1] }}"
    {%- endfor %}
    {%- for name in insurance_plan_names %}
        ,
        "Insurance: {{ name }}"
    {%- endfor %}
    {%- for row in price_lists %}
        ,
        case
            when '{{ row[0] }}' in (select id from applicable_price_lists)
                then "Price List Charging: {{ row[1] }}"
        end as "{{ translate_label('invoiceProductPriceListCharging') }}: {{ row[1] }}"
    {%- endfor %}
from {{ ref('ds__invoice_products') }}
where case
    when {{ parameter('facilityId') }} is null then true
    when available_facility_ids is null then true
    when jsonb_array_length(available_facility_ids) = 0 then true
    else exists (
        select 1
        from jsonb_array_elements_text(available_facility_ids) as fid
        where fid = {{ parameter('facilityId') }}
    )
end
order by name
