import io
import urllib.error
import urllib.request
import zipfile

import pytest
import yaml

import build_reporting_schema


def _refuse():
    raise AssertionError("the checkout's own profile was overwritten")


class _Answer:
    """Stands in for the response urlopen is used as a context manager for."""

    def __init__(self, status):
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def _urlopen(answers, sent):
    """An urlopen that answers from `answers` and records what it was sent."""

    def fake(request, timeout=None):
        sent.append(request)
        answer = answers.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return _Answer(answer)

    return fake


@pytest.fixture(autouse=True)
def _callback(monkeypatch):
    monkeypatch.setattr(build_reporting_schema, "CALLBACK_URL", "http://operator/results/token")
    monkeypatch.setattr(build_reporting_schema.time, "sleep", lambda _: None)


# deliver


def test_a_schema_is_delivered_as_sql(monkeypatch):
    sent = []
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([204], sent))

    build_reporting_schema.deliver(b"create schema reporting;", "http://operator/results/token", "application/sql")

    assert len(sent) == 1
    assert sent[0].data == b"create schema reporting;"
    assert sent[0].get_header("Content-type") == "application/sql"


def test_a_refused_delivery_is_not_sent_again(monkeypatch):
    sent = []
    refused = urllib.error.HTTPError("http://operator", 403, "Forbidden", {}, None)
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([refused], sent))

    with pytest.raises(RuntimeError, match="403"):
        build_reporting_schema.deliver(b"create schema reporting;", "http://operator/results/token", "application/sql")

    assert len(sent) == 1


def test_a_schema_the_operator_cannot_take_yet_is_sent_again(monkeypatch):
    sent = []
    later = urllib.error.HTTPError("http://operator", 503, "Unavailable", {}, None)
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([later, 204], sent))

    build_reporting_schema.deliver(b"create schema reporting;", "http://operator/results/token", "application/sql")

    assert len(sent) == 2


def test_a_delivery_that_never_lands_fails_the_build(monkeypatch):
    sent = []
    unreachable = urllib.error.URLError("connection refused")
    monkeypatch.setattr(
        urllib.request,
        "urlopen",
        _urlopen([unreachable] * build_reporting_schema.CALLBACK_ATTEMPTS, sent),
    )

    with pytest.raises(RuntimeError, match="every attempt"):
        build_reporting_schema.deliver(b"create schema reporting;", "http://operator/results/token", "application/sql")

    assert len(sent) == build_reporting_schema.CALLBACK_ATTEMPTS


# main


def test_a_delivery_without_a_version_is_refused(monkeypatch):
    monkeypatch.delenv("TAMANU_VERSION", raising=False)
    monkeypatch.setattr(build_reporting_schema, "build", lambda: "unreached.sql")

    with pytest.raises(RuntimeError, match="TAMANU_VERSION"):
        build_reporting_schema.main()


def test_a_local_run_without_a_version_still_builds(monkeypatch, tmp_path):
    monkeypatch.delenv("TAMANU_VERSION", raising=False)
    monkeypatch.setattr(build_reporting_schema, "CALLBACK_URL", "")
    built = tmp_path / "schema.sql"
    built.write_text("create schema reporting;", encoding="utf-8")
    monkeypatch.setattr(build_reporting_schema, "build", lambda: str(built))

    build_reporting_schema.main()


# check_version_line


@pytest.fixture
def _pinned(monkeypatch, tmp_path):
    project = tmp_path / "dbt_project.yml"
    project.write_text("name: tamanu_source_dbt\nversion: 2.60.37\n", encoding="utf-8")
    monkeypatch.setattr(build_reporting_schema, "PACKAGE_PROJECT", project)


def test_a_version_on_another_line_is_refused_before_building(monkeypatch, _pinned):
    monkeypatch.setenv("TAMANU_VERSION", "2.63.0")
    monkeypatch.setattr(build_reporting_schema, "build", _refuse)

    with pytest.raises(RuntimeError, match="2.63.0 is not on the line of the pinned tamanu-source-dbt 2.60.37"):
        build_reporting_schema.main()


@pytest.mark.parametrize("requested", ["2.60.40", "v2.60.1", "2.60.37"])
def test_a_version_on_the_pinned_line_builds(monkeypatch, tmp_path, _pinned, requested):
    monkeypatch.setenv("TAMANU_VERSION", requested)
    monkeypatch.delenv("TAMANU_DL_DB_URL", raising=False)
    monkeypatch.setattr(build_reporting_schema, "CALLBACK_URL", "")
    built = tmp_path / "schema.sql"
    built.write_text("create schema reporting;", encoding="utf-8")
    monkeypatch.setattr(build_reporting_schema, "build", lambda: str(built))

    build_reporting_schema.main()


def test_the_package_s_own_project_is_what_is_pinned():
    assert build_reporting_schema.PACKAGE_PROJECT.parent.joinpath("scripts", "build_reporting_schema.py").exists()


# write_profile


def test_the_profile_is_written_under_the_project_s_profile_name(monkeypatch, tmp_path):
    monkeypatch.setattr(
        build_reporting_schema, "get_dbt_project_config", lambda: {"profile": "tamanu_dbt_kamaka"}
    )
    monkeypatch.setattr(build_reporting_schema, "PROFILES_PATH", tmp_path / "config" / "profiles.yml")
    monkeypatch.setattr(build_reporting_schema, "TARGET", "replica")

    build_reporting_schema.write_profile()

    written = yaml.safe_load((tmp_path / "config" / "profiles.yml").read_text(encoding="utf-8"))
    target = written["tamanu_dbt_kamaka"]["outputs"]["replica"]
    assert written["tamanu_dbt_kamaka"]["target"] == "replica"
    assert target["host"] == "{{ env_var('TAMANU_DL_DB_URL') }}"
    assert target["schema"] == "reporting"


