#!/usr/bin/env python3
"""Generate Tamanu program forms from a WHO SMART guidelines Digital Adaptation Kit.

Every DAK publishes the same four Web Annexes, so this reads the format rather than a particular
kit. Annex A is the input and the spec is the output: labels, option strings and the mandatory flag
come from the dictionary rather than being authored, because the option strings are what land in
`survey_response_answers.body` and nothing downstream can compensate for strings that do not match.
Annex B contributes conditional guidance prompts.

What Annex A gives per data element: an ID (`HIV.D.DE39`), a label, a data type, a `Required` flag,
terminology codes (ICD-11 / ICD-10 / LOINC / ICHI / ICF / SNOMED GPS), the Annex C indicators it
feeds, and - for coded elements - one child row per input option
(`Multiple Choice Type = "Input Option"`), which is where the exact option strings live.

A domain is data, not code. `<domain>/domain.py` declares its DAK's identity and annexes, which
tabs become which surveys, the elements worth carrying, its encodable decision rules and its
Tamanu registry. Adding a kit means adding one of those, not editing this file.

Usage, from this directory:

    python dak_generator.py --domain hiv

The spec is rendered into a workbook by the `build-tamanu-forms` skill's own builder, read from
a sibling `claude-plugins` checkout - see `README.md`:

    FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
    python $FORMS_SKILL/build_program_xlsx.py --spec hiv/who-dak-hiv_program.json \\
        --out hiv/who-dak-hiv_program.xlsx

The annexes are not committed - third-party spreadsheets WHO publishes at stable URLs, ignored via
`<domain>/annexes/`. Each domain records their URLs and Annex A's checksum, so a WHO revision
announces itself rather than quietly changing a form; the script prints the fetch command when a
file is absent. See each domain's `dak-conformance.md`.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path

from openpyxl import load_workbook

DOMAINS_DIR = Path(__file__).resolve().parent


def load_domain(name: str):
    """Import `<name>/domain.py` from beside this script."""
    module_path = DOMAINS_DIR / name / "domain.py"
    if not module_path.exists():
        available = sorted(d.name for d in DOMAINS_DIR.iterdir() if (d / "domain.py").exists())
        raise SystemExit(
            f"ERROR: no domain {name!r} - expected {module_path}\nAvailable: {', '.join(available) or 'none'}"
        )
    spec = importlib.util.spec_from_file_location(f"domain_{name}", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Annex A data type + multiple-choice type -> Tamanu question type.
# 'Codes' appears on child option rows and on a couple of standalone "Other" elements.
def tamanu_type(dtype: str, mct: str, has_options: bool) -> str:
    if dtype == "Boolean":
        return "Binary"  # Boolean/Select one still means yes-no
    if dtype == "Quantity":
        return "Number"
    if dtype == "Date":
        return "Date"
    if dtype == "DateTime":
        return "DateTime"
    if dtype == "Time":
        return "Time"
    if dtype in ("String", "ID", "Codes"):
        return "FreeText"
    if dtype == "Signature":
        return "Signature"
    if dtype == "Attachment":
        # Tamanu's only question type that stores a file. The BDS kit's one `Attachment` is a
        # photograph of the newborn, which is what its own legend gives as the type's example.
        return "Photo"
    if dtype == "Coding":
        # A Coding element with no input options in the dictionary is country-configured (DAK
        # Table 13). Falling through to free text keeps the element without inventing a list;
        # the generator reports these so a deployment can supply one.
        if not has_options:
            return "FreeText"
        return "MultiSelect" if mct == "Select all that apply" else "Radio"
    return "FreeText"


def norm(value: str) -> str:
    return " ".join(re.sub(r"[^a-z0-9 ]", " ", str(value or "").lower()).split())


# A kit's own spelling of a data type, normalised to the vocabulary `tamanu_type` reads. `N/A`
# says the column does not apply, which is what a blank says. The CHE kit also writes `Code` for
# the `Codes` every other kit puts on an option row, `Integer` for a `Quantity` whose sub-type
# column already says integer, and qualifies one element's type with the element it borrows its
# value set from - `Coding (use the same coding as for the oral fluid test results)`.
#
# The SRV kit has no multiple-choice column and states the choice here instead:
# `List - select one`, `List - select all that apply`, and `List value` on each of the 383
# option rows beneath them. Those are the `Coding` parent and `Codes` option row every other
# kit writes, and `choice_type` reads the same cell for which of the two lists a parent is.
#
# The BDS kit writes those same two list types with an en dash where the SRV kit writes a
# hyphen, so the separator is levelled before the lookup rather than every dash spelling being
# named. Unmatched, `List – select one` is not `Coding`, the row never becomes a parent, and
# the kit's whole anomaly hierarchy imports as free text.
DASHES = re.compile(r"[–—]")

DATA_TYPES = {
    "code": "Codes",
    "integer": "Quantity",
    "n/a": "",
    "na": "",
    "list - select one": "Coding",
    "list - select all that apply": "Coding",
    "list value": "Codes",
}

# The same, for the multiple-choice column. A kit qualifies the type in place rather than in the
# conditionality column beside it - `Input option (for type of skin problem)`, `Select one (only
# if abscess is selected)`, `Select one - Check box` - and that qualifier is prose, not a distinct
# type, so the match is on the wording before it. Read literally, 23 of the CHE kit's option rows
# are elements, each becoming a question of its own and taking the rest of its parent's options
# with it, which is the failure the `Input option` / `Input Option` rule already exists to prevent.
CHOICE_TYPES = {
    "input option": "Input Option",
    "input code": "Input Option",
    "select one": "Select one",
    "select all": "Select all that apply",
    "select all that apply": "Select all that apply",
    "show all that apply": "Select all that apply",
    "list select one": "Select one",
    "list select all that apply": "Select all that apply",
    "list value": "Input Option",
}


def data_type(dtype: str) -> str:
    base = re.split(r"\(", dtype or "")[0].strip()
    return DATA_TYPES.get(DASHES.sub("-", base).lower(), base)


def choice_type(mct: str) -> str:
    """The multiple-choice type a row declares, whatever the kit qualifies it with.

    Returns "" for anything that is not one of the types, which is what `N/A` and a kit's prose -
    `Derived from information entered into the fields below` - both amount to. A row typed
    `Coding` owns its options whether or not this recognises its multiple-choice column, so prose
    there costs the row nothing.
    """
    # The whole cell first, then the part before a qualifier. The SRV kit separates its own
    # spelling with the same " - " that separates another kit's qualifier from its type, so
    # splitting first would read `List - select one` as `List` and leave every list untyped.
    split = norm(re.split(r"[(\u2013\u2014]|\s-\s", mct or "")[0])
    for candidate in (norm(mct), split):
        for prefix, canonical in CHOICE_TYPES.items():
            if candidate == prefix or candidate.startswith(prefix + " "):
                return canonical
    return ""


# `survey_screen_components.text`, `.detail`, `.config`, `.visibility_criteria` and `.calculation`
# are varchar(255) (`DataTypes.STRING`), as are `program_data_elements.name` and `.code`.
# `.options` and `.validation_criteria` are TEXT, so option lists are not at risk. Annex A's
# "Description and Definition" runs past 255 for a handful of elements.
MAX_FIELD = 255


def fit(value: str, limit: int = MAX_FIELD) -> str:
    """Trim to the column limit on a word boundary, marking that it was trimmed.

    Cutting mid-word in a clinician-facing hint reads as corruption, and cutting silently hides
    that the DAK said more. Neither is acceptable in a field a nurse reads at the bedside.
    """
    text = str(value or "").strip()
    if len(text) <= limit:
        return text
    cut = text[: limit - 1]
    if " " in cut:
        cut = cut[: cut.rfind(" ")]
    return cut.rstrip(" ,;:.") + "…"


# Annex A's column names vary between kits, and inside the ANC kit between tabs: a `[ANC] `
# prefix on the id columns, a line break inside "Multiple Choice Type\n(if applicable)", one tab
# in sentence case, and "Multiple Choice" where the others say "Multiple Choice Type". A field is
# therefore matched on the normalised header and names every spelling it answers to, which is what
# lets one reader serve both kits.
COLUMNS = {
    "activity": ("activity id", "activity id and name"),
    "activityName": ("activity name",),
    "de": ("data element id",),
    "label": ("data element label",),
    "description": ("description and definition", "description and definition/user information"),
    "dtype": ("data type",),
    "mct": ("multiple choice type (if applicable)", "multiple choice"),
    "option": ("input options",),
    "subtype": ("quantity sub-type", "quantity subtype"),
    "required": ("required", "optionality"),
    "subcategory": ("data element subcategory",),
    "conditionality": ("explain conditionality", "skip logic", "conditional logic"),
    "indicators": ("linkages to aggregate indicators", "links to aggregate indicators"),
    "list": ("list to include this data element in",),
}


def header_key(header) -> str:
    """`[ANC] Data Element\nID` -> `data element id`; `Data element label*` -> the same.

    The trailing asterisk is the SRV kit's, which stars every column its own instruction tab
    calls "required to be filled in for every data element" - fourteen per tab, among them the
    one that identifies the header row. Left on, `HEADER_MARKER` matches nothing and
    `header_row` finds no header on any tab, so the kit cannot be read at all rather than
    merely read wrong.
    """
    text = re.sub(r"^\[[^\]]+\]\s*", "", re.sub(r"\s+", " ", str(header or "")).strip())
    return re.sub(r"\s*\*+$", "", text).lower()


# A header that names its field and then spells out that field's own value codes in parentheses:
# `Required (R)/optional (O)/conditional (C)`. The CHE kit writes that one legend four ways,
# differing only in where the spaces fall inside it, so answering them a spelling at a time
# invites a fifth to pass unnoticed - and a `Required` column matching nothing silently drops
# every mandatory flag on the tab. The field name is what precedes the legend, so a header is
# indexed under its qualifier-stripped form as well as under its own.
#
# Only the part before the bracket, and only where it is plain words and digits. Several headers
# can strip to one form - `ICHI (beta 3) code title` and `ICHI (beta 3) URI` both give `ichi` -
# so the stripped form is a fallback rather than a claim of uniqueness: `column_index` keeps the
# first position under it, and an exact header always beats it.
QUALIFIED_HEADER = re.compile(r"^([a-z0-9 ]+?)\s*\(.*")

# Every kit names the column holding an element's label, so that is what identifies the header row.
HEADER_MARKER = "data element label"


def column_index(header_cells) -> dict[str, int]:
    """Column positions by normalised header, and by qualifier-stripped header where they differ.

    First position wins, and an exact header always beats a stripped one, so a kit carrying both
    spellings is read under the one it wrote in full.
    """
    index: dict[str, int] = {}
    stripped: dict[str, int] = {}
    for position, header in enumerate(header_cells):
        if not header:
            continue
        key = header_key(header)
        index.setdefault(key, position)
        qualified = QUALIFIED_HEADER.match(key)
        if qualified:
            stripped.setdefault(qualified.group(1), position)
    for key, position in stripped.items():
        index.setdefault(key, position)
    return index


def header_row(rows, tab: str) -> int:
    """Which row carries the column names, which is not always the first.

    Most kits open a tab with its header. The CHE kit puts three or four banner rows above it -
    the kit's title, the business process, the tab's own name, each a single merged cell - and so
    heads most of its tabs at row 4 and two of them at row 5. Read from row 1 regardless, no
    column matches and the whole tab comes back as unlabelled rows holding nothing.
    """
    for n, row in enumerate(rows):
        if any(header_key(cell) == HEADER_MARKER for cell in row):
            return n
    raise SystemExit(
        f"ERROR: no header row on {tab!r} - no cell on any row names the {HEADER_MARKER!r} "
        "column, so there is nothing to read the tab against."
    )


def activity_text(row, index) -> str:
    """The activity as every kit but one writes it: its id and its name in one cell.

    The SRV kit gives them a column each. Read the id alone and a screen is headed
    `MENSRV.C1` with no words on it, because the heading is the activity cell with its
    leading id stripped off; joining them here means the rest of this reader sees the single
    cell it sees on every other kit, and the grouping, ordering and heading rules are
    unchanged.

    Blank where the row names no activity, so the caller's carry-forward still holds.
    """
    identifier = field(row, index, "activity")
    if not identifier:
        return ""
    name = field(row, index, "activityName")
    return f"{identifier} {name}" if name and not identifier.endswith(name) else identifier


def field(row, index, name: str) -> str:
    """An Annex A column's value, under whichever spelling this tab gives it."""
    for alias in COLUMNS[name]:
        position = index.get(alias)
        if position is None or position >= len(row):
            continue
        value = row[position]
        if value not in (None, ""):
            return re.sub(r"\s+", " ", str(value)).strip()
    return ""


