"""Tests for scripts/generate_who_dak_maps.py (specs/dbt-model/map__who_dak.md)."""

from pathlib import Path

import pytest
from generate_who_dak_maps import CSV_DIR, MODELS_DIR, build_model, generate, read_copy

QUESTIONS_HEADER = "survey_id,question_code,option,element_id,role\n"


def write(path: Path, text: str) -> Path:
    path.write_text(text, encoding="utf-8", newline="")
    return path


def test_ac_002_a_model_holds_every_row_in_order_as_text(tmp_path: Path):
    # Arrange
    csv_dir, models_dir = tmp_path / "csv", tmp_path / "models"
    csv_dir.mkdir()
    write(
        csv_dir / "map__who_dak_x_questions.csv",
        QUESTIONS_HEADER + "program-whodakx-b,whodakx-b-de2,,X.B.DE2,\nprogram-whodakx-a,whodakx-a-de1,,X.A.DE1,contact\n",
    )

    # Act
    written = generate(csv_dir, models_dir)

    # Assert
    assert [path.name for path in written] == ["map__who_dak_x_questions.sql"]
    sql = written[0].read_text(encoding="utf-8")
    assert sql.index("'X.B.DE2'") < sql.index("'X.A.DE1'")
    for column in ("survey_id", "question_code", "option", "element_id", "role"):
        assert f"{column}::text as {column}" in sql


def test_ac_002_a_model_whose_copy_is_gone_is_removed(tmp_path: Path):
    csv_dir, models_dir = tmp_path / "csv", tmp_path / "models"
    csv_dir.mkdir()
    models_dir.mkdir()
    write(csv_dir / "map__who_dak_x_questions.csv", QUESTIONS_HEADER + "s,q,,X.A.DE1,\n")
    write(models_dir / "map__who_dak_y_questions.sql", "select 1")

    generate(csv_dir, models_dir)

    assert sorted(path.name for path in models_dir.iterdir()) == ["map__who_dak_x_questions.sql"]


def test_ac_003_blank_cells_are_null_and_quotes_are_escaped():
    sql = build_model(
        "map__who_dak_x_elements",
        "elements",
        [{"element_id": "X.A.DE1", "label": "Woman's age", "data_type": "", "tab": "X.A"}],
    )

    assert "('X.A.DE1', 'Woman''s age', null, 'X.A')" in sql


@pytest.mark.parametrize(
    ("name", "text", "message"),
    [
        ("map__who_dak_x_questions.csv", "survey_id,question_code,element_id\ns,q,X.A.DE1\n", "columns"),
        ("map__who_dak_x_questions.csv", QUESTIONS_HEADER, "no rows"),
        ("who_dak_x_questions.csv", QUESTIONS_HEADER + "s,q,,X.A.DE1,\n", "not named"),
    ],
)
def test_ac_004_a_copy_the_models_cannot_be_built_from_is_refused(tmp_path: Path, name, text, message):
    with pytest.raises(ValueError, match=message):
        read_copy(write(tmp_path / name, text))


def test_ac_005_committed_models_match_their_copies(tmp_path: Path):
    root = Path(__file__).resolve().parents[2]

    written = generate(root / CSV_DIR, tmp_path)

    for path in written:
        assert path.read_bytes() == (root / MODELS_DIR / path.name).read_bytes(), path.name
