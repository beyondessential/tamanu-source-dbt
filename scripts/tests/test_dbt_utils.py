import utils.dbt_utils as dbt_utils


# ---------------------------------------------------------------------------
# get_deployment_version / get_deployment_name -- a build driven from outside
# is told what to build for, rather than reading it off the checkout
# ---------------------------------------------------------------------------


def test_version_comes_from_the_checkout_when_the_environment_names_none(monkeypatch):
    monkeypatch.delenv("TAMANU_VERSION", raising=False)
    monkeypatch.setattr(dbt_utils, "get_dbt_project_config", lambda: {"version": "2.54.0"})

    assert dbt_utils.get_deployment_version() == "2.54.0"


def test_version_comes_from_the_environment_where_it_names_one(monkeypatch):
    monkeypatch.setenv("TAMANU_VERSION", "2.60.2")
    monkeypatch.setattr(dbt_utils, "get_dbt_project_config", lambda: {"version": "2.54.0"})

    assert dbt_utils.get_deployment_version() == "2.60.2"


def test_a_v_prefixed_version_is_taken_as_the_same_version(monkeypatch):
    # Versions are written both ways across the deployment repos and the
    # artefact names, and the value ends up in a filename and a SQL comment.
    monkeypatch.setenv("TAMANU_VERSION", "v2.60.2")

    assert dbt_utils.get_deployment_version() == "2.60.2"


def test_a_blank_version_falls_back_rather_than_building_for_nothing(monkeypatch):
    monkeypatch.setenv("TAMANU_VERSION", "   ")
    monkeypatch.setattr(dbt_utils, "get_dbt_project_config", lambda: {"version": "2.54.0"})

    assert dbt_utils.get_deployment_version() == "2.54.0"


def test_deployment_comes_from_the_project_name_when_the_environment_names_none(monkeypatch):
    monkeypatch.delenv("TAMANU_DEPLOYMENT", raising=False)
    monkeypatch.setattr(dbt_utils, "get_project_name", lambda: "tamanu_dbt_kamaka")

    assert dbt_utils.get_deployment_name() == "kamaka"


def test_deployment_comes_from_the_environment_where_it_names_one(monkeypatch):
    monkeypatch.setenv("TAMANU_DEPLOYMENT", "drifting")
    monkeypatch.setattr(dbt_utils, "get_project_name", lambda: "tamanu_dbt_kamaka")

    assert dbt_utils.get_deployment_name() == "drifting"


# ---------------------------------------------------------------------------
# get_dbt_target_arg -- a build against a restored replica has to name the
# target, and every other run has to keep landing on the profile's default
# ---------------------------------------------------------------------------


def test_no_target_is_named_when_the_environment_names_none(monkeypatch):
    # An empty string rather than "--target demo": a deployment repo's default
    # target is its own business, and naming one here would override it.
    monkeypatch.delenv("TAMANU_DBT_TARGET", raising=False)

    assert dbt_utils.get_dbt_target_arg() == ""


def test_the_named_target_is_passed_to_dbt(monkeypatch):
    monkeypatch.setenv("TAMANU_DBT_TARGET", "replica")

    assert dbt_utils.get_dbt_target_arg() == " --target replica"


def test_a_blank_target_names_none(monkeypatch):
    monkeypatch.setenv("TAMANU_DBT_TARGET", "   ")

    assert dbt_utils.get_dbt_target_arg() == ""