def cell(row, index, key):
    position = index.get(key)
    if position is None or position >= len(row):
        return ""
    value = row[position]
    return str(value).strip() if value not in (None, "") else ""


# A row can own an option block if the dictionary types it `Coding`, or if it declares one of
# these multiple-choice types - some rows do only the latter, and a few `Coding` rows leave the
# multiple-choice column blank.
MULTIPLE_CHOICE_PARENTS = {"Select one", "Select all that apply"}

# A kit that writes each option row's `Input Options` cell as an item of a bullet list - the CHE
# kit's `- One convulsion`, `- Vomiting everything`, one row that also kept the apostrophe Excel
# uses to force a cell to text, and one that lost the space after the bullet, `-Child HIV-positive
# - virological`. The bullet is that kit's layout rather than part of the answer: these strings
# land in `survey_response_answers.body` and Annex B quotes them without it, so `"Number of
# convulsions in this illness" = "1 convulsion"` would match nothing. 187 of the CHE kit's 261
# options carry one; no other kit's carry any.
#
# The bullet has to be followed by a space or by the capital an option opens with, because a
# leading hyphen is not always layout: `-2` is a z-score and `-ve` is a result, and stripping the
# sign off either changes the answer rather than tidying it.
OPTION_BULLET = re.compile(r"^['\u2019]?\s*[-\u2013\u2014\u2022](?=\s|[A-Z])\s*")


def option_text(cell: str, label: str) -> str:
    """The string a health worker picks: the `Input Options` cell, or the label where it has none.

    That cell is normally the string to prefer - the ANC kit populates both columns and they
    differ for 196 of its 660 options: "Fluid loss (leaking)" is the label, but "Fluid loss" is
    what a health worker picks. The HIV kit leaves the column at "N/A", where the fallback yields
    the label it has always used.
    """
    text = cell if cell not in ("", "N/A") else label
    return OPTION_BULLET.sub("", text).strip()


# Data types naming something the kit's logic works out rather than something a health worker is
# asked. See `selected`.
CONCLUSIONS = {"Annotation", "Derived", "Derived qualifier"}

# Annex A marks an option row in the multiple-choice column. The PNC kit writes `Input option` on
# 24 of its rows and `Input Option` on the rest, and the difference is not cosmetic: an option row
# read as an element becomes a question of its own *and* takes the rest of its parent's options
# with it, so `PNC.A2.DE.74 Newborn's/infant's danger signs` would import with no options at all.
OPTION_ROW = "Input Option"

# A kit may define an element once on a shared tab and then reference it from every process that
# collects it, writing the reference in the multiple-choice column: the TB kit's process tabs
# carry 117 rows reading `Please check "TB.Common" tab for more data element details`, each of
# them a real question with no type, no options and no description of its own. Read literally
# they are 116 mandatory-looking free-text boxes with the answers stripped out, which is worse
# than dropping them. The cell names the tab holding the definition, so the reader follows it.
CROSS_REFERENCE = re.compile(r'please\s+check\s+["“]?([^"”]+?)["”]?\s+tab', re.IGNORECASE)


def is_option_row(row, index, types: dict[str, str], option_ids: frozenset[str] = frozenset()) -> bool:
    """Whether the dictionary marks this row as one of the row above's input options.

    The same test `read_annex_a` applies when it attaches an option to its parent: marked
    `Input Option`, and not a `Coding` row that carries the mark by mistake - or named in the
    domain's `OPTION_ROWS`, for a row the kit leaves unmarked entirely.
    """
    de = field(row, index, "de")
    if de and de in option_ids:
        return True
    raw_dtype = types.get(de) or field(row, index, "dtype")
    mct = choice_type(field(row, index, "mct")) or choice_type(raw_dtype)
    dtype = data_type(raw_dtype)
    return mct == OPTION_ROW and dtype != "Coding"


