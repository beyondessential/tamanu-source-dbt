"""The surveillance domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is that a tab is a **disease**, not a business process. Every
other kit gives each business process a tab of its own and names the process in the tab's title;
this one gives cholera, measles, bacterial meningitis and yellow fever a tab each, runs all five
of its processes down every one of them, and carries the process only in the activity id —
`CHOLSRV.C1` is clinical evaluation, `CHOLSRV.D8` is the laboratory, `CHOLSRV.F1` the outbreak
investigation. A survey is therefore a slice of a disease tab taken by process, which is what
`activities` already expresses. See `dak-conformance.md` § A tab is a disease.

The disease also sits in the element id, which is why `elementPrefix` is empty: `CHOLSRV.C1.DE.12`
and `MSLSRV.C1.DE.12` are different elements of different diseases, and stripping the prefix that
tells them apart would collide them onto one question code and silently drop the second.

The other thing to know is that the kit mixes three grains on one tab. Most of it is about the
case in front of the health worker, but `E7` reports counts to the authorities above — "Number of
suspected cholera cases", "Population size", "Number of suspected cases per week" — and `E9` and
cholera's `F5` describe the outbreak rather than the case. None is an answer a health worker gives
about a patient, and a form that asked for them would collect a number the case records already
contain. Those three activities are left out of every survey; what they state is what the
`metric__` layer computes from the cases. See `dak-conformance.md` § Three grains.
"""

# --- the DAK's own identity --------------------------------------------------
# Surveillance Digital Adaptation Kit for infectious disease surveillance (2026), DAK version
# 1.0.0. The kit is disease-agnostic in its common tabs and carries disease-specific modules for
# cholera, measles, bacterial meningitis and yellow fever.
#
# `elementPrefix` is empty deliberately — see the module docstring. This kit names itself six ways
# (`SRVREG.`, `SRV.`, `CHOLSRV.`, `MSLSRV.`, `MENSRV.`, `YFSRV.`) and the name is load-bearing.
DAK = {
    "title": "Digital adaptation kit for infectious disease surveillance (2026)",
    "elementPrefix": "",  # the disease is part of the id, so nothing is stripped
}

# The kit's four components, fetched not committed (see ../../../.gitignore). The sha256 is the
# copy these artefacts were generated from, so a WHO revision announces itself rather than
# quietly changing a form.
#
# Hosted the way the TB, IMMZ and CHE kits are: WHO ships the components through its SMART
# guidelines implementation guide, whose component pages serve whatever the site last built, so
# `url` points at WHO's own source repository — `WorldHealthOrganization/smart-dak-srv` — at the
# `v1.0.0` tag, whose `sushi-config.yaml` declares `status: active` and `releaseLabel: release`.
# Pin the tag, never the branch: `main` is a continuous integration build.
#
# This kit has no IRIS handle to record. Its own README says "The SRV DAK publication can be found
# here [IRIS link forthcoming]", so the repository is the publication for now.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "SRV DAK_core data dictionary.xlsx",
        "page": "https://smart.who.int/dak-srv/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-srv/v1.0.0/"
            "input/dictionary/SRV%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "c33500b0c5ec31dd426bbe8b136a34de5b6c3bcc651f07444e8e807bf5f8a746",
    },
    "B": {
        # Two tables per disease: one classifying a case against the case definition, one saying
        # when the outbreak threshold is met.
        "name": "decision-support logic",
        "filename": "SRV DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-srv/decision-logic.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-srv/v1.0.0/"
            "input/decision-logic/SRV%20DAK_decision-support%20logic.xlsx"
        ),
        "sha256": "30f0345934cb6f9e7acebcd5c8bde7f49ba75a7458cf7ae9a0cd88d7be0fdc9e",
    },
    "C": {
        "name": "indicators",
        "filename": "SRV DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-srv/indicators.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-srv/v1.0.0/"
            "input/indicators/SRV%20DAK_indicators.xlsx"
        ),
        "sha256": "87a413b8cdd72f1a59753327e026e2de6de407800cee3036ec9ca1fcc7c698e3",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "SRV DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-srv/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-srv/v1.0.0/"
            "input/system-requirements/"
            "SRV%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header names:
