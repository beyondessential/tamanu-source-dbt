"""The HIV domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's Annex A and B. What differs per
domain is which tabs become which surveys, which elements are worth carrying, which decision
rules are encodable, and the registry, which is a Tamanu construct with no DAK equivalent.

A second domain (TB, ANC, family planning) is a sibling directory holding a module like this one.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for HIV, second edition (2023).
# Publication: https://www.who.int/publications/i/item/9789240085138
DAK = {
    "title": "Digital adaptation kit for HIV, second edition (2023)",
    "elementPrefix": "HIV.",  # stripped from data element ids when deriving codes
}

# Web Annexes, fetched not committed (see ../../../.gitignore). Checksums are the copies these
# artefacts were generated from, so a WHO revision announces itself rather than quietly changing
# a form. `handle` is the IRIS handle; `url` is the DSpace bitstream content URL it resolves to.
ANNEXES = {
    "A": {
        "name": "data dictionary",
        "filename": "WHO-UCN-HHS-SIA-2023.27-eng.xlsx",
        "handle": "10665/375056",
        "url": "https://iris.who.int/server/api/core/bitstreams/e9b0d20e-32ab-4d66-a5b6-638d39b0b443/content",
        "sha256": "a86a726d2cbbc487c232c9b5fe3304bb2061d192efbb7bf3ab8353dd6638e40e",
    },
    "B": {
        "name": "decision support logic",
        "filename": "WHO-UCN-HHS-SIA-2023.28-eng.xlsx",
        "handle": "10665/375057",
    },
    "C": {
        "name": "indicators and performance metrics",
        "filename": "WHO-UCN-HHS-SIA-2023.29-eng.xlsx",
        "handle": "10665/375058",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "WHO-UCN-HHS-SIA-2023.30-eng.xlsx",
        "handle": "10665/375059",
    },
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK HIV",
    "programCode": "who-dak-hiv",
    "codePrefix": "whodakhiv",  # question codes: whodakhiv-d-de39
}

# One survey per business process. Annex A has 12 `HIV.*` tabs; ten define patient encounter data
# and become forms. The two that do not:
#
#   HIV.Surveillance   defines no data elements of its own - its rows re-list elements owned by
#                      other processes as a cross-cutting reporting view. There is no form in it.
#   HIV.Configuration  is deployment constants, not patient data - population prevalence of TB,
#                      population HIV incidence, prevalence of pretreatment NNRTI resistance,
#                      malaria-endemic setting. One value per deployment, read by the decision
#                      logic, and belonging in settings or a dbt seed.
#
# `HIV.I Referral` maps onto Tamanu's own `referral` survey type; the rest are `programs`.
PROCESSES = [
    {"tab": "HIV.A Registration", "code": "registration", "name": "HIV Registration", "surveyType": "programs"},
    {"tab": "HIV.B HTS visit", "code": "htsvisit", "name": "HIV Testing Services Visit", "surveyType": "programs"},
    {"tab": "HIV.C PrEP visit", "code": "prepvisit", "name": "PrEP Visit", "surveyType": "programs"},
    {
        "tab": "HIV.D Care-Treatment",
        "code": "carevisit",
        "name": "HIV Care and Treatment Visit",
        "surveyType": "programs",
    },
    {"tab": "HIV.D HIV-TB", "code": "hivtb", "name": "HIV-TB Coinfection", "surveyType": "programs"},
    {"tab": "HIV.E-F PMTCT", "code": "pmtct", "name": "PMTCT, Delivery and Infant Diagnosis", "surveyType": "programs"},
    {"tab": "HIV.G Diagnostics", "code": "diagnostics", "name": "HIV Diagnostics", "surveyType": "programs"},
    {"tab": "HIV.H Follow-up", "code": "followup", "name": "Follow-up and Contact Tracing", "surveyType": "programs"},
    {"tab": "HIV.I Referral", "code": "referral", "name": "HIV Referral", "surveyType": "referral"},
    {"tab": "HIV.Prevention", "code": "prevention", "name": "HIV Prevention", "surveyType": "programs"},
]

# Component 5 Table 11 only itemises the HIV.D process, so the core-shortlist half of the
# selection rule applies to those two tabs alone.
CORE_TABS = {"HIV.D Care-Treatment", "HIV.D HIV-TB"}

# The DAK's own "core data elements" shortlist (Component 5, Table 11), which keeps clinically
# central elements the Required/indicator rules miss - HIV clinical stage is Required=O with no
# indicator linkage.
#
# HIV.D.DE481 is not on that shortlist and carries no indicator link, so neither rule selects
# it. Annex C's ART.9 numerator names it: without the first-line substitution date, a toxicity
# switch on first-line treatment is invisible and the indicator undercounts silently while
# still returning a number. Second- and third-line substitution dates are selected already.
CORE_ELEMENTS = {
    "HIV.D.DE1",
    "HIV.D.DE481",
    "HIV.D.DE8",
    "HIV.D.DE17",
    "HIV.D.DE38",
    "HIV.D.DE39",
    "HIV.D.DE46",
    "HIV.D.DE50",
    "HIV.D.DE65",
    "HIV.D.DE75",
    "HIV.D.DE161",
    "HIV.D.DE162",
    "HIV.D.DE169",
    "HIV.D.DE170",
    "HIV.D.DE186",
    "HIV.D.DE217",
    "HIV.D.DE225",
    "HIV.D.DE364",
    "HIV.D.DE387",
    "HIV.D.DE399",
    "HIV.D.DE457",
    "HIV.D.DE466",
    "HIV.D.DE496",
    "HIV.D.DE524",
    "HIV.D.DE537",
    "HIV.D.DE560",
    "HIV.D.DE604",
    "HIV.D.DE605",
    "HIV.D.DE607",
    "HIV.D.DE610",
    "HIV.D.DE643",
    "HIV.D.DE656",
    "HIV.D.DE947",
    "HIV.D.DE973",
    "HIV.D.DE990",
    # Activity HIV.D2 "Take vital signs" - Table 11 names the activity rather than itemising it,
    # and the DAK's step 2 says "also record weight, height, etc.". Without these the vital signs
    # screen is body weight alone, the rest being Required=O/C with no indicator linkage.
    "HIV.D.DE9",
    "HIV.D.DE10",
    "HIV.D.DE11",
    "HIV.D.DE12",
    "HIV.D.DE14",
    "HIV.D.DE15",
    # Concepts Table 11 names but which carry no indicator link: the prescribing decision, why
    # adherence failed, the counselling that pairs with DE496, and the DAK's measurable proxy for
    # nutritional status (activity HIV.D18).
    "HIV.D.DE197",
    "HIV.D.DE444",
    "HIV.D.DE465",
    "HIV.D.DE884",
}

# --- decision support (Annex B) ---------------------------------------------
# A form can prompt; it cannot conclude. Each rule shows the DAK's own guidance when its inputs
# are answered, and leaves the judgement with the clinician - HIV.D17.DT.01 fires on a viral load
# above 1000 "based on two consecutive measurements three months apart", and the history is not
# visible inside one submission. See dak-conformance.md for what is not encodable and why.
DECISION_SUPPORT = [
    {
        "rule": "HIV.B2.DT.01-05",
        "survey": "carevisit",
        "after": "HIV.D.DE17",
        "code": "whodakhiv-ds-b2-serious-illness-10-and-over",
        "name": "Danger sign, 10 years and over - act or refer now",
        "guidance": (
            "For a client aged 10 years or over: immediately take action or refer for care. Use "
            "clinical judgement and local epidemiology to decide whether these signs mean the "
            "client is seriously ill."
        ),
        # Annex B splits HIV.B2.DT by age and a visibility gate cannot: age lives on the patient
        # record, not on the form. So each age band gets its own prompt, gated on the signs
        # Annex B lists for it, and the guidance names the band. Splitting rather than taking
        # the union because the union is 270 characters and visibilityCriteria is varchar(255) --
        # and dropping signs to fit is what left convulsions and high fever ungated before.
        #
        # Three signs appear in both bands, which is Annex B's own doing (rules 01, 02, 05 and
        # 12, 13, 14), so a client with tachycardia sees both prompts. Two prompts on a danger
        # sign is the right failure.
        "gate": {
            "HIV.D.DE17": [
                "Tachycardia",
                "Tachypnea",
                "Unable to walk unaided",
                "Fever of 39 C or greater",
                "Other sign of serious illness",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Danger sign recorded on HIV care visit"},
    },
    {
        "rule": "HIV.B2.DT.06-14",
        "survey": "carevisit",
        "after": "HIV.D.DE17",
        "code": "whodakhiv-ds-b2-serious-illness-under-10",
        "name": "Danger sign, under 10 years - act or refer now",
        "guidance": (
            "For a client under 10 years: immediately take action or refer for care. Use clinical "
            "judgement and local epidemiology to decide whether these signs mean the client is "
            "seriously ill."
        ),
        "gate": {
            "HIV.D.DE17": [
                "Lethargy",
                "Unconsciousness",
                "Convulsions",
                "Unable to breastfeed",
                "Unable to drink",
                "Repeated vomiting",
                "Tachycardia",
                "Tachypnea",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Danger sign recorded on HIV care visit"},
    },
    {
        "rule": "HIV.D17.DT.01",
        "survey": "carevisit",
        "after": "HIV.D.DE387",
        "code": "whodakhiv-ds-d17-viral-failure",
        "name": "Viral load above 1000 - evaluate for virological failure",
        "guidance": (
            "Evaluate client for virological failure. WHO defines this as viral load above "
            "1000 copies/mL on two consecutive measurements three months apart, with adherence "
            "support after the first - check the previous result before concluding."
        ),
        # The ceiling is a formality, not a clinical bound: a range gate stops firing above its
        # end, and acute infection can carry a viral load past ten million copies/mL -- the
        # client who most needs the prompt. DE387 declares no maximum of its own, so the gate
        # names one no assay reports rather than one at the edge of the plausible range.
        "gate": {"HIV.D.DE387": {"type": "range", "start": 1000, "end": 1000000000}},
    },
    {
        "rule": "HIV.D17.DT.03",
        "survey": "carevisit",
        "after": "HIV.D.DE364",
        "code": "whodakhiv-ds-d17-immunological",
        "name": "Low CD4 - evaluate for immunological failure",
        "guidance": (
            "Evaluate client for immunological failure, and for advanced HIV disease. WHO reads "
            "this on a persistent count, without a concomitant or recent infection causing a "
            "transient decline - check earlier counts before concluding."
        ),
        "gate": {"HIV.D.DE364": {"type": "range", "start": 0, "end": 250}},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct, and this is our own modelling of
# the HIV cascade. Clinical status and condition codes are prefixed with the registry code
# because `prClinicalStatus-<code>` is a global id and the status code is unique database-wide.
REGISTRY = {
    "registryCode": "who-dak-hiv",
    "registryName": "WHO DAK HIV",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    "lossToFollowUpThresholdDays": 90,
    "clinicalStatuses": [
        {"code": "who-dak-hiv-diagnosed-not-on-art", "name": "Diagnosed, not on ART", "color": "orange"},
        {"code": "who-dak-hiv-on-art", "name": "On ART", "color": "green"},
        {"code": "who-dak-hiv-art-interrupted", "name": "ART interrupted", "color": "yellow"},
        {"code": "who-dak-hiv-lost-to-follow-up", "name": "Lost to follow up", "color": "red"},
        {"code": "who-dak-hiv-transferred-out", "name": "Transferred out", "color": "blue"},
        {"code": "who-dak-hiv-art-stopped", "name": "ART stopped", "color": "brown"},
        {"code": "who-dak-hiv-died", "name": "Died", "color": "purple"},
    ],
    "conditions": [
        {"code": "who-dak-hiv-cond-tb", "name": "Tuberculosis (active disease)"},
        {"code": "who-dak-hiv-cond-advanced-hiv", "name": "Advanced HIV disease"},
        {"code": "who-dak-hiv-cond-cryptococcal", "name": "Cryptococcal disease"},
        {"code": "who-dak-hiv-cond-kaposi-sarcoma", "name": "Kaposi sarcoma"},
        {"code": "who-dak-hiv-cond-hbv", "name": "Hepatitis B (HBV)"},
        {"code": "who-dak-hiv-cond-hcv", "name": "Hepatitis C (HCV)"},
        {"code": "who-dak-hiv-cond-syphilis", "name": "Syphilis"},
        {"code": "who-dak-hiv-cond-sti-other", "name": "Sexually transmitted infection (other)"},
        {"code": "who-dak-hiv-cond-cervical-neoplasia", "name": "Cervical precancer or cancer"},
        {"code": "who-dak-hiv-cond-malnutrition", "name": "Malnutrition"},
        {"code": "who-dak-hiv-cond-hypertension", "name": "Hypertension"},
        {"code": "who-dak-hiv-cond-diabetes", "name": "Diabetes mellitus"},
        {"code": "who-dak-hiv-cond-mental-health", "name": "Mental health condition"},
        {"code": "who-dak-hiv-cond-substance-use", "name": "Substance use disorder"},
        {"code": "who-dak-hiv-cond-hiv-drug-resistance", "name": "HIV drug resistance"},
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