def read_annex_a(
    path: Path,
    tabs: list[str],
    types: dict[str, str] | None = None,
    duplicate_des: list | None = None,
    orphaned_options: list | None = None,
    option_group_headings: list | None = None,
    relabelled_options: list | None = None,
    terminology_continuations: list | None = None,
    unnumbered_duplicates: list | None = None,
    option_ids: frozenset[str] | None = None,
    cross_references: list | None = None,
    unresolved_references: list | None = None,
    option_sources: dict[str, str] | None = None,
    sourced_options: list | None = None,
    group_source: str = "",
    group_references: list | None = None,
    classifications: dict | None = None,
    classification_groups: list | None = None,
    nested_lists: list | None = None,
) -> list[dict]:
    """Return the parent elements of the given tabs, each with its input options attached.

    Category dividers come back in the same stream: the ANC and PNC kits both break a tab into
    sections with a heading row, and on a tab whose 90 elements share a single activity that
    heading is the only sub-structure there is.
    """
    types = types or {}
    option_ids = frozenset(option_ids or ())
    workbook = load_workbook(path, read_only=True, data_only=True)
    # A shared tab is parsed once and indexed by data element id, then read by every process tab
    # that references it. `parsing` guards a kit whose shared tab cross-references back.
    definitions: dict[str, dict[str, dict]] = {}
    parsing: set[str] = set()

    def definitions_for(tab: str) -> dict[str, dict]:
        if tab not in definitions:
            if tab in parsing or tab not in workbook.sheetnames:
                return {}
            definitions[tab] = {
                element["de"]: element for element in parse(tab) if not element.get("divider") and element["de"]
            }
        return definitions[tab]

    # The same tab read as groups rather than as elements: a kit may define a cluster of
    # questions once, head it with an untyped row carrying an id, and reference the cluster by
    # that id from every process that collects it.
    group_definitions: dict[str, dict[str, list[dict]]] = {}

    def groups_for(tab: str) -> dict[str, list[dict]]:
        if tab not in group_definitions:
            if tab in parsing or tab not in workbook.sheetnames:
                return {}
            groups: dict[str, list[dict]] = {}
            heading = None
            for element in parse(tab):
                if element.get("divider"):
                    heading = element.get("de") or None
                    if heading:
                        groups[heading] = []
                elif heading:
                    groups[heading].append(element)
            group_definitions[tab] = groups
        return group_definitions[tab]

    def parse(tab: str) -> list[dict]:
        parsing.add(tab)
        elements: list[dict] = []
        rows = list(workbook[tab].iter_rows(values_only=True))
        head = header_row(rows, tab)
        index = column_index(rows[head])
        # A row the dictionary leaves unlabelled holds nothing, so the labelled rows are the tab.
        # Read as a list rather than a stream because a heading is classified by what follows it.
        body = [row for row in rows[head + 1 :] if field(row, index, "label")]
        parent = None
        activity = ""
        seen: set[str] = set()
        # Every list-parent seen so far on this tab, by the label a later row names it under. A
        # kit that says which list each row belongs to is read against this rather than against
        # the row order - see `owner`.
        lists: dict[str, dict] = {}

        def owner(named: str):
            """The element whose value set this row belongs to: the one it names, or the open one.

            Most kits say nothing about where an option belongs and the open parent is all there
            is. The SRV and BDS kits both name the list in a column of their own, and for the BDS
            kit that column is load-bearing: it nests its anomaly value set three deep, so the
            row above an option is often a sibling list rather than its parent. `Microcephaly`
            follows the last of the ten spina bifida values and belongs to `Central nervous
            system defects`, two levels up; read positionally it becomes an eleventh kind of
            spina bifida.

            The name wins only when it resolves to a list-parent already read on this tab. That
            is what keeps the SRV kit's three rows naming an `Admission type` it never defines,
            and the BDS kit's use of the same column for a functional grouping - `Newborn death`
            heads a date and an autopsy flag, and is a Boolean rather than a list - falling back
            to the row order they were already read under.
            """
            return lists.get(named) or parent

        for cursor, row in enumerate(body):
            label = field(row, index, "label")
            activity = activity_text(row, index) or activity
            de = field(row, index, "de")
            # The dictionary's own words are carried through to the crosswalk, and every decision
            # below reads the normalised pair, so a kit's spelling stays a spelling rather than
            # becoming a case of its own.
            raw_mct = field(row, index, "mct")
            raw_dtype = types.get(de) or field(row, index, "dtype")
            # A kit with no multiple-choice column of its own states the choice in the data
            # type, so that cell answers for it where it is absent. The fallback is reached
            # only on a row whose own column said nothing.
            mct = choice_type(raw_mct) or choice_type(raw_dtype)
            dtype = data_type(raw_dtype)
            required = field(row, index, "required")
            option = field(row, index, "option")

            # An element the kit defines once on a shared tab and references from each process
            # that collects it. The reference row carries this process's own `Required` flag and
            # conditionality; the definition carries the type, the options and the description.
            # Merging the two is the only reading that leaves the question answerable *and* keeps
            # the flag the process gave it - reading the reference row literally yields a
            # free-text box with the kit's answer list stripped off.
            reference = CROSS_REFERENCE.match(raw_mct)
            if reference:
                definition = definitions_for(reference.group(1).strip()).get(de)
                # A reference this reader drops closes the open parent, for the same reason the
                # typed-duplicate check below does: any `Input Option` rows the dictionary meant
                # for the dropped row would otherwise attach to whichever earlier element still
                # held the parent slot, which is a misattachment rather than a visible gap.
                if definition is None:
                    parent = None
                    if unresolved_references is not None:
                        unresolved_references.append((tab, de, label))
                    continue
                if de in seen:
                    parent = None
                    if duplicate_des is not None:
                        duplicate_des.append((tab, de, label))
                    continue
                seen.add(de)
                shared = dict(definition)
                shared.update(
                    {
                        "tab": tab,
                        "activity": activity,
                        # `TB.Comm.DE.57 Symptoms of TB` is `C` on screening and `R` on
                        # diagnosis, so the process's flag wins; where the reference row leaves a
                        # column blank the definition's own value stands.
                        "required": required or definition["required"],
                        "conditionality": field(row, index, "conditionality") or definition["conditionality"],
                        "indicators": field(row, index, "indicators") or definition["indicators"],
                        # Copied, because one definition is referenced from several tabs and
                        # `resolve_option_strings` rewrites option rows in place.
                        "options": [dict(child) for child in definition["options"]],
                        "sharedFrom": definition["tab"],
                    }
                )
                elements.append(shared)
                if cross_references is not None:
                    cross_references.append((tab, de, definition["tab"]))
                # A referenced element owns options on the same terms as one defined in place, so
                # it takes the parent slot rather than leaving an earlier element holding it: a
                # process tab that adds an `Input Option` row of its own after the reference means
                # it for the element it just named.
                if shared["dtype"] == "Coding" or shared["mct"] in MULTIPLE_CHOICE_PARENTS:
                    parent = shared
                continue

            # A cluster of questions the kit defines once on a shared tab and references by the
            # id of the row heading it. The CHE kit reads the respiratory rate as five questions -
            # the count, whether it could be taken, a second count, whether that was possible, and
            # the fast-breathing conclusion - defines them under `CHE.B24.DE01` on its group tab,
            # and names that id from the sign tabs for either age band and from its assessment
            # tab. It marks the reference three ways, `Group questions`, `Group question` and
            # `N/A`, so what identifies one is the id resolving to a group rather than the type
            # spelling beside it; the row read literally is one free-text box where five questions
            # belong.
            #
            # Unlike a `CROSS_REFERENCE`, which names one element and takes the process's own
            # flag, this names a cluster whose members each carry their own. The reference row's
            # label heads them, which is the only thing that row holds that the group does not.
            if de and tab != group_source and de in groups_for(group_source):
                if de in seen:
                    parent = None
                    if duplicate_des is not None:
                        duplicate_des.append((tab, de, label))
                    continue
                seen.add(de)
                elements.append({"tab": tab, "activity": activity, "divider": label, "de": de, "group": True})
                parent = None
                for member in groups_for(group_source)[de]:
                    if member["de"] and member["de"] in seen:
                        continue
                    if member["de"]:
                        seen.add(member["de"])
                    grouped = dict(member)
                    grouped.update(
                        {
                            "tab": tab,
                            "activity": activity,
                            # Copied, because one group is referenced from several tabs and
                            # `resolve_option_strings` rewrites option rows in place.
                            "options": [dict(child) for child in member["options"]],
                            "sharedFrom": group_source,
                        }
                    )
                    elements.append(grouped)
                    if grouped["dtype"] == "Coding" or grouped["mct"] in MULTIPLE_CHOICE_PARENTS:
                        parent = grouped
                if group_references is not None:
                    group_references.append((tab, de, group_source, len(groups_for(group_source)[de])))
                continue

            # A row the dictionary gives neither a data type nor a multiple-choice type holds no
            # answer, so it is a section heading - `ANC.B9.DE32 "HIV test"` heads the three
            # HIV-test elements after it, and `PNC.B4a.DE.13 "Height and weight"` heads height,
            # weight and BMI. An id and a `Required` flag do not make it an element: the PNC kit
            # marks its headings Required, and a kit that leaves a *real* element untyped names it
            # in the domain's `ELEMENT_TYPES`, which supplies the type and lifts it out of here.
            # The id is carried so the run can report what it swallowed.
            #
            # A heading also closes whatever `Coding` parent was still open. Without this,
            # `PNC.B4b.DE.52 "Malformation"` stays the open parent straight through the "Vital
            # signs and measurements" divider and eight Quantity rows, and silently absorbs the
            # unrelated stray option `PNC.B4b.DE.71 "Not feasible to collect measurement"` as one
            # of its own. The dictionary gives that option no `Coding` parent of its own to attach
            # to, so it is orphaned rather than misattached - reported like every other dictionary
            # defect this generator catches.
            if not dtype and not mct:
                # An input option the dictionary marks as nothing at all: no type, no `Input
                # Option`, nothing but a label under the question it belongs to. The FP and PNC
                # kits mismark theirs and are recoverable by rule; this kit leaves `TB.C3.DE.1
                # Risk of MDR-TB`'s "High" and "Low" and the last sample type bare, and a bare
                # row is indistinguishable from a section heading. Only the domain can say
                # which it is, so `OPTION_ROWS` names them and the divergence stays reviewable.
                if de and de in option_ids:
                    holder = owner(field(row, index, "list"))
                    if holder is not None:
                        # The same option-string rule the typed rows get below: the `Input
                        # Options` cell, or the label where the kit leaves it blank or "N/A".
                        holder["options"].append(
                            {
                                "tab": tab,
                                "de": de,
                                "label": label,
                                "option": option_text(option, label),
                            }
                        )
                    elif orphaned_options is not None:
                        orphaned_options.append((tab, de, label))
                    continue
                # A row that only repeats the label directly above it continues that element
                # rather than heading anything: the FP kit spreads `FP.A.DE11 Age (coded to ICD
                # groupings)` over five rows, one per ICD-11 age band, and the four after the
                # first hold a terminology code and nothing else. Read as headings they leave a
                # section called "Age (coded to ICD groupings)" standing over `Sex`, which is
                # the next question the selection rule keeps. The open parent is left alone,
                # since a continuation is part of the row before it.
                if cursor and label == field(body[cursor - 1], index, "label"):
                    if terminology_continuations is not None:
                        terminology_continuations.append((tab, de, label))
                    continue
                # Unless it heads a stretch of the open parent's own options. The FP kit groups
                # one element's option list with these headings - `FP.B.DE257 Health condition(s)`
                # carries 154 options under 21 of them, `Diabetes`, `Hypertension`, `Liver
                # disorders` - so closing the parent there orphans every option past the first
                # heading and leaves a mandatory Select-all as a free-text box. Tamanu has no
                # option-group construct, so the grouping is dropped and the options land as one
                # flat list; the run reports each heading it swallowed this way.
                #
                # What separates the two cases is what comes next, not the heading itself: an
                # option row means the list is still open, a typed element means the heading
                # introduces the section the PNC kit uses it for.
                if (
                    parent is not None
                    and cursor + 1 < len(body)
                    and is_option_row(body[cursor + 1], index, types, option_ids)
                ):
                    if option_group_headings is not None:
                        option_group_headings.append((tab, parent["de"], label))
                    continue
                elements.append({"tab": tab, "activity": activity, "divider": label, "de": de})
                parent = None
                continue

            # The same element stated twice, numbered only on the second row. The CHE kit writes
            # `Reason for consultation` as a `Coding` / `Select one` row with no id, and then
            # again as `CHE.B3.DE01` with the same label, the same type and the same options
            # cell. Both rows are typed, so neither the heading rule nor the repeated-id rule
            # reaches them: the first takes the parent slot, the second takes it back, the three
            # option rows attach to the second, and the first imports as a mandatory free-text
            # box beside the real question because a `Coding` row with no options degrades to one.
            #
            # The row carrying the id is the one kept, since it is the one an indicator or a
            # decision rule can name. Narrow by construction - the rows must be adjacent, share a
            # label, the first must be the unnumbered one, and it must not be an input option:
            # an unmarked option repeating the label of the numbered row after it is a value of
            # some question, and dropping it would take an answer off a form rather than a
            # duplicate question off one.
            if not de and mct != OPTION_ROW and cursor + 1 < len(body):
                following = body[cursor + 1]
                if field(following, index, "de") and field(following, index, "label") == label:
                    if unnumbered_duplicates is not None:
                        unnumbered_duplicates.append((tab, field(following, index, "de"), label))
                    continue

            # An option row the kit marks with its parent's own multiple-choice type instead of
            # as an input option. The CHE kit does it 16 times: `CHE.B7.DE03A Select all danger
            # signs that apply` is `Coding` / `Select all that apply`, and the five options under
            # it - convulsions in this illness, unconscious or lethargic, not able to drink or
            # breastfeed - are typed `Codes` and carry `Select all that apply` as well. Read as
            # written, the danger-sign list imports with no options at all and the five options
            # become mandatory-looking questions of their own, which is the damage the `Input
            # Option` casing rule already exists to prevent.
            #
            # `Codes` is the type an option row carries, so such a row was never a question; what
            # identifies the mismark is that it repeats the mark of the parent still open above it
            # rather than carrying one of its own.
            if dtype == "Codes" and parent is not None and mct and mct == parent["mct"]:
                mct = OPTION_ROW

            record = {
                "tab": tab,
                "de": de,
                "label": label,
                "description": field(row, index, "description"),
                "activity": activity,
                "subcategory": field(row, index, "subcategory"),
                "dtype": dtype,
                "mct": mct,
                "rawDtype": raw_dtype,
                "rawMct": raw_mct,
                "subtype": field(row, index, "subtype"),
                "required": required,
                "conditionality": field(row, index, "conditionality"),
                "indicators": field(row, index, "indicators"),
                "options": [],
                "option": option_text(option, label),
            }
            # A row typed `Coding` is a parent whatever the multiple-choice column says. Options
            # are typed `Codes`, or `String` for an "Other (specify)", so a `Coding` row marked
            # `Input Option` is a mis-marked parent rather than an option. `HIV.E.DE168 HIV test
            # type` is the only one in these kits, and reading it as an option silently dropped
            # both it and its four assay options from the HIV forms.
            if mct == OPTION_ROW and dtype != "Coding":
                holder = owner(field(row, index, "list"))
                if holder is not None:
                    holder["options"].append(record)
                elif orphaned_options is not None:
                    orphaned_options.append((tab, de, label))
                continue
            # An id repeated on one tab, both rows typed, keeps the first and drops the second - a
            # dictionary defect this generator has not seen fire yet, since neither kit repeats a
            # typed row's id. (An untyped twin, like `ANC.B6.DE14`'s "Gestational age" heading over
            # the same id's real date element, is already a divider by the time we get here and
            # never reaches this check at all.) Dropping the row resets `parent`: without that, any
            # `Input Option` rows meant for the discarded row would silently attach to whichever
            # earlier element still held the parent slot.
            if de and de in seen:
                parent = None
                if duplicate_des is not None:
                    duplicate_des.append((tab, de, label))
                continue
            if de:
                seen.add(de)
            elements.append(record)
            # Only an option-owning row becomes the parent, and it stays open across whatever the
            # dictionary interleaves until the next one takes over. Both kits need this:
            # `ANC.B6.DE145 Current alcohol and/or other substance use` has a Boolean between it
            # and its six options, and `ANC.B7.DED9 Persistent behaviours` has three in the middle
            # of its five. Letting a plain element become the parent leaves the real one with no
            # options, whereupon `tamanu_type` degrades a mandatory Select-all into a mandatory
            # free-text box - and a check comparing the generated spec against this same parse
            # cannot see it, because both sides agree. The dictionary's row order is the only
            # witness.
            if dtype == "Coding" or mct in MULTIPLE_CHOICE_PARENTS:
                # A list that names another list is one of that list's own values as well as a
                # question in its own right. The BDS kit's anomaly value set is three deep -
                # `Congenital anomaly diagnosis` offers ten body-system groups, `Central nervous
                # system defects` offers `Encephalocele`, and `Encephalocele` offers the eight
                # sites - and each level is a row typed as a list. Carried only as questions, the
                # mandatory top of that tree has no values at all and degrades to a free-text
                # box; carried only as values, the eight sites have no question to sit on. It is
                # both, so it is recorded as both, and `nestedIn` lets the caller show the child
                # question only when its value is picked.
                nested = lists.get(field(row, index, "list"))
                if nested is not None and nested is not record:
                    nested["options"].append(record)
                    record["nestedIn"] = nested["de"]
                    if nested_lists is not None:
                        nested_lists.append((tab, de, label, nested["de"]))
                lists.setdefault(label, record)
                parent = record
        parsing.discard(tab)
        return elements

    elements: list[dict] = []
    for tab in tabs:
        elements += parse(tab)
    # An element whose value set the kit publishes as a tab of its own rather than as option
    # rows beneath it. `IMMZ.D.DE.19 Vaccine type` is `Coding`, `Select all that apply` and
    # mandatory, and carries no options at all: the IMMZ kit puts its 34 values on
    # `IMMZ.Z Vaccine library`, one row per vaccine family. Without them the element degrades to
    # free text, and every one of that kit's coverage indicators counts
    # `"Vaccine type" = "BCG vaccines"` against a string a health worker would have to type.
    #
    # Both halves of the pointer are the domain's own claim about the dictionary, so neither
    # missing its target is survivable: an unread tab or a renumbered id leaves the element with
    # the empty option list it started with, which is the free-text box this exists to prevent.
    for element_id, source_tab in (option_sources or {}).items():
        values = [value for value in definitions_for(source_tab).values() if value["label"]]
        if not values:
            raise SystemExit(
                f"ERROR: OPTION_SOURCES gives {element_id} its value set from {source_tab!r}, "
                "which this workbook does not have as a tab or which holds no labelled rows. "
                "Check the tab name against the dictionary."
            )
        targets = [element for element in elements if element["de"] == element_id]
        if not targets:
            raise SystemExit(
                f"ERROR: OPTION_SOURCES names {element_id}, which is on none of the tabs read. "
                "The id is the dictionary's own, so a miss means the kit has renumbered it."
            )
        for element in targets:
            element["options"] = [
                {"tab": source_tab, "de": value["de"], "label": value["label"], "option": value["label"]}
                for value in values
            ]
        if sourced_options is not None:
            sourced_options.append((element_id, source_tab, len(values)))
    # A kit that states each of its classifications as a row of its own rather than as one
    # element with a value set. The CHE kit puts 72 `Derived` rows on `CHE.B23.Classification`,
    # each a classification its algorithm concludes, and groups them by the subcategory naming the
    # assessment that reaches it. Read as conclusions they all drop, and every one of that kit's
    # 33 Annex C indicators counts a classification by name - `COUNT of consultations ... with
    # "Pneumonia" classification recommended` - so the program would compute none of them.
    #
    # A health worker following IMCI records the classification, so it is carried as a question
    # they answer: one question per group, the group's own classification labels as its options,
    # which are the strings the indicators quote. The domain names the groups because the
    # dictionary's subcategory values are prose, and because a group it has not named is a
    # classification with nowhere to go rather than something to pass over.
    if classifications:
        source = classifications["tab"]
        concluded = classifications["dataType"]
        by_group: dict[str, list[dict]] = {}
        for element in elements:
            if element["tab"] != source or element.get("divider") or element["dtype"] != concluded:
                continue
            by_group.setdefault(element["subcategory"], []).append(element)
        unnamed = sorted(group for group in by_group if group not in classifications["groups"])
        if unnamed:
            raise SystemExit(
                f"ERROR: CLASSIFICATIONS does not name {len(unnamed)} of the groups holding "
                f"{concluded!r} rows on {source!r}: {unnamed}. A group with no question to carry "
                "it is a classification no indicator can count, so either name it or the kit has "
                "been revised."
            )
        for group, label in classifications["groups"].items():
            members = by_group.get(group, [])
            if not members:
                raise SystemExit(
                    f"ERROR: CLASSIFICATIONS names the group {group!r} on {source!r}, which holds "
                    f"no {concluded!r} row. The value is the dictionary's own, so a miss means the "
                    "kit has renamed or renumbered it."
                )
            elements.append(
                {
                    "tab": source,
                    "de": "",
                    "label": label,
                    "description": "",
                    "activity": members[0]["activity"],
                    "subcategory": group,
                    "dtype": "Coding",
                    "mct": "Select all that apply",
                    # The crosswalk shows what the dictionary said about the rows this was built
                    # from, which is that it derives them; there is no row of its own to quote.
                    "rawDtype": concluded,
                    "rawMct": "",
                    "subtype": "",
                    "required": "",
                    "conditionality": "",
                    "indicators": "",
                    "option": "",
                    "options": [
                        {"tab": source, "de": member["de"], "label": member["label"], "option": member["label"]}
                        for member in members
                    ],
                    "derivedFrom": [member["de"] for member in members],
                }
            )
            if classification_groups is not None:
                classification_groups.append((group, label, len(members)))
    workbook.close()
    resolve_option_strings(elements, relabelled_options)
    return elements


