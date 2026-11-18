"""The antenatal care domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's Annex A and B. What differs per
domain is which tabs become which surveys, which elements are worth carrying, which decision
rules are encodable, and the registry, which is a Tamanu construct with no DAK equivalent.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for antenatal care (2021).
# Publication: https://www.who.int/publications/i/item/9789240020306
DAK = {
    "title": "Digital adaptation kit for antenatal care (2021)",
    "elementPrefix": "ANC.",  # stripped from data element ids when deriving codes
}

# Web Annexes, fetched not committed (see ../../../.gitignore). Checksums are the copies these
# artefacts were generated from, so a WHO revision announces itself rather than quietly changing
# a form. `handle` is the IRIS handle; `url` is the DSpace bitstream content URL it resolves to.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "WHO-SRH-21.1-eng.xlsx",
        "handle": "10665/339740",
        "url": "https://iris.who.int/server/api/core/bitstreams/affcde61-7176-45c5-aac9-5503d2efc74d/content",
        "sha256": "eceb5d3594536c7010bfc7cc3894265701638f23f6dd27fca606bf1cbbe0d95f",
    },
    "B": {
        "name": "decision support logic",
        "filename": "WHO-SRH-21.2-eng.xlsx",
        "handle": "10665/339741",
        "url": "https://iris.who.int/server/api/core/bitstreams/e8520d08-bb73-451f-b042-00858b1c1f0f/content",
    },
    "C": {
        "name": "indicator table",
        "filename": "WHO-SRH-21.3-eng.xlsx",
        "handle": "10665/339742",
        "url": "https://iris.who.int/server/api/core/bitstreams/6597134f-d105-498e-a423-b5a2d526d8e2/content",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "WHO-SRH-21.4-eng.xlsx",
        "handle": "10665/339744",
        "url": "https://iris.who.int/server/api/core/bitstreams/e6a3be63-3945-4ca3-9608-922dafe67f36/content",
    },
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK ANC",
    "programCode": "who-dak-anc",
    "codePrefix": "whodakanc",  # question codes: whodakanc-b9-de34
}

# One survey per business process. Annex A has 10 `ANC.*` tabs; nine define patient encounter data
# and become forms. The one that does not:
#
#   ANC.Configuration  is deployment constants, not patient data - malaria and HIV prevalence in
#                      the population, whether ultrasound and each laboratory test are available
#                      at this site. One value per deployment, read by the decision logic, and
#                      belonging in settings or a dbt seed.
#
# `ANC.C. Referral` maps onto Tamanu's own `referral` survey type; the rest are `programs`.
PROCESSES = [
    {"tab": "ANC.A. Registration", "code": "registration", "name": "ANC Registration", "surveyType": "programs"},
    {"tab": "ANC.B5 Quick check", "code": "quickcheck", "name": "Quick Check", "surveyType": "programs"},
    {"tab": "ANC.B6 Profile", "code": "profile", "name": "Profile and History", "surveyType": "programs"},
    {
        "tab": "ANC.B7 Symptoms&Follow-up",
        "code": "symptoms",
        "name": "Symptoms and Follow-up",
        "surveyType": "programs",
    },
    {"tab": "ANC.B8 Physical exam", "code": "physicalexam", "name": "Physical Examination", "surveyType": "programs"},
    {
        "tab": "ANC.B9 Lab tests & imaging",
        "code": "labtests",
        "name": "Laboratory Tests and Imaging",
        "surveyType": "programs",
    },
    {
        "tab": "ANC.B10 Counselling & treatment",
        "code": "counselling",
        "name": "Counselling and Treatment",
        "surveyType": "programs",
    },
    {"tab": "ANC.C. Referral", "code": "referral", "name": "ANC Referral", "surveyType": "referral"},
    {"tab": "ANC.End", "code": "episodeend", "name": "ANC Episode Outcome", "surveyType": "programs"},
]

# This kit publishes Annex A as its *core* data dictionary, so there is no second, narrower list
# to consult: an element is carried when it is `Required = R` or feeds an Annex C indicator. The
# shortlist is used for one tab only.
#
# `ANC.End` describes how the pregnancy ended, and everything past the closure reason, the
# delivery date and the place of delivery is `Required = C` with no indicator link, so the first
# two rules select three questions and drop the outcome itself. That leaves a form that records
# that a woman delivered without recording how, and it leaves the registry's closure statuses -
# which are this tab's own `ANC.End.1` options - standing over nothing.
CORE_TABS = {"ANC.End"}

CORE_ELEMENTS = {
    "ANC.End.17",  # Preterm birth
    "ANC.End.18",  # Delivery mode
    "ANC.End.23",  # Birth weight
    "ANC.End.24",  # Exclusively breastfeeding
    "ANC.End.25",  # Delivery complications
    "ANC.End.38",  # Date of miscarriage or abortion
    "ANC.End.39",  # Date of death
    "ANC.End.40",  # Cause of death
}

# Types for the seven `ANC.B9` rows the dictionary types inconsistently. Every other member of
# the `<test> required` / `<test> ordered` / `<test> conducted` triplet is Boolean; these seven
# are left blank or declared `Coding` with no input options, either of which lands as a free-text
# box in the middle of a column of yes-no questions. The type comes from the sibling rows rather
# than from a judgement about the element, and lives here rather than in the generator so the
# divergence from Annex A is visible and reviewable. See dak-conformance.md.
ELEMENT_TYPES = {
    "ANC.B9.DE60": "Boolean",  # Hepatitis B test conducted - Coding, no options
    "ANC.B9.DE97": "Boolean",  # Syphilis test ordered - no data type
    "ANC.B9.DE114": "Boolean",  # Urine test conducted - Coding, no options
    "ANC.B9.DE115": "Boolean",  # Urine test ordered - no data type
    "ANC.B9.DE159": "Boolean",  # Blood glucose test conducted - Coding, no options
    "ANC.B9.DE160": "Boolean",  # Blood glucose test ordered - no data type
    "ANC.B9.DE195": "Boolean",  # TB screening ordered - no data type
}

# --- decision support (Annex B) ---------------------------------------------
# A form can prompt; it cannot conclude. Each rule shows the DAK's own guidance when its inputs
# are answered, and leaves the judgement with the clinician. See dak-conformance.md for what is
# not encodable and why.
DECISION_SUPPORT = [
    # ANC.DT.01 lists thirteen danger signs, and a gate naming all thirteen serialises to 275
    # characters against a varchar(255) `visibility_criteria` column. So the rule is emitted as two
    # prompts carrying the same guidance, split where the list crosses the limit rather than on any
    # clinical grouping - Annex B draws no distinction between them, and dropping signs to fit is
    # not an option when the point of the rule is that any one of them is urgent. A woman with
    # signs from both halves sees both prompts, which is the right failure.
    {
        "rule": "ANC.DT.01 (1 of 2)",
        "survey": "quickcheck",
        "after": "ANC.B5.DE48",
        "code": "whodakanc-ds-dt01-danger-signs-a",
        "name": "Danger sign - refer urgently",
        "guidance": (
            "This danger sign means the woman needs urgent management: refer her to hospital "
            "urgently, or continue the contact if clinical judgement says the sign can be managed "
            "here."
        ),
        "gate": {
            "ANC.B5.DE48": [
                "Bleeding vaginally",
                "Central cyanosis",
                "Convulsing",
                "Fever",
                "Imminent delivery",
                "Labour",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Danger sign recorded at ANC quick check"},
    },
    {
        "rule": "ANC.DT.01 (2 of 2)",
        "survey": "quickcheck",
        "after": "ANC.B5.DE48",
        "code": "whodakanc-ds-dt01-danger-signs-b",
        "name": "Danger sign - refer urgently",
        "guidance": (
            "This danger sign means the woman needs urgent management: refer her to hospital "
            "urgently, or continue the contact if clinical judgement says the sign can be managed "
            "here."
        ),
        "gate": {
            "ANC.B5.DE48": [
                "Looks very ill",
                "Severe headache",
                "Severe pain",
                "Severe vomiting",
                "Severe abdominal pain",
                "Unconscious",
                "Visual disturbance",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Danger sign recorded at ANC quick check"},
    },
    # ANC.DT.04 raises on systolic >= 140 *or* diastolic >= 90, and a gate spanning two questions
    # is a conjunction, so each measurement carries its own prompt. The ceilings are formalities:
    # a range gate stops firing above its end, and the reading that most needs the prompt is the
    # extreme one, so each names a value no sphygmomanometer reports rather than one at the edge
    # of the plausible range.
    {
        "rule": "ANC.DT.04",
        "survey": "physicalexam",
        "after": "ANC.B8.DE17",
        "code": "whodakanc-ds-dt04-systolic",
        "name": "Systolic blood pressure 140 or above - measure again",
        "guidance": (
            "Let the woman rest for 10-15 minutes and measure her blood pressure again. Record "
            "the second reading in the repeat blood pressure fields below."
        ),
        "gate": {"ANC.B8.DE17": {"type": "range", "start": 140, "end": 1000}},
    },
    {
        "rule": "ANC.DT.04",
        "survey": "physicalexam",
        "after": "ANC.B8.DE19",
        "code": "whodakanc-ds-dt04-diastolic",
        "name": "Diastolic blood pressure 90 or above - measure again",
        "guidance": (
            "Let the woman rest for 10-15 minutes and measure her blood pressure again. Record "
            "the second reading in the repeat blood pressure fields below."
        ),
        "gate": {"ANC.B8.DE19": {"type": "range", "start": 90, "end": 1000}},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct, and this is our own modelling of
# the pregnancy episode. Clinical status and condition codes are prefixed with the registry code
# because `prClinicalStatus-<code>` is a global id and the status code is unique database-wide.
REGISTRY = {
    "registryCode": "who-dak-anc",
    "registryName": "WHO DAK ANC",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    "lossToFollowUpThresholdDays": 56,
    # One open state, then the outcomes `ANC.End.1 Reason for closing ANC record` lists, so a
    # closure recorded on the form has a status to move the registration to. Coloured so the
    # episode ANC exists to reach reads as the good state and every loss reads as warm or dark.
    "clinicalStatuses": [
        {"code": "who-dak-anc-attending", "name": "Attending ANC", "color": "green"},
        {"code": "who-dak-anc-live-birth", "name": "Live birth", "color": "blue"},
        {"code": "who-dak-anc-stillbirth", "name": "Stillbirth", "color": "brown"},
        {"code": "who-dak-anc-miscarriage", "name": "Miscarriage", "color": "orange"},
        {"code": "who-dak-anc-abortion", "name": "Abortion", "color": "yellow"},
        {"code": "who-dak-anc-died", "name": "Woman died", "color": "purple"},
        {"code": "who-dak-anc-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-anc-moved-away", "name": "Moved away", "color": "teal"},
        {"code": "who-dak-anc-false-pregnancy", "name": "False pregnancy", "color": "pink"},
    ],
    # The conditions the DAK diagnoses or asks after, which the registry carries across contacts
    # rather than holding only what was recorded today. Each traces to a diagnosis element in
    # Annex A or to an option of `ANC.B6.DE83 Existing chronic health conditions`.
    "conditions": [
        {"code": "who-dak-anc-cond-anaemia", "name": "Anaemia"},
        {"code": "who-dak-anc-cond-asb", "name": "Asymptomatic bacteriuria"},
        {"code": "who-dak-anc-cond-gdm", "name": "Gestational diabetes mellitus"},
        {"code": "who-dak-anc-cond-diabetes", "name": "Diabetes mellitus (pre-existing)"},
        {"code": "who-dak-anc-cond-hypertension", "name": "Hypertension"},
        {"code": "who-dak-anc-cond-severe-hypertension", "name": "Severe hypertension"},
        {"code": "who-dak-anc-cond-pre-eclampsia", "name": "Pre-eclampsia"},
        {"code": "who-dak-anc-cond-severe-pre-eclampsia", "name": "Severe pre-eclampsia"},
        {"code": "who-dak-anc-cond-hiv", "name": "HIV"},
        {"code": "who-dak-anc-cond-syphilis", "name": "Syphilis"},
        {"code": "who-dak-anc-cond-hbv", "name": "Hepatitis B (HBV)"},
        {"code": "who-dak-anc-cond-hcv", "name": "Hepatitis C (HCV)"},
        {"code": "who-dak-anc-cond-tb", "name": "Tuberculosis"},
        {"code": "who-dak-anc-cond-epilepsy", "name": "Epilepsy"},
        {"code": "who-dak-anc-cond-kidney-disease", "name": "Kidney disease"},
        {"code": "who-dak-anc-cond-autoimmune", "name": "Autoimmune disease"},
        {"code": "who-dak-anc-cond-blood-disorder", "name": "Blood disorder"},
        {"code": "who-dak-anc-cond-cancer-gynaecological", "name": "Cancer - gynaecological"},
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