# like the TB, FP, IMMZ and CHE kits, this one splits its header across two rows — `Numerator` and
# `Denominator` each span two columns on the first, `Description` and `Computation` name them on
# the second — so there is no single header row to match on.
#
# Five sheets rather than one, because the indicators are split the way the dictionary is: a sheet
# per disease and `SRVCommon` for the three every disease reports. The four the workbook also
# carries — `Meningitis (old)` and the three it marks `not used, merged` — are left out by naming
# the live ones rather than sweeping the workbook.
#
# `firstDataRow` is the spreadsheet's own row number and `columns` are zero-based offsets, so
# `id: 1` is column B. `numerator` is the Computation column rather than the Description beside
# it, because the computation is where the kit quotes the element labels.
ANNEX_C = {
    "sheet": ["SRVCommon", "Cholera", "Bacterial Meningitis", "Measles", "Yellow fever"],
    "firstDataRow": 3,
    "columns": {"id": 1, "name": 2, "numerator": 8, "denominator": 10},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK Surveillance",
    "programCode": "who-dak-srv",
    "codePrefix": "whodaksrv",  # question codes: whodaksrv-cholsrv-c1-de-12
}

# Three surveys per disease, because the kit's five processes are three moments with three
# different people in them:
#
#   C  the clinician, at the bedside: evaluate the case, apply the case definition, take the
#      specimen and record the outcome
#   D  the laboratory: register the specimen and encode the result
#   E/F/G  the surveillance officer, afterwards: investigate the case's exposure, list its
#      contacts, and settle the final classification
#
# Splitting further would leave forms of one and two questions — meningitis has two elements under
# `F1` and yellow fever one under `E4`; not splitting at all would put the laboratory's result and
# the clinician's examination on one form neither of them owns.
#
# `E7` is in no survey on any disease, nor are cholera's `E9` and `F5`. See the module docstring.
#
# `Registration common` and `Surveillance common` are disease-agnostic and become one survey each,
# at the front and the back of the program: the kit defines them once and every disease's process
# uses them, which is exactly what its READ ME means by "applicable in all business processes
# where the data element is used".
#
# `Workflow ID (with examples)` and `HealthDomainAbbv.Configuration` are neither. They are the
# WHO template's own instruction tabs, shipped unremoved — the first still holds the ANC, TB and
# IMMZ example rows it tells its author to delete, the second still has the placeholder name. A
# process list that named tabs by pattern rather than one at a time would build surveys out of
# another kit's examples.
PROCESSES = [
    {
        "tab": "Registration common",
        "code": "onset",
        "name": "Surveillance Symptom Onset",
        "surveyType": "programs",
    },
    # --- cholera -------------------------------------------------------------
    {
        "tab": "Cholera",
        "activities": ["CHOLSRV.C1", "CHOLSRV.C6", "CHOLSRV.C8", "CHOLSRV.C10", "CHOLSRV.C12", "CHOLSRV.C13"],
        "code": "chol-case",
        "name": "Cholera Case Notification",
        "surveyType": "programs",
    },
    {
        "tab": "Cholera",
        "activities": ["CHOLSRV.D1", "CHOLSRV.D8", "CHOLSRV.D9"],
        "code": "chol-lab",
        "name": "Cholera Laboratory Results",
        "surveyType": "programs",
    },
    {
        "tab": "Cholera",
        "activities": ["CHOLSRV.F1", "CHOLSRV.E6"],
        "code": "chol-inv",
        "name": "Cholera Case Investigation",
        "surveyType": "programs",
    },
    # --- measles -------------------------------------------------------------
    {
        "tab": "Measles",
        "activities": ["MSLSRV.C1", "MSLSRV.C6", "MSLSRV.C8", "MSLSRV.C10"],
        "code": "msl-case",
        "name": "Measles Case Notification",
        "surveyType": "programs",
    },
    {
        "tab": "Measles",
        "activities": ["MSLSRV.D1", "MSLSRV.D8"],
        "code": "msl-lab",
        "name": "Measles Laboratory Results",
        "surveyType": "programs",
    },
    {
        "tab": "Measles",
        "activities": ["MSLSRV.F1", "MSLSRV.G1", "MSLSRV.G3", "MSLSRV.G4", "MSLSRV.E4", "MSLSRV.E6"],
        "code": "msl-inv",
        "name": "Measles Case Investigation",
        "surveyType": "programs",
    },
    # --- bacterial meningitis -------------------------------------------------
    {
        "tab": "Bacterial Meningitis",
        "activities": ["MENSRV.C1", "MENSRV.C6", "MENSRV.C8", "MENSRV.C10", "MENSRV.C11"],
        "code": "men-case",
        "name": "Bacterial Meningitis Case Notification",
        "surveyType": "programs",
    },
    {
        "tab": "Bacterial Meningitis",
        "activities": ["MENSRV.D1", "MENSRV.D8"],
        "code": "men-lab",
        "name": "Bacterial Meningitis Laboratory Results",
        "surveyType": "programs",
    },
    {
        "tab": "Bacterial Meningitis",
        "activities": ["MENSRV.F1", "MENSRV.E4", "MENSRV.E6"],
        "code": "men-inv",
        "name": "Bacterial Meningitis Case Investigation",
        "surveyType": "programs",
    },
    # --- yellow fever ---------------------------------------------------------
    {
        "tab": "Yellow fever",
        "activities": ["YFSRV.C1", "YFSRV.C6", "YFSRV.C8", "YFSRV.C10"],
        "code": "yf-case",
        "name": "Yellow Fever Case Notification",
        "surveyType": "programs",
    },
    {
        "tab": "Yellow fever",
        "activities": ["YFSRV.D1", "YFSRV.D8"],
        "code": "yf-lab",
        "name": "Yellow Fever Laboratory Results",
        "surveyType": "programs",
    },
    {
        "tab": "Yellow fever",
        "activities": ["YFSRV.F1", "YFSRV.E4", "YFSRV.E6"],
        "code": "yf-inv",
        "name": "Yellow Fever Case Investigation",
        "surveyType": "programs",
    },
    {
        "tab": "Surveillance common",
        "code": "outcome",
        "name": "Surveillance Diagnosis and Outcome",
        "surveyType": "programs",
    },
]