def apply_option_labels(elements: list[dict], labels: dict[str, str], applied: list | None = None) -> None:
    """Relabel an option the kit gives a string that already belongs to another of its own.

    `resolve_option_strings` recovers the row's label where the option cell repeats a string.
    That has nothing to fall back on when the repeated string *is* the label and the kit has
    no option column - two rows of one list reading alike, which collapse to a single
    selectable answer and lose the other. The SRV kit does it twice, both on vaccine
    formulations whose labels ran together while their code mappings stayed apart:
    `MENSRV.C6.DE.37` is ATC `J07AH01`, the unconjugated meningococcal A antigen, labelled
    with `DE.46`'s conjugated one.

    The replacement is a string the kit already gives that row - its ATC substance name -
    named in the domain's `OPTION_LABELS` so the source is reviewable rather than invented.
    """
    for element in elements:
        if element.get("divider"):
            continue
        for option in element["options"]:
            replacement = labels.get(option.get("de", ""))
            if not replacement or option["option"] == replacement:
                continue
            if applied is not None:
                applied.append((option.get("de", ""), option["option"], replacement))
            option["option"] = replacement


def resolve_option_strings(elements: list[dict], relabelled: list | None = None) -> None:
    """Fall back to an option row's label where its `Input Options` cell names another option.

    That cell is normally the string a health worker picks, and it is worth preferring: the ANC
    kit populates both columns and they differ for 196 of its 660 options. It cannot be what
    they pick when it repeats a string already on the same question, though - the FP kit gives
    `FP.B.DE452`'s "Home/self-administered" row an `Input Options` of "Referral", the option
    directly above it, and carrying that loses the answer rather than merely mislabelling it,
    because two identical options collapse to one.

    The row's own label is the other string the dictionary gives that row, so nothing is
    invented. Where both columns are already taken the row is left alone and the duplicate is
    reported as before, which is the honest outcome for `PNC.A2.DE.8`'s two "Heartburn" rows:
    the dictionary lists one option twice and says nothing else about either.
    """
    for element in elements:
        if element.get("divider"):
            continue
        taken = set()
        for option in element["options"]:
            if option["option"] in taken and option["label"] not in taken:
                if relabelled is not None:
                    relabelled.append((element["de"], option["option"], option["label"]))
                option["option"] = option["label"]
            taken.add(option["option"])


