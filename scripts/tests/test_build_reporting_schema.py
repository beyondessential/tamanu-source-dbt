import urllib.error
import urllib.request

import pytest

import build_reporting_schema


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

    build_reporting_schema.deliver(b"create schema reporting;")

    assert len(sent) == 1
    assert sent[0].data == b"create schema reporting;"
    assert sent[0].get_header("Content-type") == "application/sql"


def test_a_refused_delivery_is_not_sent_again(monkeypatch):
    sent = []
    refused = urllib.error.HTTPError("http://operator", 403, "Forbidden", {}, None)
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([refused], sent))

    with pytest.raises(RuntimeError, match="403"):
        build_reporting_schema.deliver(b"create schema reporting;")

    assert len(sent) == 1


def test_a_schema_the_operator_cannot_take_yet_is_sent_again(monkeypatch):
    sent = []
    later = urllib.error.HTTPError("http://operator", 503, "Unavailable", {}, None)
    monkeypatch.setattr(urllib.request, "urlopen", _urlopen([later, 204], sent))

    build_reporting_schema.deliver(b"create schema reporting;")

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
        build_reporting_schema.deliver(b"create schema reporting;")

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