# Elements the patient record already holds, so the form does not collect them a second time.
#
# `Registration common` is the kit registering its own client, which it has to do because a DAK
# cannot assume a record exists. Tamanu has one: name, identifier, date of birth, sex, address and
# its administrative hierarchy, telephone, email, the encounter and its facility, the clinician,
# and the referral that brought the client in are all fields of the patient and the encounter.
# Collected onto a form as well they would give a deployment two places to write one fact and no
# rule for which counts, and the second place is the one no other part of Tamanu reads.
#
# What is left is the two the patient record has no field for, and both are clinical rather than
# administrative: whether the client has symptoms at all, and the date the first of them started.
# The onset date is the one every incidence and timeliness indicator dates a case from, and only
# measles and yellow fever restate it on their own tabs, so dropping the whole tab would leave
# cholera and meningitis with no onset at all.
PATIENT_RECORD = frozenset(
    {
        "SRVREG.B5.DE.1",  # First name
        "SRVREG.B5.DE.2",  # Last name
        "SRVREG.B5.DE.3",  # UID
        "SRVREG.B5.DE.4",  # Date of birth
        "SRVREG.B5.DE.5",  # Date of birth unknown
        "SRVREG.B5.DE.6",  # Age
        "SRVREG.B5.DE.7",  # Sex
        "SRVREG.B5.DE.12",  # Address
        "SRVREG.B5.DE.13",  # Admin 1 of Residence
        "SRVREG.B5.DE.14",  # Admin 2 of Residence
        "SRVREG.B5.DE.15",  # Admin 3 of Residence
        "SRVREG.B5.DE.16",  # Admin 4 of Residence
        "SRVREG.B5.DE.17",  # Telephone number
        "SRVREG.B5.DE.18",  # Email address
        "SRVREG.B5.DE.19",  # Reporting health facility
        "SRVREG.B5.DE.20",  # Reporting health facility code
        "SRVREG.B5.DE.21",  # Healthcare provider's name
        "SRVREG.B5.DE.22",  # Healthcare provider's facility ID
        "SRVREG.B5.DE.23",  # Health care provider's telephone number
        "SRVREG.B5.DE.24",  # Encounter / Admission date
        "SRVREG.B5.DE.25",  # Referral
        "SRVREG.B5.DE.29",  # Referring facility
        "SRVREG.B5.DE.30",  # Referral ID
        "SRVREG.B5.DE.31",  # Reason for referral
        "SRVREG.B5.DE.32",  # Referring health worker
        "SRVREG.B5.DE.33",  # Admission Type
    }
)

