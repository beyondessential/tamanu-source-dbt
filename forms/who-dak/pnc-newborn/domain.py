"""The newborn half of the WHO DAK postnatal care kit: its own Tamanu program and registry.

The kit assesses two patients at every contact and splits every assessment tab `a` maternal /
`b` neonatal. A Tamanu survey submits against one patient and a program carries one registry, so
the two halves are two programs: [`../pnc/`](../pnc/domain.py) is the woman's, this is the
newborn's. Both read the same dictionary — `ANNEXES` here is a copy of that domain's, pointing at
the same file and checksum.

The split is not cosmetic. The registry is what makes a newborn's state survive between contacts,
and without a program of its own there is nowhere for it to live.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for postnatal care (2025), DAK version 1.0.0.
# Publication: https://www.who.int/publications/i/item/9789240090347
DAK = {
    "title": "Digital adaptation kit for postnatal care (2025)",
    "elementPrefix": "PNC.",
}

# Not IRIS Web Annexes: WHO ships this kit as an implementation-guide site. See
# `dak-conformance.md` § Fetching the components in the sibling domain.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "PNC DAK_core data dictionary.xlsx",
        "handle": "10665/381725",
        "page": "https://smart.who.int/dak-pnc/dictionary.html",
        "url": "https://smart.who.int/dak-pnc/v1.0.0/PNC%20DAK_core%20data%20dictionary.xlsx",
        "sha256": "fb01d97a20b846716a05db5d94d571d6459373c50d2f0d4962b69f783a454b3f",
    },
    "B": {
        "name": "decision-support logic",
        "filename": "PNC DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-pnc/decision-logic.html",
        "url": "https://smart.who.int/dak-pnc/v1.0.0/PNC%20DAK_decision-support%20logic.xlsx",
    },
    "C": {
        "name": "indicators",
        "filename": "PNC DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-pnc/indicators.html",
        "url": "https://smart.who.int/dak-pnc/v1.0.0/PNC%20DAK_indicators.xlsx",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "PNC DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-pnc/system-requirements.html",
        "url": "https://smart.who.int/dak-pnc/v1.0.0/PNC%20DAK_functional%20and%20non-functional%20requirements.xlsx",
    },
}

# --- the Tamanu program -----------------------------------------------------
# A distinct code prefix, so the same data element becomes a distinct question here and in the
# maternal program: `PNC.B4b.DE.1` is `whodakpncnb-b4b-de-1`, never `whodakpnc-b4b-de-1`. Codes
# are global upsert keys, and one element cannot belong to two programs' questions.
PROGRAM = {
    "programName": "WHO DAK PNC (newborn)",
    "programCode": "who-dak-pnc-newborn",
    "codePrefix": "whodakpncnb",
}

# The kit's five neonatal tabs. Everything else in the dictionary describes the woman, or the
# contact as a whole, and stays in the maternal program.
PROCESSES = [
    {
        "tab": "PNC.B3b.Nb_symptomswellbeing",
        "code": "nbsymptoms",
        "name": "Newborn Symptoms and Wellbeing",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B4b. Neonatal Physical Exam",
        "code": "nbexam",
        "name": "Newborn Physical Examination",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B6b.Neonatal C & Treat",
        "code": "nbtreatment",
        "name": "Newborn Care and Treatment",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.D3b.Follow-upNb_Inf sympwel",
        "code": "funbsymptoms",
        "name": "Newborn Symptoms and Wellbeing (follow-up)",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.D4b.Follow-up Nb_Inf PE",
        "code": "funbexam",
        "name": "Newborn Physical Examination (follow-up)",
        "surveyType": "programs",
    },
]

# The kit marks the whole newborn examination Required, so `Required = R` selects everything these
# tabs need and no shortlist is called for.
CORE_TABS: set[str] = set()
CORE_ELEMENTS: set[str] = set()

# PNC.B3b.DE.54 "Feeding mode" is Required = R with five options (Directly at breast, Bottle,
# Alternative method, Enteral feeding, Other) immediately after it, but the dictionary leaves its
# own Data Type blank. Untyped and unmarked, it reads as a section heading, which drops a mandatory
# question from the form entirely and leaves its five options with no parent of their own to
# attach to - they fall back onto whichever Coding question came before it.
ELEMENT_TYPES: dict[str, str] = {
    "PNC.B3b.DE.54": "Coding",
}

# --- decision support -------------------------------------------------------
# `PNC.B4b.DE.1 Newborn's danger signs` is the kit's `PNC.A2.DT.12` trigger as it appears on the
# physical exam. Reception's copy of the same rule stays with the maternal program, where the
# reception tab is; this is the one a clinician meets when examining the newborn.
#
# Three prompts, because the fifteen signs overrun the varchar(255) `visibility_criteria` column.
# The list is split where it crosses the limit rather than on any clinical grouping, and all three
# carry the same guidance - dropping signs to fit is not an option when the point of the rule is
# that any one of them is urgent. `None` and `Other (specify)` are excluded from every gate.
DECISION_SUPPORT = [
    {
        "rule": "PNC.A2.DT.12 (1 of 3)",
        "survey": "nbexam",
        "after": "PNC.B4b.DE.1",
        "code": "whodakpncnb-ds-dt12-danger-signs-a",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.B4b.DE.1": [
                "Noise breath (grunting, stridor)",
                "Cyanosis (central)",
                "Slow breathing, gasping, apnoea",
                "Flaring of the nostrils with each breath",
                "Not able to feed at all or not feeding well",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign found on examination"},
    },
    {
        "rule": "PNC.A2.DT.12 (2 of 3)",
        "survey": "nbexam",
        "after": "PNC.B4b.DE.1",
        "code": "whodakpncnb-ds-dt12-danger-signs-b",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.B4b.DE.1": [
                "Fits or convulsions",
                "Abdominal overdistension",
                "Fast breathing (breathing rate ≥ 60/min)",
                "Severe chest in-drawing",
                "Movement only when stimulated or no movement at all",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign found on examination"},
    },
    {
        "rule": "PNC.A2.DT.12 (3 of 3)",
        "survey": "nbexam",
        "after": "PNC.B4b.DE.1",
        "code": "whodakpncnb-ds-dt12-danger-signs-c",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.B4b.DE.1": [
                "Draining purulent from stump or cut",
                "Bleeding from stump or cut",
                "Fever/high body temperature (37.5 °C)",
                "Low body temperature (< 35.5 °C)",
                "Any jaundice in the first 24h after birth",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign found on examination"},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct. This is the newborn's postnatal
# episode, and the reason this program exists at all.
REGISTRY = {
    "registryCode": "who-dak-pnc-newborn",
    "registryName": "WHO DAK PNC (newborn)",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    "lossToFollowUpThresholdDays": 28,
    # The same states as the maternal episode, which is deliberate: mother and newborn are seen at
    # one contact, so a service that has lost one has usually lost both, and reading the two
    # registries side by side is easier when the vocabulary matches.
    "clinicalStatuses": [
        {"code": "who-dak-pnc-newborn-in-care", "name": "In postnatal care", "color": "green"},
        {"code": "who-dak-pnc-newborn-referred", "name": "Referred", "color": "orange"},
        {"code": "who-dak-pnc-newborn-completed", "name": "Postnatal care completed", "color": "blue"},
        {"code": "who-dak-pnc-newborn-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-pnc-newborn-transferred-out", "name": "Transferred out", "color": "teal"},
        {"code": "who-dak-pnc-newborn-died", "name": "Died", "color": "purple"},
    ],
    # What the newborn is carrying between contacts, each tracing to a `PNC.B6b` suggested
    # diagnosis. The kit's transient exam findings - `Abnormal <site> finding`, mild hypothermia,
    # sleeping uncomfortably - are what one contact observed and stay on that contact's form, the
    # same rule the maternal registry follows.
    "conditions": [
        {"code": "who-dak-pnc-newborn-cond-preterm", "name": "Preterm birth"},
        {"code": "who-dak-pnc-newborn-cond-small-for-age", "name": "Small for gestational age"},
        {"code": "who-dak-pnc-newborn-cond-very-low-weight", "name": "Very low weight"},
        {"code": "who-dak-pnc-newborn-cond-jaundice", "name": "Neonatal jaundice"},
        {"code": "who-dak-pnc-newborn-cond-serious-illness", "name": "Possible serious illness"},
        {"code": "who-dak-pnc-newborn-cond-bacterial-infection", "name": "Risk of bacterial infection"},
        {"code": "who-dak-pnc-newborn-cond-umbilical-infection", "name": "Umbilical cord infection"},
        {"code": "who-dak-pnc-newborn-cond-gonococcal-eye", "name": "Gonococcal eye infection"},
        {"code": "who-dak-pnc-newborn-cond-congenital-syphilis", "name": "Risk of congenital syphilis"},
        {"code": "who-dak-pnc-newborn-cond-hiv-exposure", "name": "Risk of HIV transmission"},
        {"code": "who-dak-pnc-newborn-cond-tb-exposure", "name": "Risk of tuberculosis"},
        {"code": "who-dak-pnc-newborn-cond-club-foot", "name": "Club foot"},
        {"code": "who-dak-pnc-newborn-cond-cleft-lip-palate", "name": "Cleft lip or palate"},
        {"code": "who-dak-pnc-newborn-cond-malformation", "name": "Congenital malformation (other)"},
        {"code": "who-dak-pnc-newborn-cond-hearing-impairment", "name": "Suspected hearing impairment"},
        {"code": "who-dak-pnc-newborn-cond-eye-abnormality", "name": "Eye abnormality"},
    ],
    # Tamanu hard-loads unknown / disproven / resolved / recordedInError into every registry and
    # merges spreadsheet rows over them. Those four alone cannot express a *confirmed* condition,
    # so the standard clinical progression is added. These codes are deliberately unprefixed:
    # Tamanu's UI carries labels for exactly these strings, and they are scoped per registry.
    "conditionCategories": [
        {"code": "suspected", "name": "Suspected"},
        {"code": "underInvestigation", "name": "Under investigation"},
        {"code": "confirmed", "name": "Confirmed"},
        {"code": "inRemission", "name": "In remission"},
    ],
}
