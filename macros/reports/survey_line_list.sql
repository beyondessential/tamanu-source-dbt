{#
    Generic survey export line list.

    Mirrors Tamanu's built-in "Generic Survey Export - Line List" report over the
    generated survey pivot models in a deployment's models/surveys/. Point it at a survey
    id and it emits the common patient columns followed by one column per answerable
    question, in survey screen and component order.

    Survey ids are deployment-specific, so reports built with this macro live in the
    deployment repo while the macro lives here. To turn a survey into a report, add
    tamanu-dbt-<deployment>/models/reports/sql/<name>-line-list.sql:

        {{ survey_line_list('program-irdmentalh-irdmhfu') }}

    plus a matching models/reports/config/<name>-line-list.json. ref() inside this macro
    resolves against the calling project, so the survey pivot model comes from the
    deployment repo while ds__patients resolves here.

    Arguments:
      survey_id         Tamanu surveys.id, e.g. 'program-irdmentalh-irdmhfu'.
      survey_model      Survey pivot model to read. Defaults to survey_id with hyphens
                        replaced by underscores, which is how the models are generated.
      label_prefix      Translation string-id prefix for question headers. Defaults to
                        'survey' plus the last segment of survey_id, camel cased.
      exclude_codes     Question codes to leave out of the report.
      allow_sensitive   Set true to report on a survey Tamanu marks sensitive. Deployment
                        repos have no standard/sensitive report tree, so the report's own
                        config and its Tamanu permission group are the access controls —
                        restrict it there.
      default_from_date / default_to_date
                        Fallback dates used when the report runs outside the Tamanu UI
                        (a dbt run rather than a compiled report).

    Column headers resolve through translate_label() using a generated string id
    (`<label_prefix><QuestionCode>`, e.g. surveyIrdmhfuMhFormDate). When no translation
    row exists the question's Tamanu name is used verbatim, so a report is readable with
    no translation work and any header can be overridden later by adding a row to the
    deployment's csv/report_translations_<deployment>.csv (or to
    csv/report_translations_standard.csv here, where the label applies to every deployment).

    Known divergences from Tamanu's own report: Autocomplete answers stay as the stored
    reference-data id rather than being resolved to a name, and Date answers keep their
    stored representation rather than being reformatted. Both are properties of
    survey_response_answers.body, which is what the survey pivot models carry. Age is the
    patient's age at death where a date of death is recorded, rather than age today. And
    a sensitive survey can be reported on here (via allow_sensitive) where Tamanu's own
    export refuses outright.

    Note for reviewers: the compile-time introspection below calls source() to read
    survey metadata, so a report built with this macro carries a source dependency. The
    source only ever appears inside a {% set %} query used to shape the column list — it
    is never part of the model's own SQL, which reads the survey pivot model via ref().
    This mirrors how the package's own get_survey() macro works.
#}

