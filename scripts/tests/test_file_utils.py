import json

from utils.file_utils import write_file


# ---------------------------------------------------------------------------
# write_file -- must emit LF, not the host's line separator
# ---------------------------------------------------------------------------
#
# On Windows, open(path, "w") translates every \n to os.linesep, so a generated
# file comes out CRLF. For the survey models that matters beyond tidiness: dbt
# reads the freshly written .md/.yml back into its manifest descriptions, and
# those strings are serialised verbatim into the reporting bundle -- a literal
# \r then reaches the consumer, which a YAML or JSON parser preserves rather
# than normalising away. It cannot be fixed by .gitattributes, because the
# build reads the working files before git ever sees them.


def test_write_file_text_emits_lf_not_platform_newline(tmp_path):
    target = tmp_path / "doc.md"

    write_file(str(target), "first line\nsecond line\n")

    assert target.read_bytes() == b"first line\nsecond line\n"


def test_write_file_json_emits_lf_not_platform_newline(tmp_path):
    target = tmp_path / "config.json"

    write_file(str(target), {"a": 1, "b": [2, 3]}, file_type="json")

    raw = target.read_bytes()
    assert b"\r\n" not in raw
    # still valid JSON, and still the indented form callers rely on
    assert json.loads(raw.decode("utf-8")) == {"a": 1, "b": [2, 3]}
    assert b"\n" in raw
