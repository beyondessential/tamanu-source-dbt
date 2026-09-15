import os
from unittest.mock import MagicMock, patch

from utils.system_utils import cprint, execute_command_with_output


# ---------------------------------------------------------------------------
# execute_command_with_output -- must pin decoding to UTF-8, not host locale
# ---------------------------------------------------------------------------


def test_execute_command_with_output_forces_utf8_decoding():
    # On Windows, subprocess.run's text=True decodes captured output using
    # the host's preferred locale encoding (cp1252), not UTF-8. Survey
    # question text containing a non-cp1252 character then raises
    # UnicodeDecodeError inside a subprocess reader thread -- non-
    # deterministically either crashing the read (stdout/stderr end up
    # None, and callers combining them with `+` get a TypeError) or
    # hanging. Pinning encoding/errors here makes decoding succeed
    # regardless of host locale.
    with patch("utils.system_utils.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0)
        execute_command_with_output("dbt run-operation get_survey_docs")

    _, kwargs = mock_run.call_args
    assert kwargs["text"] is True
    assert kwargs["capture_output"] is True
    assert kwargs["encoding"] == "utf-8"
    assert kwargs["errors"] == "replace"


def test_execute_command_with_output_forces_child_to_write_utf8():
    # Decoding UTF-8 on our end only round-trips correctly if the child
    # (dbt, itself a Python process spawned via shell=True) actually wrote
    # UTF-8. Without PYTHONUTF8/PYTHONIOENCODING forced in its environment,
    # a Windows child defaults to the console codepage (cp1252) for its own
    # stdout -- our decode then substitutes a replacement character for
    # anything cp1252 mangled, silently corrupting otherwise-valid content
    # (observed: a right double quotation mark survey question came back
    # as U+FFFD instead of itself even with our decode-side fix alone).
    with patch("utils.system_utils.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0)
        execute_command_with_output("dbt run-operation get_survey_docs")

    _, kwargs = mock_run.call_args
    assert kwargs["env"]["PYTHONUTF8"] == "1"
    assert kwargs["env"]["PYTHONIOENCODING"] == "utf-8"


def test_execute_command_with_output_preserves_rest_of_environment():
    # The child must still see the caller's environment (PATH, DBT_* vars,
    # credentials, etc.) -- only UTF-8 mode is added, nothing is dropped.
    with patch.dict(os.environ, {"SOME_MARKER_VAR": "marker-value"}):
        with patch("utils.system_utils.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            execute_command_with_output("dbt deps")

    _, kwargs = mock_run.call_args
    assert kwargs["env"]["SOME_MARKER_VAR"] == "marker-value"


def test_execute_command_with_output_passes_cwd_through():
    with patch("utils.system_utils.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0)
        execute_command_with_output("dbt deps", cwd="/some/project")

    _, kwargs = mock_run.call_args
    assert kwargs["cwd"] == "/some/project"


# ---------------------------------------------------------------------------
# cprint -- must not crash when stdout can't encode a message
# ---------------------------------------------------------------------------


def test_cprint_recovers_from_unicode_encode_error(monkeypatch):
    # A narrow console codepage (e.g. cp1252) raises UnicodeEncodeError for
    # characters like the checkmark emoji check_translations.py prints on
    # success -- this used to crash the whole script instead of just the
    # print statement. Force stdout's encoding deterministically (rather
    # than relying on the real one, which is UTF-8 under pytest and would
    # make the encode/decode round-trip on the fallback path a no-op,
    # letting a broken fallback pass silently).
    monkeypatch.setattr(
        "utils.system_utils.sys.stdout", MagicMock(encoding="ascii")
    )
    calls = []

    def fake_print(*args, **kwargs):
        calls.append(args[0])
        if len(calls) == 1:
            raise UnicodeEncodeError(
                "charmap", "✅", 0, 1, "character maps to <undefined>"
            )

    monkeypatch.setattr("utils.system_utils.print", fake_print, raising=False)

    cprint("✅ ALL TRANSLATIONS FOUND!", "success")  # must not raise

    assert len(calls) == 2
    # the fallback must actually be encodable in that encoding, not just
    # "some second call happened" -- and backslashreplace keeps the
    # codepoint legible instead of collapsing it to a bare "?"
    calls[1].encode("ascii")  # raises if still not representable
    assert "✅" not in calls[1]
    assert "\\u2705" in calls[1]


def test_cprint_prints_normally_when_encoding_succeeds(monkeypatch):
    calls = []
    monkeypatch.setattr(
        "utils.system_utils.print", lambda *a, **k: calls.append(a[0]), raising=False
    )

    cprint("all good", "info")

    assert len(calls) == 1
    assert "all good" in calls[0]