def selected(
    elements: list[dict],
    domain,
    annotations: list | None = None,
    patient_record: list | None = None,
) -> list[dict]:
    """Include an element that is required, feeds an indicator, or is on the DAK's own shortlist.

    A DAK's process tabs hold far more elements than a form can carry, so the rule is: `Required
    = R`, or linked to an Annex C indicator, or named in the kit's core-elements shortlist. The
    third exists because the first two alone drop clinically central but unreported elements.
    """
    held = getattr(domain, "PATIENT_RECORD", frozenset())
    keep = []
    for element in elements:
        if element.get("divider"):
            keep.append(element)
            continue
        # An element the patient record already holds. A DAK registers its own client because
        # it cannot assume a record exists; Tamanu has one, and collecting a name or a
        # telephone number onto a form as well gives a deployment two places to write it and
        # no rule for which counts. The tab is still read, because the few elements on it
        # that are clinical rather than administrative - the SRV kit's date of onset of first
        # symptoms - are the ones every indicator dates a case from.
        if element["de"] in held:
            if patient_record is not None:
                patient_record.append((element["tab"], element["de"], element["label"]))
            continue
        # A classification question, which the domain claimed and the reader built rather than the
        # dictionary holding a row for it. There is no flag or indicator link on it to select it by.
        if element.get("derivedFrom"):
            element["why"] = "classification"
            keep.append(element)
            continue
        # An element the kit's own logic concludes rather than collects. A form can prompt but
        # not conclude, and there is no answer to store, so it is never carried as a question; the
        # caller reports how many. The PNC kit states 109 of them as `Annotation`, a diagnosis
        # carrying the guidance text that goes with it, where the HIV and ANC kits put their rules
        # in Annex B. The CHE kit states its 72 IMCI classifications as `Derived` and the 28
        # qualifiers of those as `Derived qualifier`, computed from the signs recorded on the
        # tabs before them.
        #
        # A classification is the one conclusion this rule cannot simply drop, because it is what
        # every CHE indicator counts. `CLASSIFICATIONS` recovers those rows as the value set of a
        # question the health worker answers, and the synthesised element is kept below; what
        # falls through to here is the remainder, which no indicator reaches.
        if element["dtype"] in CONCLUSIONS:
            if annotations is not None:
                annotations.append((element["tab"], element["de"], element["label"]))
            continue
        is_required = element["required"] == "R"
        has_indicator = element["indicators"] not in ("", "-")
        is_core = element["tab"] in domain.CORE_TABS and element["de"] in domain.CORE_ELEMENTS
        if is_required or has_indicator or is_core:
            element["why"] = ",".join(
                label
                for label, flag in (("required", is_required), ("indicator", has_indicator), ("core", is_core))
                if flag
            )
            keep.append(element)
    return keep


# A heading code names what the heading is, not where it sits. The DAK numbers its own
# activities - `HIV.E1`, `ANC.B10.5` - so an activity heading takes that id; a section heading,
# which no kit gives an id, takes its own text. A code built from a running index moves every time
# a question is inserted ahead of it, which upserts a new row and strands the old one: nine HIV
# headings shifted when a single dropped question was recovered.
HEADING_SLUG_LIMIT = 40


def heading_slug(text: str, identifier_prefix: str | None = None) -> str:
    """`HIV.E1 Capture or update client history` -> `e1`; `Height and weight` -> `height-and-weight`.

    Given a prefix, the DAK's own activity id is taken when the heading opens with one - which
    is every activity except the handful a kit leaves unnumbered (`ANC.End`, `HIV.Prevention`),
    where the wording is all there is. `None` means the whole text is used, because a section
    heading has no id to take.

    An empty prefix is a kit with an id but nothing to strip off it - the SRV kit, whose
    element ids carry the disease and so keep it. That is still an id, so it is still what
    names the heading: read as `None` instead, the code becomes forty characters of the
    activity's sentence cut mid-word.

    Where the id ends is a kit's own habit. Most separate it from the label with a space, so the
    match stops there; the IMMZ kit joins the two with a dot - `IMMZ.D1.Capture or update client
    history` - which puts the label's first word inside the match. An id segment carries a digit
    and a label word does not, which is what tells `D1.Capture` from `B10.5`.
    """
    source = text or ""
    if identifier_prefix is not None:
        source = re.sub(r"^" + re.escape(identifier_prefix), "", source)
        identifier = re.match(r"\s*([\w.]*\d[\w.]*)", source)
        if identifier:
            segments = identifier.group(1).split(".")
            while len(segments) > 1 and not any(character.isdigit() for character in segments[-1]):
                segments.pop()
            source = ".".join(segments)
    slug = re.sub(r"[^a-z0-9]+", "-", source.lower()).strip("-")
    return slug[:HEADING_SLUG_LIMIT].strip("-") or "heading"


def heading_code(domain, survey_code: str, kind: str, text: str, prefix, used: dict, collisions) -> str:
    """A stable code for one heading, disambiguated only where a kit repeats itself.

    Two activities in one survey can slug alike, because a kit gives two different activities the
    same id - the PNC kit does it four times, once over nothing but a comma. The later one takes a
    numeric suffix in first-appearance order, and the caller reports it rather than letting a
    silent `pde-<code>` collision decide which survives.

    `used` tracks codes already issued, not base counts: counting per base and appending `-N`
    finds a code some other heading already owns by coincidence rather than by collision - `ANC.B10`
    on its second use and a genuinely distinct `ANC.B10.2` both slug through this path to
    `...-act-b10-2`. Searching issued codes instead means a suffix is only ever handed out once.
    """
    base = f"{domain.PROGRAM['codePrefix']}-{survey_code}-{kind}-{heading_slug(text, prefix)}"
    if base not in used:
        used[base] = True
        return base
    suffix = 2
    while f"{base}-{suffix}" in used:
        suffix += 1
    code = f"{base}-{suffix}"
    used[code] = True
    if collisions is not None:
        collisions.append((survey_code, text, code))
    return code


def question_code(element: dict, domain, survey_code: str = "") -> str:
    """HIV.D.DE39 -> whodakhiv-d-de39.

    An id may hold only alphanumerics and `-` ("id must not have spaces or punctuation other than
    -") and the code is embedded in the `pde-<code>` id built from it, so no dots and no
    underscores whatever the looser code rule permits. The cost of hyphens is that a code cannot
    be referenced from a math.js `calculation`, where `a-b` parses as subtraction; a calculated
    question needs a separator-free code of its own.

    An element the dictionary never numbered takes its activity and label instead, the way an
    unnumbered activity's heading takes its wording - the FP kit leaves `Current medications`
    without an id, and `whodakfp-` alone is not a code. No DAK id is invented for it: `_dak`
    records the blank the dictionary gave, and the run reports every element in this position.

    An element the kit defines on a shared tab takes the survey into its code as well:
    `whodaktb-screening-comm-de-3`. A code becomes the global `pde-<code>` id and so may appear
    once per workbook, but the TB kit's `TB.Comm.DE.3 Body weight (kg)` is collected at
    screening, at diagnosis, at every treatment follow-up and again for TPT dosing, and one
    unscoped code would carry it on whichever form was built first and silently drop it from the
    other three. The DAK id is unchanged in `_dak.dataElementId`, so an indicator still reaches
    every copy; what the code says is which contact the weight was taken at.
    """
    de = element["de"]
    if de:
        tail = de.replace(domain.DAK["elementPrefix"], "", 1).lower().replace(".", "-")
    else:
        activity = heading_slug(element["activity"], domain.DAK["elementPrefix"])
        tail = f"{activity}-{heading_slug(element['label'])}"
    if element.get("sharedFrom") and survey_code:
        tail = f"{survey_code}-{tail}"
    return f"{domain.PROGRAM['codePrefix']}-{tail}"


def activity_parts(activity: str) -> list[tuple[str, str]]:
    """The activity ids one dictionary row names, each with the wording that names it.

    Most kits give a tab per process and one activity per row, so this is a single pair. The
    IMMZ kit gives one tab to nine activities and names two of them on the 48 rows either
    process records - `IMMZ.D1.Capture or update client history OR IMMZ.D13.Update client
    record` -
    which is what lets a process in `PROCESSES` be a slice of a tab rather than the whole of it.
    An id is the leading run of dot-separated segments carrying a digit, so a label joined on by
    a dot falls away; a row whose activity is unnumbered names no id and belongs to no slice.

    The wording comes back with the id because a row naming two activities heads a screen on
    each survey that takes it, and that screen wants the half of the cell it was taken for.
    """
    parts: list[tuple[str, str]] = []
    for part in re.split(r"\bOR\b|\n", activity or ""):
        text = part.strip()
        words = text.split()
        if not words:
            continue
        segments = words[0].split(".")
        kept = [segments[0]]
        for segment in segments[1:]:
            if not any(character.isdigit() for character in segment):
                break
            kept.append(segment)
        if len(kept) > 1:
            parts.append((".".join(kept), text))
    return parts


