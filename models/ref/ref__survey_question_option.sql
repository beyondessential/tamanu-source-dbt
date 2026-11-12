-- ref__survey_question_option -- one row per survey question per answer option,
-- resolved as the Tamanu app resolves them (mapOptionsToValues).
-- See specs/dbt-model/ref__survey_question_option.md for the BL clauses this model implements.

with questions as (
    select
        ssc.id as survey_screen_component_id,
        ssc.survey_id,
        ssc.visibility_status as question_visibility_status,
        pde.id as data_element_id,
        pde.code as data_element_code,
        pde.name as data_element_name,
        pde.type as question_type,
        -- BL-005: the question's own text, else the data element's default text
        coalesce(nullif(ssc.text, ''), pde.default_text) as question_text,
        -- BL-002: the question's own options when non-empty, else the data element's
        case
            when ssc.options <> '' then 'question'
            else 'data_element'
        end as options_source,
        case
            when ssc.options <> '' then ssc.options
            else pde.default_options
        end as options_text
    from {{ ref('survey_screen_components') }} ssc
    inner join {{ ref('program_data_elements') }} pde
        on pde.id = ssc.data_element_id
),

parsed as (
    select
        survey_screen_component_id,
        -- BL-007: only text opening with [ or { is cast, so other text cannot fail the view
        case
            when options_text ~ '^\s*[\[{]' then options_text::json
        end as options_json
    from questions
),

-- BL-003: an array gives its elements, keyed by array index
array_options as (
    select
        p.survey_screen_component_id,
        true as is_index_key,
        e.ordinality - 1 as key_index,
        e.ordinality as written_position,
        e.option_label
    from parsed p
    cross join lateral json_array_elements_text(
        case when json_typeof(p.options_json) = 'array' then p.options_json end
    ) with ordinality e (option_label, ordinality)
),

-- BL-003: an object gives its values, never its keys
object_entries as (
    select
        p.survey_screen_component_id,
        -- the case guards the cast, as Postgres does not short-circuit `and`
        case
            when e.key ~ '^(0|[1-9][0-9]{0,9})$' then e.key::bigint
        end as numeric_key,
        e.ordinality as written_position,
        e.option_label
    from parsed p
    cross join lateral json_each_text(
        case when json_typeof(p.options_json) = 'object' then p.options_json end
    ) with ordinality e (key, option_label, ordinality)
),

object_options as (
    select
        survey_screen_component_id,
        -- BL-004: JavaScript array-index keys run from 0 to 2^32 - 2
        coalesce(numeric_key <= 4294967294, false) as is_index_key,
        numeric_key as key_index,
        written_position,
        option_label
    from object_entries
),

options as (
    select * from array_options
    union all
    select * from object_options
),

-- BL-006: a JSON null element or value is not an option, and takes no position
non_null_options as (
    select *
    from options
    where option_label is not null
)

select
    s.id as survey_id,
    s.code as survey_code,
    s.name as survey_name,
    s.survey_type,
    s.program_id,
    s.visibility_status as survey_visibility_status,
    q.survey_screen_component_id,
    q.question_visibility_status,
    q.data_element_id,
    q.data_element_code,
    q.data_element_name,
    q.question_text,
    q.question_type,
    q.options_source,
    -- BL-004: Object.values order, array-index keys ascending then the rest as written
    row_number() over (
        partition by q.survey_screen_component_id
        order by
            case when o.is_index_key then 0 else 1 end asc,
            case when o.is_index_key then o.key_index end asc,
            o.written_position asc
    )::integer as option_index,
    o.option_label
from questions q
inner join non_null_options o on o.survey_screen_component_id = q.survey_screen_component_id
-- BL-001: historical surveys and questions are kept, with their visibility statuses
inner join {{ ref('surveys') }} s on s.id = q.survey_id
