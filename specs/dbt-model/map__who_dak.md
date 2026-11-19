# dbt Model Spec: `map__who_dak_<domain>_elements` and `map__who_dak_<domain>_questions`

## Purpose

Carries each WHO DAK domain's element dictionary and question map, which `tupaia-data-product`
generates with the domain's forms and owns (maui-team D12). The question map names the DAK data
element each form question collects, so a `who_dak` model reads an answer's element by joining on
it rather than deriving a question code. The dictionary lists every element the kit defines, so
every mapping can be checked against it.

**Who consumes it?** `int__who_dak_anc_submissions`.

## Identity

| Field | Value |
|---|---|
| **Name** | `map__who_dak_anc_elements`, `map__who_dak_anc_questions` |
| **Type** | dbt model (generated reference data) |
| **Layer** | `map` |
| **Materialisation** | `view` (always) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7199](https://linear.app/bes/issue/MAUI-7199) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-19 |
| **Last updated** | 2026-11-19 |

## Grain

- **Elements:** one row per DAK data element id in the domain's Web Annex A.
- **Questions:** one row per DAK form question and the element it collects, or per option where a
  question collects several elements as its options.

## Inputs

`csv/who_dak/map__who_dak_<domain>_{elements,questions}.csv`, copies of the files of the same
name in `tupaia-data-product` `tamanu/who-dak/<domain>/`. `scripts/generate_who_dak_maps.py`
turns each copy into a model in `models/maps/who_dak/`.

## Output schema

Elements:

| Column | Type | Description | Tests |
|---|---|---|---|
| `element_id` | text | The Annex A data element id | `not_null`, `unique` |
| `label` | text | The element's Annex A label | |
| `data_type` | text | The element's Annex A type | |
| `tab` | text | The Annex A tab of the element's first listing | |

Questions:

| Column | Type | Description | Tests |
|---|---|---|---|
| `survey_id` | text | The survey the question is on, as Tamanu ids it | `not_null` |
| `question_code` | text | The question's program data element code | `not_null` |
| `option` | text | The option that collects the element, or NULL where the answer does | |
| `element_id` | text | The DAK data element the question collects | `not_null`, `relationships` to the elements model |
| `role` | text | A survey-level role the domain's models read, such as `contact`, or NULL | |

`(question_code, option)` is unique.

## Business logic

- **BL-001:** `csv/who_dak/` holds a byte-identical copy of the element dictionary and question
  map of each DAK domain whose models this branch carries.
- **BL-002:** Each copy becomes a view of the same name holding every row of the copy in its
  order, with every column text.
- **BL-003:** A blank cell in a copy reads NULL.
- **BL-004:** The generated models are committed, and CI fails when one differs from what its copy
  generates.
- **BL-005:** Every element a question map names is in the same domain's element dictionary.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Each copy's git blob hash equals that of `tupaia-data-product`'s file for the same domain | BL-001 | recorded check in the PR's Test plan |
| AC-002 | A generated model holds every row of its copy in order, every column cast to text | BL-002 | pytest `test_ac_002_*` in `scripts/tests/test_generate_who_dak_maps.py` |
| AC-003 | A blank cell renders as `null` and a quote is escaped | BL-003 | pytest `test_ac_003_*` |
| AC-004 | A copy with other columns, no rows or another name is refused | BL-002 | pytest `test_ac_004_*` |
| AC-005 | The committed models match what the copies generate | BL-004 | pytest `test_ac_005_*`, and the `checks.yml` drift guard |
| AC-006 | `element_id` is unique and not null in each dictionary | grain | dbt `not_null`, `unique` |
| AC-007 | `(question_code, option)` is unique in each question map, and `survey_id`, `question_code`, `element_id` are not null | grain | `dbt_utils.unique_combination_of_columns`, `not_null` |
| AC-008 | Every question map `element_id` is in its dictionary | BL-005 | dbt `relationships` |

## Lineage

```
tupaia-data-product tamanu/who-dak/<domain>/map__who_dak_<domain>_*.csv
  ──copy──► csv/who_dak/ ──generate_who_dak_maps.py──► map__who_dak_<domain>_* ──► int__who_dak_*
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-19 | Maui team | Initial spec: the ANC element dictionary and question map (MAUI-7199). |