def activity_key(activity: str) -> str:
    """What makes two rows the same activity, whatever the kit typed.

    Activities group by their text, so a kit typing one activity several ways opens a screen for
    each. The CHE kit writes `CHE.A9. Validate child details`, `CHE.A9.Validate child Details` and
    `CHE.A4. Gather child Details OR CHE.A8.Create child Record` on the registration tab alone -
    one activity set, five screens, each claiming a heading code of its own.

    Only case and the spacing around the id's separating dot are levelled, which is the whole of
    what differs between those five. Punctuation is left alone deliberately: the PNC kit gives two
    genuinely different activities the same id and separates them by a comma, and folding that
    away would merge two screens the kit means to keep apart.
    """
    return re.sub(r"\s+", " ", re.sub(r"\.\s*", ". ", activity or "")).strip().lower()


def activity_step(activity: str) -> tuple:
    """Sort key putting activities in DAK process order: HIV.D1, D2, D3, D4, D8, D10 ...

    Annex A's row order is not the process order, so grouping has to be explicit - otherwise one
    activity becomes several separate screens scattered through the form. The sub-step is the ANC
    kit's, which numbers its activities `ANC.B10.1` and, on three rows, `ANC.B.10.6`.
    """
    match = re.match(r"\w+\.([A-Z])\.?(\d+)(?:\.(\d+))?", activity or "")
    if not match:
        return ("Z", 999, 999, activity or "")
    return (match.group(1), int(match.group(2)), int(match.group(3) or 0), activity)


def build_question(element: dict, code: str) -> dict:
    # First occurrence wins, order preserved. A repeated option is fatal at import rather than
    # merely untidy: Tamanu writes one translatable string per option, and two identical ones
    # collide on the `(string_id, language)` primary key inside a single bulk upsert, which
    # Postgres rejects with "ON CONFLICT DO UPDATE command cannot affect row a second time" and
    # which fails the whole workbook. The PNC kit lists "Heartburn" twice under `PNC.A2.DE.8`.
    # The run reports every drop, so a dictionary defect is visible rather than silently absorbed.
    options = list(dict.fromkeys(option["option"] for option in element["options"]))
    qtype = tamanu_type(element["dtype"], element["mct"], bool(options))

    question: dict = {
        "code": code,
        "type": qtype,
        "name": fit(element["label"]),
        "text": fit(element["label"]),
    }
    if element["description"] and element["description"] != element["label"]:
        question["detail"] = fit(element["description"])

    if qtype in ("Radio", "Select", "MultiSelect"):
        question["options"] = options
    if qtype == "Number" and element["subtype"].lower().startswith("integer"):
        question["config"] = {"rounding": 0}  # Annex A distinguishes integer from decimal
    if element["required"] == "R":
        question["validationCriteria"] = {"mandatory": True}

    question["_dak"] = {
        "dataElementId": element["de"],
        "activity": element["activity"],
        "dataType": element["rawDtype"],
        "multipleChoiceType": element["rawMct"],
        "required": element["required"],
        "selectedBecause": element["why"],
        "indicators": element["indicators"],
    }
    # Only where the kit has one, so a domain whose dictionary defines every element in place
    # carries no empty key for a structure it does not use.
    if element.get("sharedFrom"):
        question["_dak"]["definedOn"] = element["sharedFrom"]
    # A question built from a group of the kit's own rows rather than read off one, so the
    # crosswalk names the rows instead of the single id it has not got.
    if element.get("derivedFrom"):
        question["_dak"]["derivedFrom"] = element["derivedFrom"]
    return question


def build_questions(
    elements: list[dict],
    survey_code: str,
    seen_codes: set[str],
    domain,
    dropped: list | None = None,
    collisions: list | None = None,
) -> list[dict]:
    # one screen per distinct activity, activities in process order, Annex A's row order kept
    # within each activity
    activities: dict[str, list[dict]] = {}
    wording: dict[str, str] = {}
    for element in elements:
        key = activity_key(element["activity"])
        activities.setdefault(key, []).append(element)
        # The first wording the kit used for this activity names the screen, so the heading reads
        # as the dictionary wrote it rather than as a normalised key.
        wording.setdefault(key, element["activity"])

    questions: list[dict] = []
    used_headings: dict[str, int] = {}
    # The code each element was emitted under on this survey, so a question nested inside another
    # question's value set can be shown only when that value is picked.
    code_by_de: dict[str, str] = {}
    for key in sorted(activities, key=lambda k: activity_step(wording[k])):
        activity = wording[key]
        # The screen is built before its heading is, so an activity the selection rule empties
        # opens no screen at all. The ANC kit needs this at both ends: it opens a tab with a
        # divider that precedes the first `Activity ID`, which would otherwise head an untitled
        # screen the importer rejects, and it groups elements under activities that can select
        # down to nothing.
        screen: list[dict] = []
        # A divider is held until an element under it is actually emitted, so a section the
        # selection rule empties does not leave a heading standing over the section after it.
        pending = None
        for element in activities[key]:
            if element.get("divider"):
                pending = element["divider"]
                continue
            code = question_code(element, domain, survey_code)
            # `pde-<code>` is a global upsert key, so a code may appear once per workbook. A
            # collision would silently rebind an existing question, so guard rather than assume.
            #
            # This is not hypothetical: HIV.D Care-Treatment and HIV.D HIV-TB share the HIV.D.DE*
            # id space, so an element Annex A lists on both lands on the first survey built and
            # is absent from the second. The caller reports what was dropped, because a question
            # missing from a form is not something to discover from a row count.
            if code in seen_codes:
                if dropped is not None:
                    dropped.append((survey_code, element["de"], code))
                continue
            seen_codes.add(code)
            if element["de"]:
                code_by_de[element["de"]] = code
            if pending is not None:
                # Held as a marker and given its code only if the screen survives, so a section
                # inside a screen the selection rule empties cannot claim a name from a later one.
                screen.append({"_section": pending})
                pending = None
            question = build_question(element, code)
            # A question that is also one of another question's options is asked only when that
            # option is picked. The gate is exact rather than inferred: the value is the very
            # string this element was appended to its parent's list as, so it cannot fail to
            # match. Ungated, the BDS kit's diagnosis form shows all ten body-system groups and
            # every sub-list under them at once - twenty-eight questions for a case that has one
            # anomaly - and a Select-all with no gate says all of them are being asked.
            #
            # Only where the parent is on this survey too. A parent the selection rule dropped
            # leaves the child standing on its own, which is the honest reading: there is no
            # answer that could reveal it.
            nested_in = code_by_de.get(element.get("nestedIn") or "")
            if nested_in:
                question["visibilityCriteria"] = {"_conjunction": "and", nested_in: element["option"]}
            screen.append(question)

        if not any("_section" not in entry for entry in screen):
            continue
        heading = re.sub(r"^(\w+\.[\w./]*\d+)\.?\s*", "", activity).strip() or activity
        questions.append(
            {
                "code": heading_code(
                    domain, survey_code, "act", activity, domain.DAK["elementPrefix"], used_headings, collisions
                ),
                "type": "Instruction",
                "name": heading[:60],
                "text": fit(heading),
                "detail": fit(activity),
                "newScreen": len(questions) > 0,
            }
        )
        for entry in screen:
            if "_section" in entry:
                questions.append(
                    {
                        "code": heading_code(
                            domain, survey_code, "sec", entry["_section"], None, used_headings, collisions
                        ),
                        "type": "Instruction",
                        "name": entry["_section"][:60],
                        "text": fit(entry["_section"]),
                    }
                )
            else:
                questions.append(entry)

    return gate_other_specify(questions)


def gate_other_specify(questions: list[dict]) -> list[dict]:
    """Show an "Other (specify)" free-text question only when its parent's Other option is picked.

    Applied only where it is mechanically safe: a String element whose label starts with "Other",
    where the preceding coded question has an option that also starts with "Other". Annex A's
    wider conditionality is prose in `Explain Conditionality` and is not encoded.
    """
    for n, question in enumerate(questions):
        if question["type"] != "FreeText" or not question["name"].lower().startswith("other"):
            continue
        for previous in reversed(questions[:n]):
            if previous["type"] not in ("Radio", "Select", "MultiSelect"):
                continue
            other = next((option for option in previous.get("options", []) if norm(option).startswith("other")), None)
            if other:
                question["visibilityCriteria"] = {"_conjunction": "and", previous["code"]: other}
            break
    return questions


def add_decision_support(questions: list[dict], survey_code: str, domain) -> list[dict]:
    """Insert Annex B guidance prompts directly after the questions that trigger them.

    Placed immediately after the trigger so the prompt appears on the same screen as the answer
    that raised it - guidance on a later page is guidance the clinician has already walked past.
    Each addition is marked `_decisionSupport` so it is never mistaken for a DAK data element: it
    stores no reportable answer and has no data element id.
    """
    # A rule names its trigger by data element id, which is the kit's own handle for it. A
    # question the reader built rather than read off a row has no such id - the CHE
    # classifications are one question per group of the dictionary's rows - so a rule may name
    # one by question code instead, and both resolve through here.
    by_de = {q["_dak"]["dataElementId"]: n for n, q in enumerate(questions) if q.get("_dak")}
    by_de.pop("", None)
    for n, question in enumerate(questions):
        by_de.setdefault(question["code"], n)
    additions: list[tuple[int, dict]] = []

    for rule in domain.DECISION_SUPPORT:
        if rule["survey"] != survey_code:
            continue
        anchor = by_de.get(rule["after"])
        if anchor is None:
            continue  # the trigger was not selected into this form; skip rather than guess

        gate: dict = {"_conjunction": "and"}
        resolvable = True
        for de, condition in rule["gate"].items():
            if de not in by_de:
                resolvable = False
                break
            target = questions[by_de[de]]
            # A gate value that does not exactly match one of the target's DAK options never
            # fires, and nothing complains - the guidance would silently never appear. So a
            # mismatch is an error here rather than a surprise in the clinic. One value or a
            # list of them alike: a single string is the commoner form and the one a kit's own
            # near-miss spelling hides in. Only a question that carries an option list can be
            # checked - a Binary gates on Yes/No and a Number on a range, neither of which the
            # spec writes as options.
            values = condition if isinstance(condition, list) else [condition]
            if target.get("options") and all(isinstance(value, str) for value in values):
                unknown = [value for value in values if value not in target["options"]]
                if unknown:
                    raise SystemExit(
                        f"ERROR: decision support {rule['rule']} gates on {unknown}, which are "
                        f"not options of {de} ({target['code']}). Annex A's option labels are "
                        "the only values that can match."
                    )
            gate[target["code"]] = condition
        if not resolvable:
            continue

        additions.append(
            (
                anchor,
                {
                    "code": rule["code"],
                    "type": "Instruction",
                    "name": rule["name"],
                    "text": rule["guidance"],
                    "detail": f"WHO DAK decision support {rule['rule']}",
                    "visibilityCriteria": gate,
                    "_decisionSupport": {"rule": rule["rule"], "source": "Annex B"},
                },
            )
        )
        if rule.get("issue"):
            additions.append(
                (
                    anchor,
                    {
                        "code": rule["code"] + "-issue",
                        "type": "PatientIssue",
                        "name": rule["name"],
                        "text": rule["name"],
                        "config": rule["issue"],
                        "visibilityCriteria": gate,
                        "_decisionSupport": {"rule": rule["rule"], "source": "Annex B"},
                    },
                )
            )

    # Grouped by anchor and spliced, rather than inserted one at a time. Inserting each
    # addition at anchor + 1 reverses the group: a rule's guidance Instruction is built before
    # its PatientIssue, so inserting both at the same point puts the issue first. Descending
    # anchor order keeps earlier anchors valid while later ones are still being spliced.
    by_anchor: dict[int, list] = {}
    for anchor, question in additions:
        by_anchor.setdefault(anchor, []).append(question)

    for anchor in sorted(by_anchor, reverse=True):
        questions[anchor + 1 : anchor + 1] = by_anchor[anchor]
    return questions