# Rows the kit marks as nothing at all — no data type, no `List value` — that are input options of
# the question above them. By rule such a row is indistinguishable from a section heading, so a
# domain has to name it, the way the TB kit's three unmarked options are named.
#
# These three are the Yes / No / Unknown of `SRVREG.B5.DE.25 Referral`, which the kit types on
# every other list it writes. They are options of an element the patient record already holds, so
# naming them changes no form; unnamed, they would be three headings standing over the questions
# after them.
OPTION_ROWS = (
    "SRVREG.B5.DE.26",
    "SRVREG.B5.DE.27",
    "SRVREG.B5.DE.28",
)

# An option the kit labels with a string that already belongs to another option of the same
# question. Two identical options collapse to one and lose an answer, and neither row has anything
# else to fall back on: this kit has no separate option column, so the label is the option.
#
# Both are vaccine formulations whose labels ran together while their code mappings stayed apart.
# The replacement is the ATC substance name the kit itself puts on the row, so the string is the
# kit's own rather than invented, and it is the unconjugated antigen in both cases:
#
#   MENSRV.C6.DE.37  ATC J07AH01, ICD-11 XM37L5  vs  DE.46  ATC J07AH10 (conjugated)
#   MENSRV.C6.DE.61  ATC J07AL01, ICD-11 XM91D7  vs  DE.62  ATC J07AL02 (conjugated)
OPTION_LABELS = {
    "MENSRV.C6.DE.37": "Meningococcus A, purified polysaccharides antigen",
    "MENSRV.C6.DE.61": "Pneumococcus, purified polysaccharides antigen",
}

# The kit's own core-elements shortlist, and which tabs it covers. The selection rule carries an
# element that is `Optionality = R`, or feeds an Annex C indicator, or is named here.
CORE_TABS = {
    "Registration common",
    "Surveillance common",
    "Cholera",
    "Measles",
    "Bacterial Meningitis",
    "Yellow fever",
}

# The third rule exists because the first two drop clinically central but unreported elements.
# This kit needs it for the dates and qualifiers that are `Optionality = C` — conditional on an
# answer given earlier, which is a statement about when to ask rather than about whether the
# element matters — and which no indicator happens to name.
CORE_ELEMENTS = {
    # The onset date every incidence and timeliness indicator dates a case from. Conditional on
    # the client having symptoms, so never flagged `R`.
    "SRVREG.B5.DE.38",  # Date of onset of first symptom(s)
    # The date of death, without which a case fatality ratio has a numerator and no date.
    "SRV.C13.DE.10",
    # The disease-specific onset dates, each conditional on the sign it dates.
    "MSLSRV.C1.DE.17",  # Date of rash onset
    "YFSRV.C1.DE.2",  # Date of fever onset
    "YFSRV.C1.DE.4",  # Date of jaundice onset
    # The dehydration grading cholera case management turns on, conditional on the diarrhoea
    # answer above it.
    "CHOLSRV.C1.DE.7",  # Level of dehydration
}

