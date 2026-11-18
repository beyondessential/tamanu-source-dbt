#!/usr/bin/env python3
"""Report which Web Annex C indicators a DAK's generated forms can compute.

Annex C writes every numerator and denominator in terms of Annex A data elements, quoted:

    COUNT of clients with "HIV status"='HIV-positive' AND "On ART"=True

so the quoted labels are the element list an indicator needs, and the generated spec's question
labels are what a deployment collects. Comparing the two turns "which indicators can we report"
from a judgement into a check, which is the point: the answer changes whenever the element
selection changes, and a stale answer in a README is worse than none.

Usage, from this directory:

    python annex_c_coverage.py --domain hiv
    python annex_c_coverage.py --domain hiv --list covered

Three outcomes per indicator:

  no numerator   Annex C itself says the numerator is not computable from DAK data -- survey
                 based, commodity stock, or another system. Nothing a deployment does changes it.
  not quoted     the computation names no element in quotes, so there is nothing to compare the
                 forms against. Not a gap: the check cannot answer either way. The CHE kit writes
                 18 of its 33 computations as prose, listing the classifications it counts
                 without quoting any of them.
  covered        every element the numerator and denominator quote is a question on a generated
                 form, so the indicator is implementable as it stands.
  gap            an element is missing. That is a form-selection decision to revisit, and the
                 missing labels are printed so it can be.

The match is on the element *label*, because that is what Annex C quotes, and on the option
strings of the questions carrying those elements, because a kit may count a value rather than an
element: the CHE kit's indicators count an IMCI classification by name -- `COUNT of consultations
... with "Pneumonia" classification recommended` -- and a classification is an option there rather
than a question of its own.

A label Annex C writes differently from Annex A will read as a gap: check the printed labels
before concluding an element is absent, and prefer widening the selection to loosening this
comparison.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import openpyxl
from dak_generator import cell, load_domain, norm

# Elements every Tamanu deployment holds on the patient record, so no form has to ask.
FROM_PATIENT_RECORD = {
    "gender",
    "sex",
    "age",
    "date of birth",
    "birth date",
    "visit date",
    "facility",
}


# Annex A's longest element label is comfortably inside this; the bound exists to skip prose
# in quotes rather than to cap real labels, and anything longer is reported rather than dropped.
MAX_LABEL = 120


# A quote in either kind of double quotation mark: the FP kit writes its calculations with
# curly ones, and mixes both inside one indicator - `FP.IND.3` quotes its numerator element
# curly and its denominator element straight.
QUOTE = re.compile(r'["“]([^"”]+)["”]')

# A quote directly after a comparison operator is the value compared against, not an element:
# `"Reason for visit" = "Contraceptive continuation"` names one element and one of its options.
# The HIV kit puts its values in single quotes and so never needs this; the FP kit uses the same
# marks for both, and counting the options as elements makes every such indicator read as a gap.
#
# The TB kit compares against alternatives rather than single values, and writes the alternatives
# as a chain rather than as a set: `("TB treatment history" = "New" OR "Recurrent" OR "Unknown")`
# states one element and three of its options, and every quote after the operator is a value. It
# also writes `!=` where the others write `≠`. So the match runs from the operator to the end of
# the chain, and every quote inside the chain is a value.
#
# The operator list is deliberately punctuation only. A word operator - `in`, `not in` - cannot be
# told from the English preposition, and reading `enrolled in "TB registration"` as a comparison
# sets a real element aside as a value, which is the one direction that turns a gap into a green
# tick. (The TB kit never writes one: across its 51 indicators only `=` and `!=` match.) A kit
# that does needs a form this cannot mistake for prose, not a wider word list.
#
# A quote followed by a comparison operator of its own ends the chain rather than joining it,
# which is what keeps `"A" = "x" OR "B" = "y"` from swallowing `B`. `in` stays in that lookahead,
# where a false positive only ends a chain early and so errs towards reporting an element. A value
# set aside here is still reported when it matches no question, so an element read as a value
# stays visible.
COMPARED_VALUE = re.compile(
    r"(?:[=≠]|!=)\s*"
    r'(["“][^"”]+["”](?:\s*(?:OR|,)\s*["“][^"”]+["”](?!\s*(?:[=≠]|!=|\bin\b)))*)',
    re.IGNORECASE,
)


def quoted_elements(numerator: str, denominator: str) -> tuple[set[str], int, set[str]]:
    """The data element labels an indicator's calculation quotes, how many quotes were too long to
    be a label, and the quotes set aside as the value a comparison compares against.

    A quote this does not check is handed back rather than dropped, for either reason it can go
    unchecked: a label longer than the bound, or a quote on the right of a comparison. Both would
    otherwise make an indicator read "covered" without that element ever being checked - `FP.IND.6`
    compares two elements, `"Chosen method" = "Method or service provided"`, and the right-hand one
    is not distinguishable from an option string.
    """
    text = " ".join(part for part in (numerator, denominator) if part)
    values = {norm(value) for chain in COMPARED_VALUE.findall(text) for value in QUOTE.findall(chain)}
    found, skipped = set(), 0
    for quote in QUOTE.findall(text):
        if len(quote) > MAX_LABEL:
            skipped += 1
            continue
        label = norm(quote)
        # a quoted number is a denominator of 1 or a threshold, not an element
        if label and label not in values and not label.replace(" ", "").isdigit():
            found.add(label)
    return found, skipped, {value for value in values if value and not value.replace(" ", "").isdigit()}


def form_labels(spec_path: Path) -> set[str]:
    """Labels of the questions that carry a DAK data element.

    Activity headings and decision-support prompts are excluded: they are rows on the form but
    not elements, and a heading that happened to read like an element label would count as
    coverage the deployment does not have.
    """
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    # The `_dak` block itself is the test, not the id inside it: a heading carries no block and a
    # decision-support prompt carries `_decisionSupport` instead, while an element the kit left
    # unnumbered has a block with a blank id and is still a question the deployment collects.
    labels = {
        norm(question.get("text"))
        for sheet in spec["surveySheets"]
        for question in sheet["questions"]
        if question.get("_dak")
    }
    # And the values those questions offer, for a kit whose indicators count an option rather
    # than an element. Only options of a question carrying a DAK block, so a decision-support
    # prompt's wording can never be read as coverage.
    options = {
        norm(option)
        for sheet in spec["surveySheets"]
        for question in sheet["questions"]
        if question.get("_dak")
        for option in question.get("options", [])
    }
    return labels | options | FROM_PATIENT_RECORD


def read_annex_c(path: Path, layout: dict | None = None) -> list[dict]:
    """The indicators of a kit's Annex C, from a plain header row or a declared layout.

    The HIV kit heads its indicator sheet with one row of column names, which is all this needs.
    The FP kit spreads its header over three rows of merged cells and gives the two computation
    columns - the ones that quote the element labels - no heading of their own, so there is no
    single header row to match on. Such a kit declares `ANNEX_C` in its `domain.py` instead:
    positions rather than names, pinned by the same checksum discipline as the rest of the file.

    `sheet` may name several, for a kit that splits its indicators the way its dictionary is
    split. The SRV kit gives each of its four diseases a sheet and its disease-agnostic
    indicators a fifth, and carries four more it does not use - so the sheets are named rather
    than swept up. `firstDataRow` is a position within a sheet, so it is applied to each of
    them: read as an offset into the whole run, every sheet after the first keeps its header.
    """
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        declared = (layout or {}).get("sheet", "Indicator definitions")
        sheet_names = [declared] if isinstance(declared, str) else list(declared)
        missing = [name for name in sheet_names if name not in workbook.sheetnames]
        if missing:
            raise SystemExit(
                f"ERROR: {path.name} has no {', '.join(repr(name) for name in missing)} "
                f"sheet - it holds {', '.join(workbook.sheetnames)}.\n\n"
                "This check reads the element labels an indicator's calculation quotes, so it "
                "answers only for a kit that writes its calculations that way. The ANC kit states "
                "its numerators in prose and quotes nothing, and no reading of its sheet turns "
                "prose into an element list. See that domain's dak-conformance.md.\n"
            )
        sheets = [list(workbook[name].iter_rows(values_only=True)) for name in sheet_names]
    finally:
        workbook.close()

    if layout:
        columns = layout["columns"]
        # Each sheet loses its own heading rows. `firstDataRow` is a row number on a sheet, so
        # taking it as an offset into the sheets run together would leave every sheet after the
        # first carrying its header into the indicator list.
        rows = [row for sheet in sheets for row in sheet[layout["firstDataRow"] - 1 :]]
        # `ref` is the HIV kit's own cross-reference to its indicator catalogue; a kit without
        # one is keyed on the DAK id, which every kit has.
        return [
            {
                "id": cell(row, columns, "id"),
                "ref": cell(row, columns, "ref") or cell(row, columns, "id"),
                "name": cell(row, columns, "name"),
                "numerator": cell(row, columns, "numerator"),
                "denominator": cell(row, columns, "denominator"),
            }
            for row in rows
            # An id and a numerator. The TB kit breaks its indicator table into business
            # processes and then into subject groups, and writes each divider in the id column -
            # "Business process C: diagnosis", "People with presumptive TB" - where a row with an
            # id but nothing to compute reads as an indicator with an empty calculation and is
            # counted as a gap forever.
            if cell(row, columns, "id") and cell(row, columns, "numerator")
        ]

    header = [str(value).strip() if value else "" for value in sheets[0][0]]
    index = {name: position for position, name in enumerate(header)}
    indicators = []
    for row in [row for sheet in sheets for row in sheet[1:]]:
        if not cell(row, index, "DAK ID"):
            continue
        indicators.append(
            {
                "id": cell(row, index, "DAK ID"),
                "ref": cell(row, index, "Ref no."),
                "name": cell(row, index, "Short name"),
                "numerator": cell(row, index, "Numerator calculation"),
                "denominator": cell(row, index, "Denominator calculation"),
            }
        )
    return indicators


def classify(indicator: dict, available: set[str]) -> tuple[str, set[str], int, set[str]]:
    calculation = " ".join(str(indicator[key]) for key in ("numerator", "denominator") if indicator[key])
    if "not included in dak" in calculation.lower():
        return "no numerator", set(), 0, set()

    elements, skipped, compared = quoted_elements(indicator["numerator"], indicator["denominator"])
    missing = {element for element in elements if element not in available}
    # A compared value never counts as missing - an option string is not an element, and counting
    # it as one made every indicator that quotes one read as a gap. One matching no question is
    # reported instead, since that is the case where it may have been an element after all.
    unchecked = {value for value in compared if value not in available}
    # A computation that quotes nothing states its numerator in prose, which no reading turns
    # into an element list. Reported apart from a gap because the two call for opposite things: a
    # gap is a form-selection decision to revisit, while this is a limit of the check itself and
    # widening the selection would not move it.
    if not elements:
        return "not quoted", set(), skipped, unchecked
    if missing:
        return "gap", missing, skipped, unchecked
    return "covered", set(), skipped, unchecked


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--domain", required=True, help="Domain directory, e.g. hiv")
    parser.add_argument(
        "--list",
        choices=["covered", "gap", "not-quoted", "no-numerator", "all"],
        help="Print the indicators in a category rather than only the counts.",
    )
    args = parser.parse_args()

    domain = Path(args.domain)
    spec_files = sorted(domain.glob("*_program.json"))
    if not spec_files:
        print(f"ERROR: no generated spec in {domain}/ -- run dak_generator.py first", file=sys.stderr)
        return 2

    spec = spec_files[0]

    # the domain module records the annexe filenames, and the layout where the kit needs one
    domain_module = load_domain(args.domain)
    # Not every kit publishes an Annex C. The SMBP kit's `input/indicators/` at its released tag
    # holds nothing but the `.gitignore` that would have hidden the workbook, so it has no
    # indicators to be covered or missed and its `ANNEXES` records none. Saying so is the answer
    # to "which indicators can we report"; a `KeyError` is not.
    domain_config = domain_module.ANNEXES.get("C")
    if domain_config is None:
        print(
            f"{args.domain}: this kit publishes no Annex C, so there are no indicators to check.\n"
            "See its dak-conformance.md."
        )
        return 0
    layout = getattr(domain_module, "ANNEX_C", None)

    annex_c = domain / "annexes" / domain_config["filename"]
    if not annex_c.is_file():
        # The fetch command where the kit records a version-pinned `url`, which is how the ones
        # WHO ships through its implementation-guide site are recorded; the IRIS handle where it
        # does not, which is all the kits published as numbered IRIS items carry. Either shape of
        # `ANNEXES` entry has to yield this message rather than a traceback.
        #
        # Paths are quoted and written with forward slashes because a kit's filename holds spaces
        # - `CCC DAK_indicators.xlsx` - and an unquoted one truncates the `-o` argument, leaving
        # the rest of the name to be read as a second URL.
        if domain_config.get("url"):
            fetch = (
                "Fetch it with:\n\n"
                f'    mkdir -p "{annex_c.parent.as_posix()}"\n'
                f'    curl -sL -o "{annex_c.as_posix()}" \\\n        {domain_config["url"]}\n'
            )
        else:
            fetch = f"Fetch it from IRIS handle {domain_config['handle']}; see README.md.\n"
        print(
            f"ERROR: Annex C is not present at {annex_c}\n\n"
            "It is not committed -- a third-party spreadsheet WHO publishes at a stable URL.\n"
            f"{fetch}",
            file=sys.stderr,
        )
        return 2

    available = form_labels(spec)
    indicators = read_annex_c(annex_c, layout)

    buckets: dict[str, list] = {"covered": [], "gap": [], "not quoted": [], "no numerator": []}
    skipped_quotes = 0
    unchecked_values: set[str] = set()
    for indicator in indicators:
        verdict, missing, skipped, unchecked = classify(indicator, available)
        buckets[verdict].append((indicator, missing))
        skipped_quotes += skipped
        unchecked_values |= unchecked

    print(f"{spec.name}: {len(available - FROM_PATIENT_RECORD)} distinct question labels and option strings")
    print(f"{annex_c.name}: {len(indicators)} indicators")
    print()
    print(f"  covered by the forms   {len(buckets['covered']):4}")
    print(f"  gap in the forms       {len(buckets['gap']):4}")
    print(f"  computation not quoted {len(buckets['not quoted']):4}   (stated in prose, nothing to check)")
    print(f"  no computable numerator{len(buckets['no numerator']):4}   (Annex C's own statement)")
    if skipped_quotes:
        print(
            f"\n  {skipped_quotes} quoted string(s) longer than {MAX_LABEL} characters were not "
            f"checked as labels -- raise MAX_LABEL if any is a real element."
        )
    if unchecked_values:
        print(
            f"\n  {len(unchecked_values)} quoted string(s) sat on the right of a comparison, so were "
            "read as the value compared against rather than as a label, and name no question on the "
            "forms. An indicator naming an element that way reads covered without it being checked:"
        )
        for value in sorted(unchecked_values):
            print(f"      {value}")

    wanted = {
        "covered": ["covered"],
        "gap": ["gap"],
        "not-quoted": ["not quoted"],
        "no-numerator": ["no numerator"],
        "all": ["covered", "gap", "not quoted", "no numerator"],
    }.get(args.list, [])

    for verdict in wanted:
        print(f"\n=== {verdict} ===")
        for indicator, missing in sorted(buckets[verdict], key=lambda pair: pair[0]["ref"]):
            line = f"  {indicator['ref']:9} {indicator['id']:12} {indicator['name'][:52]}"
            if missing:
                line += "\n" + "\n".join(f"              missing: {label}" for label in sorted(missing))
            print(line)

    return 0


if __name__ == "__main__":
    sys.exit(main())
