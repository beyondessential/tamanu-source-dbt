"""The postnatal care domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit is not published as IRIS Web Annexes. WHO ships it as an implementation-guide site, and
the four components are downloads from that site rather than annexe A-D spreadsheets — see
`dak-conformance.md` § Fetching the components.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for postnatal care (2025), DAK version 1.0.0.
# Publication: https://www.who.int/publications/i/item/9789240090347
DAK = {
    "title": "Digital adaptation kit for postnatal care (2025)",
    "elementPrefix": "PNC.",  # stripped from data element ids when deriving codes
}

# The kit's four components, fetched not committed (see ../../../.gitignore). `url` is the
# versioned path on WHO's SMART guidelines site; `page` is the human-facing component page that
# links it. The sha256 is the copy these artefacts were generated from, so a WHO revision
# announces itself rather than quietly changing a form.
#
# `handle` is the IRIS handle of the *publication*, which carries only the PDF: unlike the HIV and
# ANC kits, this one has no annexe items in IRIS at all.
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
PROGRAM = {
    "programName": "WHO DAK PNC",
    "programCode": "who-dak-pnc",
    "codePrefix": "whodakpnc",  # question codes: whodakpnc-b4a-de-1
}

# One survey per maternal business process. The kit has 16 `PNC.*` tabs: ten define the woman's
# encounter data and become forms here, five define the newborn's and are in
# `../pnc-newborn/domain.py`, and one does not become a form at all:
#
#   PNC Configuration  is deployment constants, not patient data - population prevalence of
#                      gestational diabetes, of HIV, of schistosomiasis, and which services this
#                      site offers. One value per site, read by the decision logic, and belonging
#                      in settings or a dbt seed.
#
# The kit splits every assessment by subject, `a` for the woman and `b` for the newborn/infant: a
# Tamanu survey submits against one patient, so a maternal and a neonatal assessment cannot share a
# form, which is why the two subjects are two separate programs. Each subject's assessments are
# further split by contact, `B` for the first contact and `D` for a follow-up, since the two contact
# types are separate business processes with separate data elements in the dictionary.
PROCESSES = [
    {"tab": "PNC.A.Registration", "code": "registration", "name": "PNC Registration", "surveyType": "programs"},
    {
        "tab": "PNC.B1.Profile & health hist",
        "code": "profile",
        "name": "Maternal Profile and Health History",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B2.Preg,labour&birthinfo",
        "code": "birthinfo",
        "name": "Pregnancy, Labour and Birth Information",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B3a.Mat_symptomswellbeing",
        "code": "matsymptoms",
        "name": "Maternal Symptoms and Wellbeing",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B4a.Maternal Physical Exam",
        "code": "matexam",
        "name": "Maternal Physical Examination",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B6a. Maternal C & Treat",
        "code": "mattreatment",
        "name": "Maternal Care and Treatment",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.B7.Non-emergencyReferral",
        "code": "referral",
        "name": "PNC Referral",
        "surveyType": "referral",
    },
    {
        "tab": "PNC.C1. Emergency Referral",
        "code": "emergencyreferral",
        "name": "PNC Emergency Referral",
        "surveyType": "referral",
    },
    {
        "tab": "PNC.D3a. Follow-upMat_sympwell",
        "code": "fumatsymptoms",
        "name": "Maternal Symptoms and Wellbeing (follow-up)",
        "surveyType": "programs",
    },
    {
        "tab": "PNC.D4a. Follow-up Mat_PE",
        "code": "fumatexam",
        "name": "Maternal Physical Examination (follow-up)",
        "surveyType": "programs",
    },
]

# This kit publishes its dictionary as the core list, so as with the ANC kit there is no second,
# narrower shortlist to consult: an element is carried when it is `Required = R` or feeds an
# indicator. The kit marks 206 elements Required, so the shortlist is needed on two tabs only.
#
# Every danger-sign element in the kit is `Required = C`, and the two on the reception tab carry
# no indicator link either, so the first two rules drop them. That would leave the registration
# form asking why the woman came and nothing else, and would leave the kit's own `PNC.A2.DT.01`
# and `PNC.A2.DT.12` triggers with nothing to fire on — the one thing reception exists to catch.
# `PNC.B4a.DE.1` is the same maternal list repeated on the physical exam, carried because its
# newborn counterpart `PNC.B4b.DE.1` — in `../pnc-newborn/domain.py`'s CORE_ELEMENTS — is
# `Required = R` and one exam should not screen for danger signs while the other does not.
CORE_TABS = {"PNC.A.Registration", "PNC.B4a.Maternal Physical Exam"}

CORE_ELEMENTS = {
    "PNC.A2.DE.8",  # Specific health concern(s) - why she came, in the kit's own vocabulary
    "PNC.A2.DE.60",  # Woman's danger signs
    "PNC.A2.DE.74",  # Newborn's/infant's danger signs
    "PNC.B4a.DE.1",  # Woman's danger signs, on the physical exam
}

# This kit types every element the maternal tabs mean to collect, so nothing needs a type supplied
# here. Its untyped rows are all section headings, which the reader recognises by the absence of a
# type.
ELEMENT_TYPES: dict[str, str] = {}

# --- decision support -------------------------------------------------------
# A form can prompt; it cannot conclude. `PNC.A2.DT.01` and `PNC.A2.DT.12` are the kit's own
# danger-sign triggers, anchored at reception and referenced from the physical-exam tabs, so both
# prompts sit on the registration form where the signs are first recorded.
#
# The newborn rule is emitted as three prompts. Its fifteen danger signs serialise to 536
# characters against a varchar(255) `visibility_criteria` column, so the list is split where it
# crosses the limit rather than on any clinical grouping - the kit draws no distinction between
# them, and dropping signs to fit is not an option when the point of the rule is that any one of
# them is urgent. A newborn with signs from two chunks raises two prompts, which is the right
# failure. The maternal list fits in one.
#
# `No danger signs` and `Other (specify)` are excluded from every gate: the first is the option
# that means the rule should not fire, and the second carries no sign to act on.
DECISION_SUPPORT = [
    {
        "rule": "PNC.A2.DT.01",
        "survey": "registration",
        "after": "PNC.A2.DE.60",
        "code": "whodakpnc-ds-dt01-maternal-danger-signs",
        "name": "Maternal danger sign - refer urgently",
        "guidance": (
            "This danger sign means the woman needs urgent management. Start emergency treatment "
            "and refer her to hospital urgently."
        ),
        "gate": {
            "PNC.A2.DE.60": [
                "Bleeding vaginally",
                "Central cyanosis",
                "Convulsing",
                "Fever",
                "Looks very ill",
                "Severe headache",
                "Severe pain",
                "Severe vomiting",
                "Severe abdominal pain",
                "Unconscious",
                "Visual disturbance",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Maternal danger sign recorded at PNC reception"},
    },
    {
        "rule": "PNC.A2.DT.12 (1 of 3)",
        "survey": "registration",
        "after": "PNC.A2.DE.74",
        "code": "whodakpnc-ds-dt12-newborn-danger-signs-a",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.A2.DE.74": [
                "Noise breath (grunting, stridor)",
                "Cyanosis",
                "Slow breathing, gasping, apnoea",
                "Flaring of the nostrils with each breath",
                "Not able to feed at all or not feeding well",
                "Fits or convulsions",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign recorded at PNC reception"},
    },
    {
        "rule": "PNC.A2.DT.12 (2 of 3)",
        "survey": "registration",
        "after": "PNC.A2.DE.74",
        "code": "whodakpnc-ds-dt12-newborn-danger-signs-b",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.A2.DE.74": [
                "Abdominal overdistension",
                "Fast breathing (breathing rate ≥ 60/min)",
                "Severe chest in-drawing",
                "Movement only when stimulated or no movement at all",
                "Draining purulent from stump or cut",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign recorded at PNC reception"},
    },
    {
        "rule": "PNC.A2.DT.12 (3 of 3)",
        "survey": "registration",
        "after": "PNC.A2.DE.74",
        "code": "whodakpnc-ds-dt12-newborn-danger-signs-c",
        "name": "Newborn danger sign - refer urgently",
        "guidance": (
            "This danger sign means the newborn needs urgent management. Start emergency treatment "
            "and refer to hospital urgently."
        ),
        "gate": {
            "PNC.A2.DE.74": [
                "Bleeding from stump or cut",
                "Fever",
                "Low body temperature",
                "Any jaundice or yellow palms and soles",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Newborn danger sign recorded at PNC reception"},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct, and this is our own modelling of
# the postnatal episode. Clinical status and condition codes are prefixed with the registry code
# because `prClinicalStatus-<code>` is a global id and the status code is unique database-wide.
#
# This registry is the **woman's** postnatal episode. The newborn is a separate Tamanu patient with
# a registry of its own, in `../pnc-newborn/domain.py`.
REGISTRY = {
    "registryCode": "who-dak-pnc",
    "registryName": "WHO DAK PNC",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    "lossToFollowUpThresholdDays": 28,
    # Where the woman is in the postnatal episode. The kit defines no closing element of its own -
    # unlike the ANC kit, which ends its record with `ANC.End.1` - so these are the states its care
    # pathway distinguishes: in care, referred out, finished, or lost.
    "clinicalStatuses": [
        {"code": "who-dak-pnc-attending", "name": "Attending PNC", "color": "green"},
        {"code": "who-dak-pnc-referred", "name": "Referred", "color": "orange"},
        {"code": "who-dak-pnc-completed", "name": "PNC completed", "color": "blue"},
        {"code": "who-dak-pnc-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-pnc-transferred-out", "name": "Transferred out", "color": "teal"},
        {"code": "who-dak-pnc-died", "name": "Woman died", "color": "purple"},
    ],
    # The conditions the kit's decision logic concludes about the woman, which the registry carries
    # across contacts rather than holding only what was recorded today. Each traces to a
    # `PNC.B6a` suggested diagnosis. Six are shared with the ANC registry by design: the same woman
    # carries hypertension, pre-eclampsia, anaemia, HIV, tuberculosis and syphilis from one episode
    # into the next, and the two registries should name them the same way.
    "conditions": [
        {"code": "who-dak-pnc-cond-hypertension", "name": "Hypertension"},
        {"code": "who-dak-pnc-cond-severe-hypertension", "name": "Severe hypertension"},
        {"code": "who-dak-pnc-cond-pre-eclampsia", "name": "Pre-eclampsia"},
        {"code": "who-dak-pnc-cond-severe-pre-eclampsia", "name": "Severe pre-eclampsia"},
        {"code": "who-dak-pnc-cond-anaemia", "name": "Anaemia"},
        {"code": "who-dak-pnc-cond-hiv", "name": "HIV"},
        {"code": "who-dak-pnc-cond-tb", "name": "Tuberculosis"},
        {"code": "who-dak-pnc-cond-syphilis", "name": "Syphilis"},
        {"code": "who-dak-pnc-cond-postpartum-infection", "name": "Postpartum infection"},
        {"code": "who-dak-pnc-cond-uterine-infection", "name": "Uterine infection"},
        {"code": "who-dak-pnc-cond-perineal-infection", "name": "Perineal infection"},
        {"code": "who-dak-pnc-cond-wound-infection", "name": "Caesarean-section wound infection"},
        {"code": "who-dak-pnc-cond-postpartum-bleeding", "name": "Postpartum bleeding"},
        {"code": "who-dak-pnc-cond-respiratory-infection", "name": "Respiratory tract infection"},
        {"code": "who-dak-pnc-cond-postnatal-depression", "name": "Postnatal depression or anxiety"},
        {"code": "who-dak-pnc-cond-alloimmunization", "name": "Risk of alloimmunization"},
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