# Annex B states two decision tables per disease: one classifying a case against the case
# definition, one saying when the outbreak threshold is met. A form can prompt but not conclude,
# so what is encodable is the guidance the annexe attaches to a classification the health worker
# has just recorded — gated on that answer, in the annexe's own words.
#
# The outbreak-threshold tables are not encodable at all. They compare this week's case count with
# last week's across a surveillance unit, which is an aggregate over cases rather than a fact
# about the one in front of the health worker; a form has no access to it. What they state is a
# `metric__` layer's rule, not a form's.
DECISION_SUPPORT = [
    # --- cholera, CHOLSRV.C2.DT ----------------------------------------------
    {
        "rule": "CHOLSRV.C2.DT",
        "survey": "chol-case",
        "after": "CHOLSRV.C1.DE.12",
        "code": "whodaksrv-ds-chol-suspected",
        "name": "Suspected cholera case",
        "guidance": (
            "Initiate treatment BEFORE laboratory results. Test the case by RDT where RDTs are "
            "available and confirm a positive by culture and/or PCR; test by culture and/or PCR "
            "where they are not. Refer to cholera clinical guidelines for rehydration."
        ),
        "gate": {"CHOLSRV.C1.DE.12": "Suspected case"},
    },
    {
        "rule": "CHOLSRV.C2.DT",
        "survey": "chol-case",
        "after": "CHOLSRV.C1.DE.12",
        "code": "whodaksrv-ds-chol-confirmed",
        "name": "Confirmed cholera case",
        "guidance": (
            "Notify the facility or district surveillance officer. Conduct case management based "
            "on the degree of the client's dehydration."
        ),
        "gate": {"CHOLSRV.C1.DE.12": "Confirmed case"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Confirmed cholera case - notify the surveillance officer",
        },
    },
    # --- measles, MSLSRV.E6.DT ------------------------------------------------
    {
        "rule": "MSLSRV.E6.DT",
        "survey": "msl-inv",
        "after": "MSLSRV.E6.DE.97",
        "code": "whodaksrv-ds-msl-confirmed",
        "name": "Laboratory-confirmed measles case",
        "guidance": (
            "Notify the facility or district surveillance team. Initiate case management as per treatment guidelines."
        ),
        "gate": {"MSLSRV.E6.DE.97": "Laboratory-confirmed measles case"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Laboratory-confirmed measles - notify the surveillance team",
        },
    },
    {
        "rule": "MSLSRV.E6.DT",
        "survey": "msl-inv",
        "after": "MSLSRV.E6.DE.97",
        "code": "whodaksrv-ds-msl-epi-linked",
        "name": "Epidemiologically linked measles case",
        "guidance": (
            "Notify the facility or district surveillance team. Initiate case management as per treatment guidelines."
        ),
        "gate": {"MSLSRV.E6.DE.97": "Epidemiologically linked measles case"},
    },
    {
        "rule": "MSLSRV.E6.DT",
        "survey": "msl-inv",
        "after": "MSLSRV.E6.DE.97",
        "code": "whodaksrv-ds-msl-clinically-compatible",
        "name": "Clinically compatible measles case",
        "guidance": (
            "Notify the facility or district surveillance team. Initiate case management as per "
            "treatment guidelines, and consider further testing or monitoring."
        ),
        "gate": {"MSLSRV.E6.DE.97": "Clinically compatible measles case"},
    },
    {
        "rule": "MSLSRV.E6.DT",
        "survey": "msl-inv",
        "after": "MSLSRV.E6.DE.97",
        "code": "whodaksrv-ds-msl-discarded",
        "name": "Non-measles discarded case",
        "guidance": (
            "Notify the facility or district surveillance team. Initiate case management as per "
            "treatment guidelines, and conduct further investigation to identify the disease."
        ),
        "gate": {"MSLSRV.E6.DE.97": "Non-measles discarded case"},
    },
    # --- bacterial meningitis, MENSRV.C2.DT -----------------------------------
    {
        "rule": "MENSRV.C2.DT",
        "survey": "men-inv",
        "after": "MENSRV.E6.DE.214",
        "code": "whodaksrv-ds-men-suspected",
        "name": "Suspected bacterial meningitis",
        "guidance": (
            "Collect CSF and perform initial diagnostic tests (for example Gram stain) "
            "immediately. Notify the facility or district surveillance team."
        ),
        "gate": {"MENSRV.E6.DE.214": "Suspected"},
    },
    {
        "rule": "MENSRV.C2.DT",
        "survey": "men-inv",
        "after": "MENSRV.E6.DE.214",
        "code": "whodaksrv-ds-men-probable",
        "name": "Probable bacterial meningitis",
        "guidance": (
            "Perform laboratory testing (PCR or culture) for confirmation. Notify the facility surveillance team."
        ),
        "gate": {"MENSRV.E6.DE.214": "Probable"},
    },
    {
        "rule": "MENSRV.C2.DT",
        "survey": "men-inv",
        "after": "MENSRV.E6.DE.214",
        "code": "whodaksrv-ds-men-confirmed",
        "name": "Confirmed bacterial meningitis",
        "guidance": ("Initiate clinical care as per treatment guidelines. Notify the facility surveillance team."),
        "gate": {"MENSRV.E6.DE.214": "Confirmed"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Confirmed bacterial meningitis - notify the surveillance team",
        },
    },
    # --- yellow fever, YFSRV.C2.DT --------------------------------------------
    {
        "rule": "YFSRV.C2.DT",
        "survey": "yf-case",
        "after": "YFSRV.C1.DE.24",
        "code": "whodaksrv-ds-yf-suspected",
        "name": "Suspected yellow fever case",
        "guidance": (
            "Notify the facility or district surveillance team and complete a case investigation "
            "form within 48 hours. Collect a blood sample for molecular testing (RT-PCR) and "
            "serological testing (IgM antibody) on first contact with the case."
        ),
        "gate": {"YFSRV.C1.DE.24": "Suspected case"},
    },
    {
        "rule": "YFSRV.C2.DT",
        "survey": "yf-case",
        "after": "YFSRV.C1.DE.24",
        "code": "whodaksrv-ds-yf-confirmed",
        "name": "Confirmed yellow fever case",
        "guidance": (
            "Notify the facility or district surveillance team. Initiate case management as per treatment guidelines."
        ),
        "gate": {"YFSRV.C1.DE.24": "Confirmed case"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Confirmed yellow fever case - notify the surveillance team",
        },
    },
]