{#- Data element types Tamanu excludes from the export. Instruction is already dropped
    by get_survey(), so it never reaches the survey model. -#}
{%- macro survey_line_list_excluded_types() -%}
    {{- return(['Instruction', 'DisplayText', 'Result', 'SurveyLink']) -}}
{%- endmacro -%}


{#- Column names get_survey() reserves. A question whose code collides with one is
    aliased there with an `_answer` suffix, so this list must stay in step with the
    package macro. -#}
{%- macro survey_line_list_reserved_columns() -%}
    {{- return([
        'encounter_id',
        'response_id',
        'patient_id',
        'start_datetime',
        'end_datetime',
        'result_text',
    ]) -}}
{%- endmacro -%}


{%- macro survey_line_list_camelise(text, capitalise_first=false) -%}
    {%- set words = text.replace('-', '_').replace(' ', '_').split('_') | reject('equalto', '') | list -%}
    {%- set ns = namespace(out='') -%}
    {%- for word in words -%}
        {%- if loop.first and not capitalise_first -%}
            {%- set ns.out = word | lower -%}
        {%- else -%}
            {%- set ns.out = ns.out ~ (word | capitalize) -%}
        {%- endif -%}
    {%- endfor -%}
    {{- ns.out -}}
{%- endmacro -%}


{#- Question metadata for a survey, in screen and component order: a list of
    {code, name, type, alias} dicts, where alias is the survey-model column name.
    Empty during `dbt parse`, when there is no warehouse connection to query. -#}
{%- macro survey_line_list_questions(survey_id) -%}
    {%- set reserved = survey_line_list_reserved_columns() -%}
    {%- set query -%}
        select
            replace(pde.code, '-', '_') as code,
            pde.name,
            pde.type
        from {{ source('tamanu', 'survey_screen_components') }} ssc
        join {{ source('tamanu', 'program_data_elements') }} pde
            on ssc.data_element_id = pde.id
        where ssc.survey_id = '{{ survey_id }}'
            and ssc.deleted_at is null
            and pde.deleted_at is null
            and pde.type != 'Instruction'
        order by ssc.screen_index, ssc.component_index
    {%- endset -%}

    {%- set results = dbt_utils.get_query_results_as_dict(query) -%}
    {%- set questions = [] -%}
    {%- set seen = [] -%}

    {%- if results -%}
        {%- for code, name, type in zip(results['code'], results['name'], results['type']) -%}
            {#- get_survey() emits one column per data element, so a repeated code would
                already have broken the survey model. Skip duplicates defensively rather
                than emit an ambiguous column reference. -#}
            {%- if code not in seen -%}
                {%- do seen.append(code) -%}
                {%- do questions.append({
                    'code': code,
                    'name': name,
                    'type': type,
                    'alias': (code ~ '_answer') if code in reserved else code,
                }) -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endif -%}

    {{- return(questions) -}}
{%- endmacro -%}


{#- A column header: the translation for string_id when one exists, else the question's
    Tamanu name. translate_label() falls back to the raw string id, which is not a
    usable header, so the lookup happens here instead. -#}
{%- macro survey_line_list_label(string_id, fallback) -%}
    {%- set translations = get_translations() -%}
    {%- if ('report.reporting.' ~ string_id) in translations or string_id in translations -%}
        {{- translate_label(string_id) -}}
    {%- else -%}
        {{- fallback -}}
    {%- endif -%}
{%- endmacro -%}


{#- Escape a label for use inside a double-quoted Postgres identifier. -#}
{%- macro survey_line_list_quote(label) -%}
    {{- label | trim | replace('"', '""') -}}
{%- endmacro -%}


{#- Confirm the survey exists, and that a survey Tamanu marks sensitive was opted into
    deliberately. Tamanu's own generic export refuses sensitive surveys outright; here it
    is a gate rather than a wall, so a sensitive form can be reported on when that is the
    intent — but never by accident, since is_sensitive is set in Tamanu and can be turned
    on for a survey long after its report was built. -#}
{%- macro survey_line_list_assert_exportable(survey_id, allow_sensitive) -%}
    {%- if execute -%}
        {%- set query -%}
            select is_sensitive
            from {{ source('tamanu', 'surveys') }}
            where id = '{{ survey_id }}'
                and deleted_at is null
        {%- endset -%}
        {%- set results = run_query(query) -%}
        {%- if results | length == 0 -%}
            {{- exceptions.raise_compiler_error(
                "survey_line_list('" ~ survey_id ~ "'): no such survey."
            ) -}}
        {%- elif results.rows[0][0] and not allow_sensitive -%}
            {{- exceptions.raise_compiler_error(
                "survey_line_list('" ~ survey_id ~ "'): survey is marked sensitive in Tamanu. Pass "
                ~ "allow_sensitive=true to report on it, and restrict the report to the appropriate "
                ~ "permission group in Tamanu."
            ) -}}
        {%- endif -%}
    {%- endif -%}
{%- endmacro -%}


{%- macro survey_line_list(
    survey_id,
    survey_model=none,
    label_prefix=none,
    exclude_codes=[],
    allow_sensitive=false,
    default_from_date='2024-01-01',
    default_to_date='2024-01-31'
) -%}

{%- do survey_line_list_assert_exportable(survey_id, allow_sensitive) -%}

{%- set model = survey_model or survey_id | replace('-', '_') -%}
{%- set prefix = label_prefix or ('survey' ~ survey_line_list_camelise(survey_id.split('-') | last, capitalise_first=true)) -%}
{%- set questions = survey_line_list_questions(survey_id) -%}
{%- set answerable = questions
    | rejectattr('type', 'in', survey_line_list_excluded_types())
    | rejectattr('code', 'in', exclude_codes)
    | list -%}
{%- set has_result = questions | selectattr('type', 'equalto', 'Result') | list | length > 0 -%}

{%- if execute and answerable | length == 0 -%}
    {{- exceptions.raise_compiler_error(
        "survey_line_list('" ~ survey_id ~ "') found no answerable questions. Check the survey id "
        ~ "and that survey_screen_components rows exist for it."
    ) -}}
{%- endif -%}

{#- Resolve every header up front so over-long ones can be reported together. -#}
{%- set columns = [] -%}
{%- set overlong = [] -%}
{%- for question in answerable -%}
    {%- set label = survey_line_list_label(
        prefix ~ survey_line_list_camelise(question.code, capitalise_first=true),
        question.name
    ) | trim -%}
    {%- do columns.append({'alias': question.alias, 'type': question.type, 'label': label}) -%}
    {%- if label | length > 63 -%}
        {%- do overlong.append(question.code) -%}
    {%- endif -%}
{%- endfor -%}

{#- A column alias is a Postgres identifier, so anything past 63 bytes is silently
    truncated in the exported header. Naming the questions here is the only signal the
    author gets; the fix is a shorter label in the deployment's translations CSV. -#}
{%- if execute and overlong | length > 0 -%}
    {{- exceptions.warn(
        "survey_line_list('" ~ survey_id ~ "'): " ~ (overlong | length) ~ " column header(s) exceed "
        ~ "the 63-byte Postgres identifier limit and will be truncated in the export. Add a shorter "
        ~ "label for: " ~ (overlong | join(', '))
    ) -}}
{%- endif -%}

select
    p.display_id as "{{ translate_label('patientDisplayId') }}",
    p.first_name as "{{ translate_label('patientFirstName') }}",
    p.last_name as "{{ translate_label('patientLastName') }}",
    to_char(p.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    p.age as "{{ translate_label('patientAge') }}",
    p.sex as "{{ translate_label('patientSex') }}",
    p.village as "{{ translate_label('patientVillage') }}",
    to_char(
        {{ to_user_selected_timezone('s.end_datetime') }},
        '{{ var("datetime_without_seconds_format") }}'
    ) as "{{ translate_label('surveySubmissionTime') }}"
{%- for column in columns %}
    {%- if column.type == 'Signature' %},
    case
        when s."{{ column.alias }}" is not null then '{{ translate_label('surveySignatureSigned') }}'
        else '{{ translate_label('surveySignatureUnsigned') }}'
    end as "{{ survey_line_list_quote(column.label) }}"
    {%- else %},
    s."{{ column.alias }}" as "{{ survey_line_list_quote(column.label) }}"
    {%- endif %}
{%- endfor %}
{%- if has_result %},
    s.result_text as "{{ translate_label('surveyResult') }}"
{%- endif %}
from {{ ref(model) }} s
join {{ ref('ds__patients') }} p on p.patient_id = s.patient_id
where
    case
        when {{ parameter('fromDate', default_value=default_from_date, data_type='date') }} is null then true
        else {{ to_user_selected_timezone('s.end_datetime') }}::date
            >= {{ parameter('fromDate', default_value=default_from_date, data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value=default_to_date, data_type='date') }} is null then true
        else {{ to_user_selected_timezone('s.end_datetime') }}::date
            <= {{ parameter('toDate', default_value=default_to_date, data_type='date') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else p.village_id = {{ parameter('villageId') }}
    end
order by s.end_datetime desc
{%- endmacro -%}