def test_a_project_naming_no_profile_falls_back_to_its_name(monkeypatch, tmp_path):
    monkeypatch.setattr(
        build_reporting_schema, "get_dbt_project_config", lambda: {"name": "tamanu_dbt_kamaka"}
    )
    monkeypatch.setattr(build_reporting_schema, "PROFILES_PATH", tmp_path / "config" / "profiles.yml")

    build_reporting_schema.write_profile()

    written = yaml.safe_load((tmp_path / "config" / "profiles.yml").read_text(encoding="utf-8"))
    assert "tamanu_dbt_kamaka" in written


def test_a_local_run_keeps_the_checkout_s_profile(monkeypatch, tmp_path):
    monkeypatch.delenv("TAMANU_DL_DB_URL", raising=False)
    monkeypatch.setattr(build_reporting_schema, "CALLBACK_URL", "")
    monkeypatch.setattr(build_reporting_schema, "write_profile", _refuse)
    built = tmp_path / "schema.sql"
    built.write_text("create schema reporting;", encoding="utf-8")
    monkeypatch.setattr(build_reporting_schema, "build", lambda: str(built))

    build_reporting_schema.main()


# reports


def _compiles(monkeypatch, tmp_path, languages, compiled):
    """Stand in for dbt: each language's compile writes `compiled[language]`."""
    commands = []
    monkeypatch.setattr(
        build_reporting_schema,
        "get_dbt_project_config",
        lambda: {"vars": {"supported_languages": languages}} if languages else {},
    )
    monkeypatch.setattr(build_reporting_schema, "execute_command", commands.append)

    def generate(language):
        paths = []
        for name in compiled.get(language, []):
            path = tmp_path / name
            path.write_text("{}", encoding="utf-8")
            paths.append(str(path))
        return paths

    monkeypatch.setattr(build_reporting_schema, "generate_project_reports", generate)
    return commands


def test_reports_are_zipped_flat_under_their_release_names(monkeypatch, tmp_path):
    names = {
        "en": ["admissions-v2.60.0-kamaka-en.json"],
        "fr": ["admissions-v2.60.0-kamaka-fr.json"],
    }
    commands = _compiles(monkeypatch, tmp_path, ["en", "fr"], names)

    archive = zipfile.ZipFile(io.BytesIO(build_reporting_schema.build_reports()))

    assert sorted(archive.namelist()) == [
        "admissions-v2.60.0-kamaka-en.json",
        "admissions-v2.60.0-kamaka-fr.json",
    ]
    assert [c for c in commands if "{language: en}" in c]
    assert [c for c in commands if "{language: fr}" in c]


def test_a_project_declaring_no_languages_compiles_the_default(monkeypatch, tmp_path):
    commands = _compiles(monkeypatch, tmp_path, None, {"default": ["admissions-v2.60.0-kamaka.json"]})

    build_reporting_schema.build_reports()

    assert len(commands) == 1
    assert "{language: default}" in commands[0]


def test_a_project_with_no_reports_delivers_none(monkeypatch, tmp_path):
    _compiles(monkeypatch, tmp_path, ["en"], {})
    sent = []
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([], sent))

    build_reporting_schema.deliver_reports()

    assert sent == []


def test_reports_are_delivered_as_a_zip(monkeypatch, tmp_path):
    _compiles(monkeypatch, tmp_path, ["en"], {"en": ["admissions-v2.60.0-kamaka-en.json"]})
    monkeypatch.setattr(build_reporting_schema, "REPORTS_CALLBACK_URL", "http://operator/reports/token")
    sent = []
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([204], sent))

    build_reporting_schema.deliver_reports()

    assert sent[0].full_url == "http://operator/reports/token"
    assert sent[0].get_header("Content-type") == "application/zip"


@pytest.mark.parametrize(
    "failure",
    [
        SystemExit(1),
        urllib.error.HTTPError("http://operator", 404, "Not Found", {}, None),
    ],
    ids=["a compile that exits", "an operator with no reports route"],
)
def test_reports_that_fail_leave_the_build_standing(monkeypatch, tmp_path, failure):
    _compiles(monkeypatch, tmp_path, ["en"], {"en": ["admissions-v2.60.0-kamaka-en.json"]})
    if isinstance(failure, SystemExit):

        def exits(_):
            raise failure

        monkeypatch.setattr(build_reporting_schema, "execute_command", exits)
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([failure], []))

    build_reporting_schema.deliver_reports()


def test_reports_follow_the_schema_only_where_the_operator_asks(monkeypatch, tmp_path):
    monkeypatch.setenv("TAMANU_VERSION", "2.60.0")
    monkeypatch.setattr(build_reporting_schema, "check_version_line", lambda: None)
    monkeypatch.delenv("TAMANU_DL_DB_URL", raising=False)
    built = tmp_path / "schema.sql"
    built.write_text("create schema reporting;", encoding="utf-8")
    monkeypatch.setattr(build_reporting_schema, "build", lambda: str(built))
    order = []
    monkeypatch.setattr(build_reporting_schema, "deliver", lambda body, url, kind: order.append(kind))
    monkeypatch.setattr(build_reporting_schema, "deliver_reports", lambda: order.append("reports"))

    monkeypatch.setattr(build_reporting_schema, "REPORTS_CALLBACK_URL", "")
    build_reporting_schema.main()
    assert order == ["application/sql"]

    order.clear()
    monkeypatch.setattr(build_reporting_schema, "REPORTS_CALLBACK_URL", "http://operator/reports/token")
    build_reporting_schema.main()
    assert order == ["application/sql", "reports"]
