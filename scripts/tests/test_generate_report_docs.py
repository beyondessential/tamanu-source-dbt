import json

from generate_report_docs import (
    build_catalogue,
    categorise,
    describe_filter,
    extract_columns,
    render_html,
    resolve_alias,
    resolve_label,
)

TRANSLATIONS = {
    "report.reporting.facility": "Facility",
    "report.reporting.dischargeAssignedTime": "Time assigned to",
    "report.reporting.dischargeDepartment": "Discharging department",
    "bareId": "Bare label",
}


# ---------------------------------------------------------------------------
# resolve_label — mirrors the lookup order of the translate_label macro
# ---------------------------------------------------------------------------


def test_resolve_label_prefers_the_report_reporting_prefix():
    assert resolve_label("facility", TRANSLATIONS) == "Facility"


def test_resolve_label_falls_back_to_the_bare_string_id():
    assert resolve_label("bareId", TRANSLATIONS) == "Bare label"


def test_resolve_label_falls_back_to_the_key_itself():
    assert resolve_label("noSuchLabel", TRANSLATIONS) == "noSuchLabel"


# ---------------------------------------------------------------------------
# resolve_alias — a header may combine several labels
# ---------------------------------------------------------------------------


def test_resolve_alias_joins_multiple_labels_in_one_header():
    alias = "{{ translate_label('dischargeAssignedTime') }} {{ translate_label('dischargeDepartment') }}"
    assert resolve_alias(alias, TRANSLATIONS) == "Time assigned to Discharging department"


def test_resolve_alias_normalises_whitespace():
    alias = "{{ translate_label('facility') }}   \n  {{ translate_label('bareId') }}"
    assert resolve_alias(alias, TRANSLATIONS) == "Facility Bare label"


# ---------------------------------------------------------------------------
# extract_columns — order, CTE isolation, dynamic headers
# ---------------------------------------------------------------------------


def test_extract_columns_keeps_select_order():
    sql = """
        select
            a as "{{ translate_label('bareId') }}",
            b as "{{ translate_label('facility') }}"
        from x
    """
    columns, dynamic = extract_columns(sql, TRANSLATIONS)
    assert columns == ["Bare label", "Facility"]
    assert dynamic is False


def test_extract_columns_ignores_bare_cte_aliases():
    sql = """
        with counts as (
            select count(*) as admissions, sum(x) as total from y
        )
        select admissions as "{{ translate_label('facility') }}" from counts
    """
    columns, _ = extract_columns(sql, TRANSLATIONS)
    assert columns == ["Facility"]


def test_extract_columns_excludes_headers_built_from_reference_data():
    # invoice-products-summary emits one column per configured price list; those
    # headers are not fixed, so they are flagged rather than documented.
    sql = """
        select
            a as "{{ translate_label('facility') }}"
            {%- for name in price_list_names %}
            , b as "{{ translate_label('bareId') }}: {{ name }}"
            {%- endfor %}
        from x
    """
    columns, dynamic = extract_columns(sql, TRANSLATIONS)
    assert columns == ["Facility"]
    assert dynamic is True


# ---------------------------------------------------------------------------
# categorise / describe_filter
# ---------------------------------------------------------------------------


def test_categorise_puts_audit_reports_before_the_line_list_rule():
    assert categorise("audit-discharge-line-list", "Audit discharge line list") == (
        "Audit and data quality"
    )


def test_categorise_recognises_line_lists_and_summaries():
    assert categorise("admissions-line-list", "Admissions line list") == "Line lists"
    assert categorise("lab-requests-summary", "Lab requests summary") == "Summaries"


def test_describe_filter_notes_the_facility_restriction():
    described = describe_filter(
        {
            "parameterField": "FacilityField",
            "label": "Facility",
            "filterBySelectedFacility": True,
        }
    )
    assert described["label"] == "Facility"
    assert "logged in to" in described["behaviour"]


def test_describe_filter_carries_fixed_options():
    described = describe_filter(
        {
            "parameterField": "ParameterMultiselectField",
            "label": "Admission status",
            "options": [{"label": "Active"}, {"label": "Discharged"}],
        }
    )
    assert described["options"] == ["Active", "Discharged"]


def test_describe_filter_falls_back_for_an_unknown_field_type():
    described = describe_filter({"parameterField": "SomeNewField", "label": "New"})
    assert described["behaviour"] == "Select a value"


# ---------------------------------------------------------------------------
# End to end, against the report definitions actually in the repository
# ---------------------------------------------------------------------------


def test_every_standard_report_resolves_to_named_columns():
    catalogue = build_catalogue()
    assert catalogue["report_count"] > 0
    for report in catalogue["reports"]:
        assert report["columns"], f"{report['id']} resolved no columns"
        # An unresolved label leaks the camelCase string ID into the header.
        for column in report["columns"]:
            assert column == column.strip()
            assert not column.endswith(":"), f"{report['id']}: dangling '{column}'"


def test_render_html_embeds_parseable_data_and_closes_no_tags_early():
    catalogue = build_catalogue()
    html = render_html(catalogue)
    assert "__CATALOGUE_DATA__" not in html
    payload = html.split('type="application/json">')[1].split("</script>")[0]
    assert json.loads(payload)["report_count"] == catalogue["report_count"]
