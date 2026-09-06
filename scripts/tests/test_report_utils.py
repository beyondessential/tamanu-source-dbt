import pytest

from utils.report_utils import (
    ReportingSchemaDependencyError,
    order_models_for_schema,
)


def _node(name, deps=(), tags=()):
    """Build the slice of a manifest node the ordering reads."""
    return {"name": name, "tags": list(tags), "depends_on": {"nodes": list(deps)}}


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
