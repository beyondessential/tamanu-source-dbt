# dbt Model Spec: `ref__survey_question_option`

## Purpose

Lists the answer options of every Tamanu survey question, one row per option, resolved
the way the Tamanu app resolves them. Dashboards and reports that group survey answers
(hypertension status, diabetic status and so on) depend on these options matching their
category mappings. Tamanu holds them only as raw JSON text, so a new option goes
unnoticed until a visual shows a wrong or missing category. This model gives a list
that can be checked against those mappings.

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__survey_question_option` |
| **Type** | dbt model |
| **Layer** | `ref` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear** | [MAUI-7109](https://linear.app/bes/issue/MAUI-7109) |
| **Created** | 2026-11-12 |
| **Last updated** | 2026-11-12 |

**Definition source.** `mapOptionsToValues(componentOptions || defaultOptions)` in
`@tamanu/ui-components` (`utils/survey.jsx`) and the mobile `SurveyQuestion`, and the
question label `component.text || dataElement.defaultText` in the same components.

## Grain

**One row per:** survey screen component × answer option. A question whose resolved
options yield no label has no rows.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `survey_id` | text | The survey the question sits on |
| `survey_code` | text | |
| `survey_name` | text | |
| `survey_type` | text | |
| `program_id` | text | |
| `survey_visibility_status` | text | |
| `survey_screen_component_id` | text | The question on this survey |
| `question_visibility_status` | text | |
| `data_element_id` | text | Answers to the question are stored against this id |
| `data_element_code` | text | |
| `data_element_name` | text | |
| `question_text` | text | BL-005 |
| `question_type` | text | The data element's type |
| `options_source` | text | `question` or `data_element` (BL-002) |
| `option_index` | integer | 1-based position in the app's order (BL-004) |
| `option_label` | text | The option as shown, and as stored in `survey_response_answers.body` |

## Business logic

- **BL-001:** Source only from the `surveys`, `survey_screen_components` and
  `program_data_elements` base models, and keep questions whose survey or question is
  historical, exposing both visibility statuses as columns.
- **BL-002:** A question's own `options` are used when they are a non-empty string,
  otherwise its data element's `default_options`, and `options_source` records which.
- **BL-003:** The chosen text yields options only when it is a JSON array or JSON
  object: an array gives its elements and an object gives its values, never its keys.
- **BL-004:** Options are ordered as JavaScript's `Object.values` orders them, with
  array-index keys first in ascending numeric order and then every other key in the
  order written, and an array's elements in array order.
- **BL-005:** `question_text` is the question's own `text` when non-empty, otherwise
  the data element's `default_text`.
- **BL-006:** A JSON `null` element or value yields no option.
- **BL-007:** Only text whose first non-blank character is `[` or `{` is parsed as
  JSON, so other text yields no options rather than failing the view.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `survey_screen_component_id`, `option_index` and `option_label` are never null | grain | dbt `not_null` |
| AC-002 | (`survey_screen_component_id`, `option_index`) is unique | grain | `dbt_utils.unique_combination_of_columns` |
| AC-003 | A data element's JSON array of options yields one row per element in array order, with `options_source` = `data_element` | BL-002, BL-003, BL-004 | unit `test_ref__survey_question_option_array_default_options` |
| AC-004 | A question's own options override its data element's, and an empty-string question `options` falls back to the data element's | BL-002 | unit `test_ref__survey_question_option_question_options_override` and `test_ref__survey_question_option_array_default_options` |
| AC-005 | A JSON object yields its values, with array-index keys first in numeric order and other keys in written order | BL-003, BL-004 | unit `test_ref__survey_question_option_object_options` |
| AC-006 | Comma-separated text, a JSON scalar, an empty value and a JSON `null` element yield no rows | BL-003, BL-006, BL-007 | unit `test_ref__survey_question_option_unparseable_options` |
| AC-007 | `question_text` falls back to the data element's `default_text` when the question's `text` is empty | BL-005 | unit `test_ref__survey_question_option_array_default_options` |
| AC-008 | Historical surveys and questions are kept, with their visibility statuses carried through | BL-001 | unit `test_ref__survey_question_option_question_options_override` |

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `surveys` | `bases/` | Survey code, name, type, program and visibility |
| `survey_screen_components` | `bases/` | The question on the survey, its own options and text |
| `program_data_elements` | `bases/` | Default options, default text, code, name and type |

## Risks

- The Tamanu importer accepts `program_data_elements.default_options` and
  `survey_screen_components.options` text that is not JSON, such as comma-separated
  values, but the form parses JSON only and shows no options for such a question, so the
  model lists none.
- Postgres 12 cannot cast text to JSON without raising on malformed input. A malformed
  value that starts with `[` or `{` fails the whole view.
- An object with a repeated key yields one row per occurrence, where the app keeps only
  the last.

## Change log

| Date | Change |
|---|---|
| 2026-11-12 | Created (MAUI-7109) |