# The Tamanu program registry — not from the DAK, which has no registry concept.
#
# What this registry holds is a **case**, not a client: a person is enrolled once per episode of
# one of the four diseases, and the same person is enrolled again if they present with another.
# That is the grain every indicator in Annex C counts, and it is why the clinical statuses are the
# case classification rather than a treatment pathway.
REGISTRY = {
    "registryCode": "who-dak-srv",
    "registryName": "WHO DAK Surveillance",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    # A surveillance case is closed by classification and outcome rather than abandoned, and the
    # kit has no element that says a case stopped being followed. Left off rather than given a
    # threshold this DAK does not state.
    "lossToFollowUpEnabled": False,
    # Where this case stands. The kit classifies a case twice — once against the case definition
    # when it presents, and once at `E6` when the clinical and laboratory data are in — and the
    # registry holds the second, whose values are the union of the four diseases' `Final case
    # classification` options. `Suspected` and `Confirmed` are on all four; `Probable` is
    # meningitis's and yellow fever's; `Discarded` covers cholera's `Not a suspected case`,
    # measles's `Non-measles discarded case` and yellow fever's own `Discarded`. Measles is the
    # one disease that classifies a case as measles without laboratory confirmation, so its
    # `Epidemiologically linked` and `Clinically compatible` are statuses of their own: neither
    # is confirmed, and neither is a case still under suspicion.
    #
    # `Recovered` and `Died` are the outcome, from `SRV.C13.DE.7 Outcome` (`Alive` / `Deceased`).
    "clinicalStatuses": [
        {"code": "who-dak-srv-suspected", "name": "Suspected case", "color": "yellow"},
        {"code": "who-dak-srv-probable", "name": "Probable case", "color": "orange"},
        {"code": "who-dak-srv-epi-linked", "name": "Epidemiologically linked case", "color": "pink"},
        {"code": "who-dak-srv-clinically-compatible", "name": "Clinically compatible case", "color": "brown"},
        {"code": "who-dak-srv-confirmed", "name": "Confirmed case", "color": "red"},
        {"code": "who-dak-srv-discarded", "name": "Discarded", "color": "grey"},
        {"code": "who-dak-srv-recovered", "name": "Recovered", "color": "green"},
        {"code": "who-dak-srv-died", "name": "Died", "color": "purple"},
    ],
    # Which disease the case is of, from the options of `SRV.C11.DE.1 Diagnosis` — the one element
    # the kit defines disease-agnostically and every disease's process records. `Other` is the
    # kit's own fifth option, and it is what a deployment adding a disease module of its own
    # records against until the kit publishes one.
    "conditions": [
        {"code": "who-dak-srv-cond-cholera", "name": "Cholera"},
        {"code": "who-dak-srv-cond-measles", "name": "Measles"},
        {"code": "who-dak-srv-cond-bacterial-meningitis", "name": "Bacterial meningitis"},
        {"code": "who-dak-srv-cond-yellow-fever", "name": "Yellow fever"},
        {"code": "who-dak-srv-cond-other", "name": "Other notifiable disease"},
    ],
    # Tamanu hard-loads unknown / disproven / resolved / recordedInError into every registry and
    # merges spreadsheet rows over them. Those four alone cannot express a *confirmed* condition,
    # so the case-classification progression is added. These codes are deliberately unprefixed:
    # Tamanu's UI carries labels for exactly these strings, and they are scoped per registry.
    "conditionCategories": [
        {"code": "suspected", "name": "Suspected"},
        {"code": "underInvestigation", "name": "Under investigation"},
        {"code": "confirmed", "name": "Confirmed"},
    ],
}
