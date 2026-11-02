import pytest

from utils.report_utils import (
    ReportingSchemaDependencyError,
    effective_dependencies,
    order_models_for_schema,
    reporting_schema_nodes,
)


def _node(name, deps=(), tags=(), materialized="view"):
    """Build the slice of a manifest node the ordering reads."""
    return {
        "name": name,
        "tags": list(tags),
        "depends_on": {"nodes": list(deps)},
        "config": {"materialized": materialized},
    }


# ---------------------------------------------------------------------------
# order_models_for_schema -- ordering
# ---------------------------------------------------------------------------


def test_dependencies_are_ordered_before_their_dependents():
    a, b, c = "model.p.a", "model.p.b", "model.p.c"
    manifest = {"nodes": {c: _node("c", [b]), a: _node("a"), b: _node("b", [a])}}

    assert order_models_for_schema(manifest, [c, a, b]) == [a, b, c]


def test_source_dependencies_do_not_block_ordering():
    model = "model.p.base__patients"
    manifest = {"nodes": {model: _node("base__patients", ["source.p.tamanu.patients"])}}

    assert order_models_for_schema(manifest, [model]) == [model]


# ---------------------------------------------------------------------------
# order_models_for_schema -- dependencies the reporting schema never creates
# ---------------------------------------------------------------------------


def test_seed_dependency_names_the_seed_and_points_at_map():
    model, seed = "model.p.int__treatment", "seed.p.treatment_medications"
    manifest = {
        "nodes": {model: _node("int__treatment", [seed]), seed: _node("treatment_medications")}
    }

    with pytest.raises(ReportingSchemaDependencyError) as excinfo:
        order_models_for_schema(manifest, [model])

    message = str(excinfo.value)
    assert "int__treatment" in message
    assert seed in message
    assert "map__" in message


def test_excluded_model_dependency_names_the_tag_that_excludes_it():
    model, registry = "model.p.dataset__x", "model.p.metric_definitions"
    manifest = {
        "nodes": {
            model: _node("dataset__x", [registry]),
            registry: _node("metric_definitions", tags=["internal"]),
        }
    }

    with pytest.raises(ReportingSchemaDependencyError) as excinfo:
        order_models_for_schema(manifest, [model])

    assert '"internal"' in str(excinfo.value)


def test_restricted_dependency_names_the_var_that_excludes_it():
    model, sensitive = "model.p.dataset__x", "model.p.dataset__sensitive"
    manifest = {
        "nodes": {
            model: _node("dataset__x", [sensitive]),
            sensitive: _node("dataset__sensitive", tags=["restricted"]),
        }
    }

    with pytest.raises(ReportingSchemaDependencyError) as excinfo:
        order_models_for_schema(manifest, [model])

    assert "has_sensitive_facility" in str(excinfo.value)


def test_models_waiting_on_a_blocked_model_are_listed_separately():
    seed = "seed.p.meds"
    upstream, downstream = "model.p.int__treatment", "model.p.metric__screening"
    manifest = {
        "nodes": {
            upstream: _node("int__treatment", [seed]),
            downstream: _node("metric__screening", [upstream]),
            seed: _node("meds"),
        }
    }

    with pytest.raises(ReportingSchemaDependencyError) as excinfo:
        order_models_for_schema(manifest, [upstream, downstream])

    assert "Blocked behind them: metric__screening" in str(excinfo.value)


# ---------------------------------------------------------------------------
# order_models_for_schema -- genuine cycles
# ---------------------------------------------------------------------------


def test_cycle_is_reported_as_a_cycle_and_names_the_models():
    a, b = "model.p.a", "model.p.b"
    manifest = {"nodes": {a: _node("a", [b]), b: _node("b", [a])}}

    with pytest.raises(ReportingSchemaDependencyError) as excinfo:
        order_models_for_schema(manifest, [a, b])

    message = str(excinfo.value)
    assert "Circular dependency" in message
    assert "a, b" in message


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


# ---------------------------------------------------------------------------
# reporting_schema_nodes -- which models get a view
# ---------------------------------------------------------------------------


def _manifest(**nodes):
    return {"nodes": {f"model.p.{name}": node for name, node in nodes.items()}}


def _ids(*names):
    return [f"model.p.{name}" for name in names]


def test_an_ephemeral_model_gets_no_view():
    manifest = _manifest(
        base=_node("base"),
        shared=_node("shared", _ids("base"), materialized="ephemeral"),
        dataset=_node("dataset", _ids("shared")),
    )

    assert reporting_schema_nodes(manifest, False) == _ids("base", "dataset")


def test_a_view_reading_through_an_ephemeral_model_follows_what_it_reads():
    manifest = _manifest(
        base=_node("base"),
        shared=_node("shared", _ids("base"), materialized="ephemeral"),
        dataset=_node("dataset", _ids("shared")),
    )
    nodes = reporting_schema_nodes(manifest, False)

    assert order_models_for_schema(manifest, list(reversed(nodes))) == _ids("base", "dataset")


def test_ephemeral_models_are_resolved_through_a_chain():
    manifest = _manifest(
        base=_node("base"),
        inner=_node("inner", _ids("base"), materialized="ephemeral"),
        outer=_node("outer", _ids("inner"), materialized="ephemeral"),
        dataset=_node("dataset", _ids("outer")),
    )

    assert effective_dependencies(manifest, "model.p.dataset") == _ids("base")


def test_a_dependency_reached_twice_through_ephemeral_models_is_listed_once():
    manifest = _manifest(
        base=_node("base"),
        left=_node("left", _ids("base"), materialized="ephemeral"),
        right=_node("right", _ids("base"), materialized="ephemeral"),
        dataset=_node("dataset", _ids("left", "right")),
    )

    assert effective_dependencies(manifest, "model.p.dataset") == _ids("base")


def test_sources_stay_dependencies():
    manifest = _manifest(base=_node("base", ["source.p.tamanu.patients"]))

    assert effective_dependencies(manifest, "model.p.base") == ["source.p.tamanu.patients"]


def test_a_restricted_ephemeral_model_gets_no_view_with_a_sensitive_facility():
    manifest = _manifest(
        episodes=_node("episodes", tags=["restricted"], materialized="ephemeral"),
        dataset=_node("dataset", _ids("episodes"), tags=["restricted"]),
    )

    assert reporting_schema_nodes(manifest, False) == []
    assert reporting_schema_nodes(manifest, True) == _ids("dataset")


def test_reports_and_internal_models_get_no_view():
    manifest = _manifest(
        registry=_node("registry", tags=["internal"]),
        report=_node("report", tags=["reports"]),
        base=_node("base"),
    )

    assert reporting_schema_nodes(manifest, False) == _ids("base")
