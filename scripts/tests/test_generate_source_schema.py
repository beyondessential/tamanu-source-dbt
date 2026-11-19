import textwrap

from generate_source_schema import ROOT, build_ddl


def _write(root, relative, content):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content), encoding="utf-8")


def _project(tmp_path):
    _write(
        tmp_path,
        "models/sources/encounters.yml",
        """\
        sources:
          - name: tamanu
            schema: public
            tables:
              - name: encounters
                columns:
                  - name: id
                    data_type: character varying(255)
                  - name: tags
                    data_type: array
                  - name: kind
                    data_type: user-defined
                  - name: note
              - name: no_columns
        """,
    )
    _write(
        tmp_path,
        "models/logs/changes.yml",
        """\
        sources:
          - name: logs__tamanu
            schema: logs
            tables:
              - name: changes
                columns:
                  - name: id
                    data_type: uuid
        """,
    )
    return tmp_path


def test_creates_each_table_with_its_declared_column_types(tmp_path):
    ddl = build_ddl(_project(tmp_path))

    assert (
        'create table "public"."encounters" ("id" character varying(255), "tags" text[], '
        '"kind" text, "note" text);'
    ) in ddl
    assert 'create table "logs"."changes" ("id" uuid);' in ddl


def test_creates_each_schema_once_before_its_tables(tmp_path):
    ddl = build_ddl(_project(tmp_path))

    assert ddl.count('create schema if not exists "public";') == 1
    assert ddl.index('create schema if not exists "public";') < ddl.index('"public"."encounters"')


def test_ac_001_skips_a_table_with_no_declared_columns(tmp_path):
    assert "no_columns" not in build_ddl(_project(tmp_path))


def test_covers_the_repository_sources():
    ddl = build_ddl(ROOT)

    assert 'create table "public"."encounters" (' in ddl
    assert 'create table "logs"."changes" (' in ddl


def test_substitutes_upper_case_and_missing_types(tmp_path):
    _write(
        tmp_path,
        "models/sources/odd.yml",
        """\
        sources:
          - name: tamanu
            schema: public
            tables:
              - name: odd
                columns:
                  - name: tags
                    data_type: ARRAY
                  - name: kind
                    data_type: USER-DEFINED
                  - name: blank
                    data_type:
        """,
    )

    assert 'create table "public"."odd" ("tags" text[], "kind" text, "blank" text);' in build_ddl(
        tmp_path
    )
