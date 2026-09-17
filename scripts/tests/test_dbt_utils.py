import utils.dbt_utils as dbt_utils


# ---------------------------------------------------------------------------
# get_dbt_target_arg -- a build against a restored replica has to name the
# target, and every other run has to keep landing on the profile's default
# ---------------------------------------------------------------------------


def test_no_target_is_named_when_the_environment_names_none(monkeypatch):
    # An empty string and not "--target demo": a deployment repo's default
    # target is its own business, and naming one here would override it.
    monkeypatch.delenv("TAMANU_DBT_TARGET", raising=False)

    assert dbt_utils.get_dbt_target_arg() == ""


def test_the_named_target_is_passed_to_dbt(monkeypatch):
    monkeypatch.setenv("TAMANU_DBT_TARGET", "replica")

    assert dbt_utils.get_dbt_target_arg() == " --target replica"


def test_a_blank_target_names_none(monkeypatch):
    monkeypatch.setenv("TAMANU_DBT_TARGET", "   ")

    assert dbt_utils.get_dbt_target_arg() == ""
