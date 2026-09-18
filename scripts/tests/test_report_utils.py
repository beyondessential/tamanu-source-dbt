import pytest


# ---------------------------------------------------------------------------
# generate_reporting_schema_script -- the stamp it leaves on the schema
# ---------------------------------------------------------------------------


def test_the_script_stamps_the_version_on_the_schema(monkeypatch, tmp_path):
    # A server says which reporting schema it runs by reading this comment, so
    # a schema built without it cannot be told apart from any other build.
    import json

    import utils.report_utils as report_utils

    target = tmp_path / "target"
    target.mkdir()
    (target / "manifest.json").write_text(
        json.dumps(
            {
                "nodes": {
                    "model.tamanu.patients": {
                        "name": "patients",
                        "tags": [],
                        "depends_on": {"nodes": []},
                        "compiled_path": "compiled/patients.sql",
                        "database": "tamanu",
                        "config": {},
                    }
                }
            }
        ),
        encoding="utf-8",
    )
    compiled = tmp_path / "compiled"
    compiled.mkdir()
    (compiled / "patients.sql").write_text("select 1", encoding="utf-8")

    out = tmp_path / "out"
    monkeypatch.setattr(report_utils, "BASE_DIR", str(tmp_path))
    monkeypatch.setattr(report_utils, "VERSION_DIR", str(out))
    monkeypatch.setattr(report_utils, "VERSION", "2.60.2")
    monkeypatch.setattr(report_utils, "DEPLOYMENT", "kamaka")
    monkeypatch.setattr(report_utils, "get_dbt_project_vars", lambda: {})

    report_utils.generate_reporting_schema_script()

    script = (out / "reporting-schema-v2.60.2-kamaka.sql").read_text(encoding="utf-8")
    assert "comment on schema reporting is '2.60.2';" in script


def test_a_manifest_with_nothing_to_build_fails(monkeypatch, tmp_path):
    import json

    import utils.report_utils as report_utils

    target = tmp_path / "target"
    target.mkdir()
    (target / "manifest.json").write_text(json.dumps({"nodes": {}}), encoding="utf-8")
    monkeypatch.setattr(report_utils, "BASE_DIR", str(tmp_path))
    monkeypatch.setattr(report_utils, "get_dbt_project_vars", lambda: {})

    with pytest.raises(RuntimeError, match="No models found"):
        report_utils.generate_reporting_schema_script()