def main() -> int:
    # The reports below quote the dictionary, and a dictionary is not ASCII: the CHE kit names two
    # tabs `CHE.B10-14.Symptoms ≥2 mths` and `CHE.B18-21.Signs <2 mths`, and every kit's labels
    # carry en dashes. A console that cannot encode one raises part-way through the summary,
    # after the spec has already been written - a run that worked, reported as a traceback.
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--domain",
        required=True,
        help="DAK domain to generate: a directory beside this script holding domain.py",
    )
    parser.add_argument(
        "--annex-a",
        type=Path,
        help="Override the Annex A path (default: <domain>/annexes/<the domain's filename>)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        help="Path to write the JSON spec (default: <domain>/who-dak-<domain>_program.json)",
    )
    parser.add_argument(
        "--no-decision-support",
        action="store_true",
        help="Omit the Annex B guidance prompts, generating from the data dictionary alone",
    )
    args = parser.parse_args()

    domain = load_domain(args.domain)
    annex_a = domain.ANNEXES["A"]
    path = args.annex_a or (DOMAINS_DIR / args.domain / "annexes" / annex_a["filename"])
    out = args.out or (DOMAINS_DIR / args.domain / f"who-dak-{args.domain}_program.json")

    if not path.exists():
        print(
            f"ERROR: Annex A not found at {path}\n\n"
            "The annexes are not committed - third-party spreadsheets WHO publishes at stable "
            "URLs. Fetch it with:\n\n"
            # Quoted and forward-slashed: a kit's filename holds spaces - `CCC DAK_core data
            # dictionary.xlsx` - and an unquoted one truncates the `-o` argument.
            f'    mkdir -p "{Path(path).parent.as_posix()}"\n'
            f'    curl -sL -o "{Path(path).as_posix()}" \\\n        {annex_a["url"]}\n',
            file=sys.stderr,
        )
        return 2

    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != annex_a["sha256"]:
        print(
            "WARNING: Annex A checksum differs from the copy these artefacts came from.\n"
            f"  expected {annex_a['sha256']}\n"
            f"  found    {digest}\n"
            "WHO may have revised the annexe. Review the regenerated spec before shipping it.\n",
            file=sys.stderr,
        )

    spec = {
        "programName": domain.PROGRAM["programName"],
        "programCode": domain.PROGRAM["programCode"],
        "country": "",
        "homeServer": "",
        "registry": domain.REGISTRY,
    }

    surveys, sheets, rows = [], [], []
    seen_codes: set[str] = set()
    all_questions: list[dict] = []
    dropped: list[tuple[str, str]] = []
    collisions: list[tuple[str, str, str]] = []

    # one pass over the workbook, not one per process: it is ~1 MB and the tabs are read whole
    duplicate_des: list[tuple[str, str, str]] = []
    orphaned_options: list[tuple[str, str, str]] = []
    annotations: list[tuple[str, str, str]] = []
    option_group_headings: list[tuple[str, str, str]] = []
    relabelled_options: list[tuple[str, str, str]] = []
    option_labels_applied: list[tuple[str, str, str]] = []
    patient_record_held: list[tuple[str, str, str]] = []
    terminology_continuations: list[tuple[str, str, str]] = []
    unnumbered_duplicates: list[tuple[str, str, str]] = []
    cross_references: list[tuple[str, str, str]] = []
    unresolved_references: list[tuple[str, str, str]] = []
    sourced_options: list[tuple[str, str, int]] = []
    group_references: list[tuple[str, str, str, int]] = []
    classification_groups: list[tuple[str, str, int]] = []
    nested_lists: list[tuple[str, str, str, str]] = []
    elements_by_tab = read_annex_a(
        path,
        # Unique, in declaration order: a kit whose processes are slices of one tab names that
        # tab once per slice, and parsing it per process would carry every element three times.
        list(dict.fromkeys(process["tab"] for process in domain.PROCESSES)),
        getattr(domain, "ELEMENT_TYPES", {}),
        duplicate_des,
        orphaned_options,
        option_group_headings,
        relabelled_options,
        terminology_continuations,
        unnumbered_duplicates,
        frozenset(getattr(domain, "OPTION_ROWS", ())),
        cross_references,
        unresolved_references,
        getattr(domain, "OPTION_SOURCES", {}),
        sourced_options,
        getattr(domain, "GROUP_SOURCE", ""),
        group_references,
        getattr(domain, "CLASSIFICATIONS", None),
        classification_groups,
        nested_lists,
    )

    apply_option_labels(elements_by_tab, getattr(domain, "OPTION_LABELS", {}), option_labels_applied)

    for process in domain.PROCESSES:
        elements = [e for e in elements_by_tab if e["tab"] == process["tab"]]
        # A process is a whole tab unless it names the activities it takes, which is how a kit
        # that packs several processes onto one tab is split into the surveys those processes
        # are. A row either process records reaches both, and the duplicate-code rule below
        # then carries it on the first survey built and reports it as not repeated on the rest.
        if process.get("activities"):
            wanted = set(process["activities"])
            sliced = []
            # One wording per activity id, being the first the kit used for it. A row is taken
            # under the half of its activity cell that named this process, and a kit that words
            # one activity two ways - the CHE kit heads `CHE.B3` both `Determine reason for
            # consultation` and `Determine reason for and type of consultation` - would otherwise
            # open a screen for each and split the activity's questions between them.
            spoken: dict[str, str] = {}
            for element in elements:
                for identifier, wording in activity_parts(element["activity"]):
                    if identifier not in wanted:
                        continue
                    wording = spoken.setdefault(identifier, wording)
                    # Taken under the wording that named it here, so a row naming two activities
                    # heads the same screen as the rows naming only this one. Left as the kit
                    # wrote it, one activity opens two screens differing by the half of the cell
                    # that belongs to the process this survey is not.
                    sliced.append(element if wording == element["activity"] else {**element, "activity": wording})
                    break
            elements = sliced
        chosen = selected(elements, domain, annotations, patient_record_held)
        questions = build_questions(chosen, process["code"], seen_codes, domain, dropped, collisions)
        if not args.no_decision_support:
            questions = add_decision_support(questions, process["code"], domain)
        answerable = [q for q in questions if q["type"] != "Instruction"]
        if not answerable:
            print(f"  skipping {process['tab']}: nothing selected")
            continue

        surveys.append(
            {
                "code": process["code"],
                "name": process["name"],
                "surveyType": process["surveyType"],
                "status": "publish",
                "isSensitive": False,
                "visibilityStatus": "current",
                "notifiable": False,
            }
        )
        sheets.append({"surveyName": process["name"], "questions": questions})
        all_questions += questions
        rows.append(
            (
                process["tab"],
                process["code"],
                len(elements),
                len(chosen),
                len(answerable),
                sum(1 for q in questions if q.get("newScreen")) + 1,
                sum(1 for q in answerable if q.get("options")),
                sum(1 for q in answerable if q.get("validationCriteria")),
                sum(1 for q in answerable if q.get("_dak", {}).get("indicators", "") not in ("", "-")),
            )
        )

    spec["surveys"] = surveys
    spec["surveySheets"] = sheets
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    header = ("tab", "survey", "elems", "sel", "questions", "screens", "coded", "mand", "indic")
    print(
        f"\n{header[0]:22s} {header[1]:14s} {header[2]:>6s} {header[3]:>5s} "
        f"{header[4]:>9s} {header[5]:>7s} {header[6]:>5s} {header[7]:>4s} {header[8]:>5s}"
    )
    for row in rows:
        print(
            f"{row[0]:22s} {row[1]:14s} {row[2]:6d} {row[3]:5d} {row[4]:9d} "
            f"{row[5]:7d} {row[6]:5d} {row[7]:4d} {row[8]:5d}"
        )

    answerable = [q for q in all_questions if q["type"] != "Instruction"]
    coded = [q for q in answerable if q.get("options")]
    indicator_linked = sum(1 for q in answerable if q.get("_dak", {}).get("indicators", "") not in ("", "-"))
    print(
        f"\n{len(surveys)} survey(s), {len(answerable)} answerable questions, "
        f"{sum(1 for q in all_questions if q.get('newScreen')) + len(surveys)} screens, "
        f"{sum(len(q['options']) for q in coded)} DAK options, "
        f"{sum(1 for q in answerable if q.get('validationCriteria'))} mandatory, "
        f"{indicator_linked} indicator-linked"
    )

    prompts = [q for q in all_questions if q.get("_decisionSupport")]
    if prompts:
        print(f"\nAnnex B decision support ({len(prompts)} added):")
        for q in prompts:
            print(f"  {q['_decisionSupport']['rule']:16s} {q['type']:12s} {q['name'][:52]}")

    if dropped:
        print(
            f"\ncarried by an earlier survey, so not repeated here ({len(dropped)}) - a data "
            f"element id may appear once per workbook, because pde-<code> is a global key:"
        )
        for survey_code, element_id, code in dropped:
            print(f"  {element_id:16s} {code:26s} not repeated on {survey_code}")

    if collisions:
        print(
            f"\ntwo headings in one survey with the same name, so suffixed ({len(collisions)}) - the "
            "kit gives them the same activity id under different wording:"
        )
        for _survey_code, text, code in collisions:
            print(f"  {code:44s} {text[:52]}")

    if sourced_options:
        print(
            f"\nvalue set taken from a tab of its own ({len(sourced_options)}) - the kit publishes "
            "these options as a library rather than as option rows under the element:"
        )
        for element_id, source_tab, count in sourced_options:
            print(f"  {element_id:16s} {count:3d} options from {source_tab}")

    if classification_groups:
        print(
            f"\nclassifications carried as one question's value set ({len(classification_groups)}) - "
            "the kit states each as a row of its own, and an indicator counts it by name:"
        )
        for group, label, count in classification_groups:
            print(f"  {label[:38]:38s} {count:3d} from {group[:44]}")

    if nested_lists:
        print(
            f"\nboth a question and one of another question's values ({len(nested_lists)}) - the kit "
            "nests its value set, so each level is asked only when the value above it is picked:"
        )
        for _tab, element_id, label, holder in nested_lists:
            print(f"  {element_id:16s} {label[:44]:44s} inside {holder}")

    if group_references:
        print(
            f"\ndefined as a group on a shared tab and referenced from a process tab "
            f"({len(group_references)}) - the reference row heads the group, whose members carry "
            "their own flags and take the survey into their codes:"
        )
        for tab, element_id, source, count in group_references:
            print(f"  {element_id:16s} {count:3d} questions from {source:28s} on {tab}")

    if cross_references:
        by_tab: dict[str, int] = {}
        for tab, _element_id, source in cross_references:
            by_tab[f"{tab} -> {source}"] = by_tab.get(f"{tab} -> {source}", 0) + 1
        print(
            f"\ndefined on a shared tab and referenced from a process tab ({len(cross_references)}) - "
            "the reference row gives the process's own Required flag, the definition gives the type, "
            "the options and the description, and the question code carries the survey:"
        )
        for pair, count in by_tab.items():
            print(f"  {pair:52s} {count:3d}")

    if unresolved_references:
        print(
            f"\nreferenced a shared tab that defines no such element, so dropped "
            f"({len(unresolved_references)}) - the id on the reference row is not on the tab it names:"
        )
        for tab, element_id, label in unresolved_references:
            print(f"  {element_id:16s} {label[:52]:52s} {tab}")

    if duplicate_des:
        print(
            f"\nan id the dictionary repeats on one tab, both rows typed, so only the first is "
            f"kept ({len(duplicate_des)}):"
        )
        for tab, element_id, label in duplicate_des:
            print(f"  {element_id:16s} {label[:52]:52s} {tab}")

    if orphaned_options:
        print(
            f"\nan input option with no open Coding parent, so dropped ({len(orphaned_options)}) - "
            "a heading closes the parent that was open before it, and this option came after one "
            "with no Coding row of its own in between:"
        )
        for tab, element_id, label in orphaned_options:
            print(f"  {element_id:16s} {label[:52]:52s} {tab}")

    claimed = [
        element
        for element in elements_by_tab
        if element.get("divider") and element.get("de") and not element.get("group")
    ]
    if claimed:
        print(
            f"\nread as a section heading although the dictionary gave them an id ({len(claimed)}) - "
            "no data type and no multiple-choice type, whatever the Required flag says, so there "
            "is nothing to ask. A genuine element here needs the domain's ELEMENT_TYPES:"
        )
        for element in claimed:
            print(f"  {element['de']:16s} {element['divider'][:58]}")

    if terminology_continuations:
        print(
            f"\nrepeating the label of the row above, so read as a continuation of it "
            f"({len(terminology_continuations)}) - no data type, no multiple-choice type and "
            "nothing but a further terminology code, so there is no separate question here:"
        )
        for tab, element_id, label in terminology_continuations:
            print(f"  {element_id:16s} {label[:58]:58s} {tab}")

    if unnumbered_duplicates:
        print(
            f"\nstated twice and numbered only on the second row, so the unnumbered one is "
            f"dropped ({len(unnumbered_duplicates)}) - both rows are typed and carry the same "
            "label, and only the numbered one can be named by an indicator or a decision rule:"
        )
        for tab, element_id, label in unnumbered_duplicates:
            print(f"  {element_id:16s} {label[:58]:58s} {tab}")

    if option_group_headings:
        print(
            f"\nheadings grouping one element's own option list, so dropped ({len(option_group_headings)}) - "
            "an option row follows each, so the list is still open; Tamanu has no option-group "
            "construct, and the options land as one flat list on the parent:"
        )
        for tab, parent_id, label in option_group_headings:
            print(f"  {parent_id or '(unnumbered)':16s} {label[:58]:58s} {tab}")

    if annotations:
        print(
            f"\nconcluded by the kit's own logic rather than collected, so dropped "
            f"({len(annotations)}) - there is no answer to store:"
        )
        for tab, element_id, label in annotations:
            print(f"  {element_id:16s} {label[:58]:58s} {tab}")

    # Both reports below read the crosswalk, which holds the kit's own spelling rather than the
    # canonical type, so each is normalised the same way the reader normalised it. Read raw, a
    # kit that writes `List - select one` where the others write `Coding` matches neither report:
    # every coded element of the SRV and BDS kits is silently exempt from both.
    guessed = [
        q
        for q in answerable
        if q.get("_dak")
        and data_type(q["_dak"]["dataType"]) == "Coding"
        # Neither column said whether more than one answer is allowed. A kit with no
        # multiple-choice column of its own states it in the data type, and `choice_type` reads
        # that cell for it, so a question here is one no column answered for.
        and not (choice_type(q["_dak"]["multipleChoiceType"]) or choice_type(q["_dak"]["dataType"]))
        and q["type"] == "Radio"
    ]
    if guessed:
        print(
            f"\ncoded but with no multiple-choice type, so emitted as single-select ({len(guessed)}) - "
            "the dictionary does not say whether more than one answer is allowed:"
        )
        for q in guessed:
            print(f"  {q['_dak']['dataElementId']:16s} {q['name'][:58]}")

    emitted = {q["_dak"]["dataElementId"] for q in all_questions if q.get("_dak")}
    duplicate_options = []
    for element in elements_by_tab:
        if element.get("divider") or element["de"] not in emitted:
            continue
        seen_values: set[str] = set()
        for option in element["options"]:
            if option["option"] in seen_values:
                duplicate_options.append((element["de"], option["option"]))
            seen_values.add(option["option"])
    if duplicate_options:
        print(
            f"\nrepeated in the dictionary's own option list, so carried once ({len(duplicate_options)}) - "
            "two identical options collide on one translatable string and fail the import:"
        )
        for element_id, value in duplicate_options:
            print(f"  {element_id:16s} {value[:58]}")

    if option_labels_applied:
        print(
            f"\nlabelled with a string already on the same question, so the label the kit's own "
            f"code mapping gives the row is used instead ({len(option_labels_applied)}) - two "
            "identical options collapse to one and lose an answer:"
        )
        # A line each rather than a column pair: the two strings differ only in their tail -
        # `... antigen conjugated` against `... antigen` - and any truncation that fits them
        # side by side prints the same string twice.
        for element_id, was, now in option_labels_applied:
            print(f"  {element_id:18s} {was}")
            print(f"  {'':18s} -> {now}")

    if patient_record_held:
        held_tabs = sorted({tab for tab, _, _ in patient_record_held})
        print(
            f"\nalready held by the patient record, so not collected again "
            f"({len(patient_record_held)} on {', '.join(held_tabs)}) - a form collecting these "
            "would give a deployment two places to write one fact:"
        )
        for _, element_id, label in patient_record_held:
            print(f"  {element_id:18s} {label[:56]}")

    if relabelled_options:
        print(
            f"\nan `Input Options` cell naming another option of the same question, so the row's "
            f"own label is used instead ({len(relabelled_options)}) - carrying the cell would "
            "collapse two answers into one and lose this one:"
        )
        for parent_id, cell_value, label in relabelled_options:
            print(f"  {parent_id:16s} {cell_value[:28]:28s} -> {label[:38]}")

    unnumbered = [q for q in answerable if q.get("_dak") and not q["_dak"]["dataElementId"]]
    if unnumbered:
        print(
            f"\nno data element id in the dictionary, so the code carries the activity and label "
            f"instead ({len(unnumbered)}) - nothing here invents a DAK id, so the crosswalk shows "
            "the blank the kit left:"
        )
        for q in unnumbered:
            print(f"  {q['code']:34s} {q['name'][:58]}")

    untyped = [q for q in answerable if q.get("_dak") and not q["_dak"]["dataType"]]
    if untyped:
        print(
            f"\nno data type in the dictionary, so emitted as free text ({len(untyped)}) - give the "
            f"domain's ELEMENT_TYPES the type its sibling rows imply:"
        )
        for q in untyped:
            print(f"  {q['_dak']['dataElementId']:16s} {q['name'][:58]}")

    country_configured = [
        q
        for q in answerable
        if data_type(q.get("_dak", {}).get("dataType", "")) == "Coding" and q["type"] == "FreeText"
    ]
    if country_configured:
        print(
            f"\ncoded by the DAK but with no option list - needs a local list "
            f"({len(country_configured)}), emitted as free text:"
        )
        for q in country_configured:
            print(f"  {q['_dak']['dataElementId']:16s} {q['name'][:58]}")

    print(f"\nwrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
