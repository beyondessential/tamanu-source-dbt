"""The birth defects surveillance domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is that its value set **nests**. Every other kit's coded element
is one question and a flat list of answers; this one states the congenital anomaly as a tree three
levels deep — `Congenital anomaly diagnosis` offers ten body-system groups, `Central nervous
system defects` offers `Encephalocele`, and `Encephalocele` offers the eight sites — and says so
in a column of its own, `List to include this data element in`, which its READ ME describes as
indicating "if the data element is part of a list of data elements". Each level is a row typed as
a list, so each level is both a question and one of the values of the question above it. See
`dak-conformance.md` § A value set that nests.

The other thing to know is that no data element belongs to the case-confirmation process alone.
The kit has three business processes — collection and abstraction, case confirmation, data
aggregation — but every row on `BDS.Common` and on the collection tab names activities of the
first two together, because confirmation re-opens the same case record rather than collecting
anything new. So the processes are not what the surveys divide on; the grain is. See
`dak-conformance.md` § Three processes, two forms.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for birth defects surveillance (2025), DAK version 1.0.0.
#
# `elementPrefix` is the kit's own name, which every id carries and which nothing distinguishes:
# `BDS.Comm.DE.1`, `BDS.A4.DE.1`, `BDS.B6.DE.1` stay apart on the segment after it.
DAK = {
    "title": "Digital adaptation kit for birth defects surveillance (2025)",
    "elementPrefix": "BDS.",
}

# The kit's components, fetched not committed (see ../../../.gitignore). The sha256 is the copy
# these artefacts were generated from, so a WHO revision announces itself rather than quietly
# changing a form.
#
# Hosted the way the TB, IMMZ, CHE and SRV kits are: WHO ships the components through its SMART
# guidelines implementation guide, whose component pages serve whatever the site last built, so
# `url` points at WHO's own source repository — `WorldHealthOrganization/smart-dak-bds` — at the
# `v1.0.0` tag, whose `sushi-config.yaml` declares `status: active` and `releaseLabel: release`.
# Pin the tag, never the branch: `main` is a continuous integration build.
#
# **This kit publishes no Annex B.** Its `input/decision-logic/` directory holds nothing but the
# `.gitignore` that would have hidden the workbook, so there is no decision-support logic to read
# and `DECISION_SUPPORT` is empty. See `dak-conformance.md` § No decision-support logic.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "BDS DAK_core data dictionary.xlsx",
        "page": "https://smart.who.int/dak-bds/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-bds/v1.0.0/"
            "input/dictionary/BDS%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "82383db06e529fede20e89386897e134b199e9873b5725cc76bfbecef920590a",
    },
    "C": {
        "name": "indicators",
        "filename": "BDS DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-bds/indicators.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-bds/v1.0.0/"
            "input/indicators/BDS%20DAK_indicators.xlsx"
        ),
        "sha256": "909d8f18a20f067dafddf869ff65dd491499932815c7fef004fb0561b0d79e02",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "BDS DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-bds/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-bds/v1.0.0/"
            "input/system-requirements/"
            "BDS%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header names:
# like the TB, FP, IMMZ, CHE and SRV kits, this one splits its header across two rows —
# `Numerator` and `Denominator` each span two columns on the first, `Description` and
# `Computation` name them on the second — so there is no single header row to match on.
#
# `firstDataRow` is the spreadsheet's own row number and `columns` are zero-based offsets, so
# `id: 1` is column B. `numerator` is the Computation column rather than the Description beside
# it, because the computation is where the kit quotes the element labels. The thirteen rows that
# head a body system — `Congenital heart defects`, `Abdominal wall defects` — carry an id and no
# computation, which is what the reader already drops a divider on.
ANNEX_C = {
    "sheet": "Indicator table",
    "firstDataRow": 4,
    "columns": {"id": 1, "name": 2, "numerator": 5, "denominator": 7},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK Birth Defects Surveillance",
    "programCode": "who-dak-bds",
    "codePrefix": "whodakbds",  # question codes: whodakbds-comm-de-20
}

# Two forms and a review, which is not how the kit's three business processes divide.
#
# No element belongs to the case-confirmation process alone: all 152 rows of `BDS.Common` and all
# 105 of the collection tab name activities of process A *and* of process B, because confirmation
# re-opens the same case record rather than collecting anything new. Slicing by process would
# therefore build a second survey out of the first one's questions and drop every one of them as
# a repeated code. What the kit does divide on is grain — who is answering, and about what:
#
#   the case      the newborn, the pregnancy and the parents, collected or abstracted from the
#                 record by the data collector          -> `BDS.A.Data collect abstract`
#   the anomaly   what the defect is, how it presents and whether the diagnosis is confirmed,
#                 which is the whole of `BDS.Common`    -> `BDS.Common`
#   the review    what the birth defects specialist and the data manager send back to each other
#                 about a case already recorded         -> `BDS.B.Case confirmation`
#
# `BDS.C.Data aggregation` is in no survey. Its four elements — whether a generated report is
# satisfactory, the signature approving it, comments on it, and a request for corrections to it —
# are about a periodic report over many cases rather than about a case, and a form asking for them
# would collect a judgement on data the deployment already holds. That is the same grain the SRV
# kit reports upward and the same reason it is left out; what those elements state is what a
# `metric__` layer computes. See `dak-conformance.md` § Three processes, two forms.
#
# `activities` is what heads each screen. Every row of `BDS.Common` names four or five activities
# in one cell, so without a slice the whole cell becomes the screen title; naming the A-process
# activities takes each row under the one it was collected at.
PROCESSES = [
    {
        "tab": "BDS.A.Data collect abstract",
        "activities": ["BDS.A4", "BDS.A10", "BDS.A12", "BDS.A15", "BDS.A17"],
        "code": "case",
        "name": "Birth Defects Case Record",
        "surveyType": "programs",
    },
    {
        "tab": "BDS.Common",
        "activities": ["BDS.A4", "BDS.A12", "BDS.A18"],
        "code": "anomaly",
        "name": "Birth Defects Anomaly Diagnosis",
        "surveyType": "programs",
    },
    {
        "tab": "BDS.B.Case confirmation",
        "code": "review",
        "name": "Birth Defects Case Confirmation",
        "surveyType": "programs",
    },
]

# Elements the patient record already holds. A DAK registers its own client because it cannot
# assume a record exists; Tamanu has one, and collecting a name or a date of birth onto a form as
# well gives a deployment two places to write one fact and no rule for which counts.
#
# The subject of a birth defects case is the newborn, so this is the newborn's own registration
# block and nothing else. The parents' names and identifiers are left on the form deliberately:
# Tamanu links a patient to a mother and a father, but the link exists only where both are
# patients of this deployment, and a surveillance case is routinely recorded for a newborn whose
# mother is not — so dropping them would lose the fact rather than move it.
PATIENT_RECORD = frozenset(
    {
        "BDS.A4.DE.4",  # Health facility ID
        "BDS.A12.DE.7",  # First name
        "BDS.A12.DE.8",  # Last name
        "BDS.A12.DE.9",  # Unique ID
        "BDS.A12.DE.10",  # Date of birth
        "BDS.A12.DE.11",  # Date of birth unknown
        "BDS.A12.DE.13",  # Sex
    }
)

CORE_TABS = {
    "BDS.Common",
    "BDS.A.Data collect abstract",
    "BDS.B.Case confirmation",
}

# The third rule exists because the first two drop clinically central but unreported elements.
# This kit needs it for three groups of them.
CORE_ELEMENTS = {
    # --- the anomaly tree's middle and lower levels ---------------------------
    # A list nested inside another list carries no `Optionality` of its own — the kit flags the
    # top of the tree `R` and leaves every level beneath it blank — and links an indicator only
    # on the ten body-system groups. The seventeen sub-lists below them are named by an indicator
    # rather than linked from one: `BDS.IND.4` counts `"Congenital anomaly diagnosis" included in
    # "Encephalocele" list`, so without the sub-list there is a tick for `Encephalocele` and no
    # way to say which of the eight it was, and the indicator counting it has nothing to count.
    "BDS.Comm.DE.25",  # Encephalocele
    "BDS.Comm.DE.34",  # Spina bifida
    "BDS.Comm.DE.58",  # Cleft palate
    "BDS.Comm.DE.65",  # Cleft lip
    "BDS.Comm.DE.69",  # Cleft palate with cleft lip
    "BDS.Comm.DE.81",  # Oesophageal atresia/tracheo-oesophageal fistula
    "BDS.Comm.DE.85",  # Large intestinal atresia/stenosis
    "BDS.Comm.DE.90",  # Anorectal atresia/stenosis
    "BDS.Comm.DE.97",  # Hypospadias
    "BDS.Comm.DE.104",  # Renal agenesis/hypoplasia
    "BDS.Comm.DE.111",  # Limb deficiency: amelia
    "BDS.Comm.DE.115",  # Tranverse terminal limb deficiency
    "BDS.Comm.DE.122",  # Intercalary limb deficiency
    "BDS.Comm.DE.126",  # Longitudinal preaxial limb deficiency
    "BDS.Comm.DE.131",  # Longitudinal axial limb deficiency
    "BDS.Comm.DE.134",  # Longitudinal postaxial limb deficiency
    "BDS.Comm.DE.143",  # Down syndrome
    # --- consent, and the photograph it is sought for -------------------------
    # The kit gives consent two of the collection process's five activities and marks all four
    # elements `C`, "required if demanded by the surveillance system" — a statement about the
    # deployment's rules rather than about an answer given earlier, which is the one thing the
    # `Optionality` flag cannot say. Left to the first two rules the whole of both activities
    # drops, and the form asks for a photograph of a newborn without recording the consent taken
    # for it.
    "BDS.A10.DE.5",  # Consent provided for data collection
    "BDS.A10.DE.6",  # Signature for consent
    "BDS.A15.DE.102",  # Consent provided for photographs
    "BDS.A15.DE.103",  # Signature for photographs
    "BDS.A17.DE.105",  # Photograph
    # --- the pregnancy and birth the prevalence denominators are read against --
    # Each is `C` on an answer above it and named by no indicator, and each is what a birth
    # defects prevalence is stratified by.
    "BDS.A12.DE.22",  # Gestational age at birth
    "BDS.A12.DE.23",  # Gestational age at birth unknown
    "BDS.A12.DE.28",  # Weight
    "BDS.A12.DE.29",  # Length
    "BDS.A12.DE.30",  # Head circumference
    # The newborn's death, which no indicator names and without which a case closes with no
    # outcome. `Cause of death` is the kit's own list; the rest date and qualify it.
    "BDS.A12.DE.32",  # Newborn death
    "BDS.A12.DE.33",  # Date of death
    "BDS.A12.DE.34",  # Cause of death known
    "BDS.A12.DE.35",  # Cause of death
    "BDS.A12.DE.36",  # Autopsy
    # Consanguinity, which the kit asks about because it is the aetiology a registry exists to
    # detect, and which it marks `O` and `C`.
    "BDS.A12.DE.38",  # Parents related
    "BDS.A12.DE.39",  # Parent relationship
    # --- the whole of the case-confirmation process ---------------------------
    # Four `O` elements linked to no indicator, which between them are the entire record of what
    # the birth defects specialist and the data manager did with a case. `Diagnosis correction` is
    # the one the kit's own `BDS.IND.42` counts — `COUNT of birth defects cases with "Diagnosis
    # correction" = FALSE` — while leaving its indicator-linkage column blank, so the linkage rule
    # cannot see it and the accuracy indicator would have no numerator.
    "BDS.B6.DE.1",  # Diagnosis correction
    "BDS.B11.DE.2",  # Request for further information to data manager
    "BDS.B12.DE.3",  # Request for futher information to data collector
    "BDS.B17.DE.4",  # Comments to data manager
}

# This kit publishes no decision-support logic: `input/decision-logic/` at the released tag holds
# only a `.gitignore`, and the implementation guide's own decision-logic page is empty. There is
# nothing to encode, and nothing is invented to fill the gap — a guidance prompt this repository
# authored would be a clinical recommendation WHO has not made.
DECISION_SUPPORT = []

# --- the Tamanu program registry --------------------------------------------
# Not from the DAK. A DAK has no registry concept: it specifies the data a case is recorded with,
# not the enrolment that says a client is being followed. The registry is what makes the case a
# longitudinal record in Tamanu, and its vocabulary is taken from the kit's own elements so that
# what the registry says and what the forms collect are the same statement.
REGISTRY = {
    "registryCode": "who-dak-bds",
    "registryName": "WHO DAK Birth Defects Surveillance",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    # The kit has a loss-to-follow-up indicator, `BDS.IND.41`, and states it as a case record
    # status rather than as an elapsed time: cases whose status is `Incomplete` over cases that
    # are `Complete` or `Incomplete`. The status below already carries that, so Tamanu's separate
    # threshold is left off rather than giving one fact two places to be recorded and two answers.
    "lossToFollowUpEnabled": False,
    # Where this case record stands, from the four values of `BDS.Comm.DE.1 Case record status`.
    # This is the element the kit's data-quality indicators are all keyed on — `BDS.IND.39`
    # counts completeness within `Complete`, `BDS.IND.41` reads `Incomplete` as loss to
    # follow-up, `BDS.IND.42` and `BDS.IND.43` restrict to `Complete` — and every prevalence
    # numerator requires it too.
    "clinicalStatuses": [
        {"code": "who-dak-bds-open", "name": "Open", "color": "blue"},
        {"code": "who-dak-bds-incomplete", "name": "Incomplete", "color": "orange"},
        {"code": "who-dak-bds-complete", "name": "Complete", "color": "green"},
        {"code": "who-dak-bds-discarded", "name": "Discarded", "color": "grey"},
    ],
    # Which anomaly the case is of, from the ten body-system groups the kit offers directly under
    # `BDS.Comm.DE.20 Congenital anomaly diagnosis`. The group rather than the specific defect:
    # the groups are the level the kit links `BDS.IND.42` to and the level a registry list stays
    # legible at, and the specific defect is on the form, where the tree's lower levels record it.
    "conditions": [
        {"code": "who-dak-bds-cond-cns", "name": "Central nervous system defects"},
        {"code": "who-dak-bds-cond-ear", "name": "Ear defects"},
        {"code": "who-dak-bds-cond-heart", "name": "Congenital heart defects"},
        {"code": "who-dak-bds-cond-orofacial", "name": "Orofacial defects"},
        {"code": "who-dak-bds-cond-gastrointestinal", "name": "Gastrointestinal defects"},
        {"code": "who-dak-bds-cond-genitourinary", "name": "Genitourinary defects"},
        {"code": "who-dak-bds-cond-musculoskeletal", "name": "Musculoskeletal defects"},
        {"code": "who-dak-bds-cond-abdominal-wall", "name": "Abdominal wall defects"},
        {"code": "who-dak-bds-cond-chromosomal", "name": "Chromosomal abnormalities"},
        {"code": "who-dak-bds-cond-infection", "name": "Congenital infection syndromes"},
    ],
    # Tamanu hard-loads unknown / disproven / resolved / recordedInError into every registry and
    # merges spreadsheet rows over them. The kit's `BDS.Comm.DE.7 Congenital anomaly diagnosis
    # status` has four values of its own, and two of them the hard-loaded four already say:
    # `Excluded` is `disproven`, and `Misdiagnosis` is `recordedInError`. The other two are the
    # distinction every prevalence indicator turns on — each counts `"Congenital anomaly
    # diagnosis status" = "Confirmed diagnosis"` — and neither is expressible, so both are added.
    # These codes are deliberately unprefixed: Tamanu's UI carries labels for exactly these
    # strings, and they are scoped per registry.
    "conditionCategories": [
        {"code": "possible", "name": "Possible diagnosis"},
        {"code": "confirmed", "name": "Confirmed diagnosis"},
    ],
}
