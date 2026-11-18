"""The child health domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is that its reportable output is not a column. Every other kit
links an element to the Annex C indicator it feeds; this one fills that column in for a single
element and marks 32 of its 202 candidate elements `Required = R`, so the two rules that carry the
other kits select 33 between them here. What the indicators count instead is the IMCI
classification — `COUNT of consultations ... with "Pneumonia" classification recommended` — and
the kit states each of its 72 classifications as a `Derived` row of its own on
`CHE.B23.Classification`, grouped by the assessment that reaches it. `CLASSIFICATIONS` carries
each group as one question the health worker answers, whose options are the classification names
the indicators quote. See `dak-conformance.md` § The classification is the output.

The kit also defines a cluster of questions once and references the cluster by id: the five
questions the respiratory rate takes are `CHE.B24.DE01` on the group tab, named from the sign
tabs for either age band and from the assessment tab, and marked `Group questions`, `Group
question` and `N/A` on the three rows that name it. `GROUP_SOURCE` says where the clusters live,
and a reference is identified by its id resolving to one rather than by the spelling beside it.
See `dak-conformance.md` § One tab, seven groups.

Where this program stops is the other thing to know about it. Tamanu holds the child, the
caregiver and the visit natively, so `CHE.A`'s registration activity is not a survey and this
program starts at the reason for consultation. See `dak-conformance.md` § What the patient record
keeps.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for child health (0–59 months) in humanitarian emergencies (2024),
# DAK version 1.0.0. Publication: https://www.who.int/publications/i/item/9789240089907
#
# WHO's source repository slugs this kit `ccc` and titles it `SMART DAK CCC`, while every
# identifier inside it — tab names, data element ids, indicator codes — reads `CHE`. The
# directory, the program and the question codes follow the identifiers, because those are what a
# reader matches against; `ANNEXES` records the repository the bytes come from.
DAK = {
    "title": "Digital adaptation kit for child health (0-59 months) in humanitarian emergencies (2024)",
    "elementPrefix": "CHE.",  # stripped from data element ids when deriving question codes
}

# The kit's four components, fetched not committed (see ../../../.gitignore). The sha256 is the
# copy these artefacts were generated from, so a WHO revision announces itself rather than
# quietly changing a form.
#
# Hosted the way the TB and IMMZ kits are: IRIS carries the PDF and WHO ships the four components
# through its SMART guidelines implementation guide, whose component pages serve whatever the site
# last built. `url` therefore points at WHO's own source repository for the guide —
# `WorldHealthOrganization/smart-dak-ccc` — at the `v1.0.0` tag, whose `sushi-config.yaml`
# declares `status: active` and `releaseLabel: release`; `page` records the human-facing
# publication. Pin the tag, never the branch: `main` is a continuous integration build.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "CCC DAK_core data dictionary.xlsx",
        "handle": "10665/376546",
        "page": "https://smart.who.int/dak-ccc/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-ccc/v1.0.0/"
            "input/dictionary/CCC%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "b3a318d0735ff2089aaea62e08913b73c236a03901b9e2ccb6976b3e8ca8e225",
    },
    "B": {
        # Four decision tables: one classifying each age band from the signs recorded before it,
        # and one giving the treatment for each classification either band reaches.
        "name": "decision-support logic",
        "filename": "CCC DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-ccc/decision-logic.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-ccc/v1.0.0/"
            "input/decision-logic/CCC%20DAK_decision-support%20logic.xlsx"
        ),
        "sha256": "c8b59dd68144f8e4d33b85a8ee75d1ae389ce507ed1725ad9af416787b23a389",
    },
    "C": {
        "name": "indicators",
        "filename": "CCC DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-ccc/indicators.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-ccc/v1.0.0/"
            "input/indicators/CCC%20DAK_indicators.xlsx"
        ),
        "sha256": "fe329e735586c48143d3901265655463d8f439701f8a721c3b92faf019e08f5a",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "CCC DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-ccc/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-ccc/v1.0.0/"
            "input/system-requirements/"
            "CCC%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header names:
# like the TB, FP and IMMZ kits, this one splits its header across two rows — `Numerator` and
# `Denominator` each span two columns on the first, `Definition` and `Computation` name them on
# the second — so there is no single header row to match on.
#
# `firstDataRow` is the spreadsheet's own row number; `columns` are zero-based offsets, so
# `id: 0` is column A. `numerator` is the Computation column rather than the prose Definition
# beside it, because the computation is where the kit quotes the classification names.
ANNEX_C = {
    "sheet": "Indicator table ",
    "firstDataRow": 4,
    "columns": {"id": 0, "name": 1, "numerator": 4, "denominator": 6},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK Child Health",
    "programCode": "who-dak-che",
    "codePrefix": "whodakche",  # question codes: whodakche-b7-de01, whodakche-b23-fever-classification
}

# One survey per business process.
#
# `CHE.A.Registration` holds two: the registration activity that gathers, creates and validates
# the child's record, and `CHE.B3`, which asks why the child is here. The first is the patient
# record — national id, name, date of birth, sex, caregiver, telephone numbers, visit date — all
# of which Tamanu holds natively, and carrying it here would give a deployment two places to write
# a child and no rule for which one counts. So this process is the `CHE.B3` slice of that tab.
#
# `CHE.B24.Group questions` is not a survey either: it is where the kit defines the clusters the
# other tabs reference, and it reaches the forms through `GROUP_SOURCE` rather than on its own.
# `CHE.B28.Country Configuration` holds one element, a population mean, which is a deployment
# setting rather than a question anyone answers about a child.
PROCESSES = [
    {
        "tab": "CHE.A.Registration",
        "activities": ["CHE.B3"],
        "code": "consultation",
        "name": "Reason for Consultation",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B7-9.LTI-DangerSigns",
        "code": "danger-signs",
        "name": "Life-threatening Illness and Danger Signs",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B6.Measurements",
        "code": "measurements",
        "name": "Measurements",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B10-14.Symptoms ≥2 mths",
        "code": "symptoms-child",
        "name": "Symptoms, 2-59 Months",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B10-16.Signs ≥2 mths",
        "code": "signs-child",
        "name": "Signs, 2-59 Months",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B18-21.Symptoms <2 mths",
        "code": "symptoms-infant",
        "name": "Symptoms, Young Infant",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B18-21.Signs <2 mths",
        "code": "signs-infant",
        "name": "Signs, Young Infant",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B22.Assessments-Tests",
        "code": "assessments",
        "name": "Assessments and Tests",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B17.Health Promotion",
        "code": "health-promotion",
        "name": "Health Promotion",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B23.Classification",
        "code": "classification",
        "name": "Classification",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B27.Combined Data Element",
        "code": "severe",
        "name": "Severe Classification Summary",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B25.Population-Malaria",
        "code": "setting-malaria",
        "name": "Malaria Setting and Test Availability",
        "surveyType": "programs",
    },
    {
        "tab": "CHE.B.26.Population-HIV",
        "code": "setting-hiv",
        "name": "HIV Prevalence Setting",
        "surveyType": "programs",
    },
]

# The tab holding the clusters this kit's process tabs reference by id. Seven of them: the
# respiratory rate, the oral fluid test, the inhaled bronchodilator trial, the appetite test, the
# breastfeeding assessment, the second temperature measurement and the malaria test — each a
# heading row carrying an id, with its questions beneath.
GROUP_SOURCE = "CHE.B24.Group questions"

# The classifications, which the kit states as one `Derived` row each rather than as an element
# with a value set, grouped by the subcategory naming the assessment that reaches them. Each
# group becomes one Select-all question whose options are the group's classification labels
# verbatim, because those labels are the strings Annex C's computations quote.
#
# The `Derived qualifier` rows are not carried. They qualify one classification — `Pneumonia`
# `With wheezing` — and the kit repeats a qualifier under each classification it applies to, so
# `With wheezing` appears three times in the cough group and `Fever present every day for more
# than 7 days` three times in the fever group. Flattened into one option list they collide with
# each other and lose the classification they qualified, and no indicator counts one.
CLASSIFICATIONS = {
    "tab": "CHE.B23.Classification",
    "dataType": "Derived",
    "groups": {
        # --- either age band ------------------------------------------------
        "Danger signs": "Danger signs classification",
        "Life-threatening illness": "Life-threatening illness classification",
        # --- 2-59 months ----------------------------------------------------
        "Symptoms and signs – Cough or difficulty breathing": "Cough or difficulty breathing classification",
        "Symptoms and signs – Diarrhoea/dehydration": "Diarrhoea and dehydration classification",
        "Symptoms and signs – Fever": "Fever classification",
        "Symptoms and signs – Ear problem": "Ear problem classification",
        "Symptoms and signs – Skin or mouth or eye problem": "Skin, mouth or eye problem classification",
        "Symptoms and signs – Anaemia": "Anaemia classification",
        "Symptoms and signs – Acute malnutrition and low weight for age": "Acute malnutrition classification",
        # --- young infant ---------------------------------------------------
        "Symptoms and signs – Very severe disease and local bacterial infection": (
            "Young infant bacterial infection classification"
        ),
        "Symptoms and signs – Jaundice": "Jaundice classification",
        "Symptoms and signs – Diarrhoea": "Young infant diarrhoea classification",
        "Symptoms and signs – Feeding problem or low weight for age (WFA)": (
            "Young infant weight for age classification"
        ),
        "Symptoms and signs – Feeding problem or low WFA": "Young infant feeding problem classification",
        # --- health promotion -----------------------------------------------
        "Health promotion": "Health promotion classification",
        "Health promotion – Immunization": "Immunization status classification",
        "Health promotion – HIV": "HIV status classification",
    },
}

# The kit's own core shortlist, which here carries the program rather than supplementing it.
# `Required = R` selects 32 of the 202 candidates and the indicator column is filled in for one
# element, so the two rules that carry every other kit would leave this one with a danger-sign
# list, a respiratory rate and little else — no temperature, no weight, no dehydration signs, no feeding assessment.
# The kit marks 259 of its elements `C`, conditional on a symptom the child presents with, which
# is what an IMCI assessment is made of rather than a reason to leave it out.
#
# Every process tab, because the shortlist is doing the selecting on all of them.
CORE_TABS = {process["tab"] for process in PROCESSES}

CORE_ELEMENTS = {
    # --- why the child is here ---------------------------------------------
    "CHE.B3.DE05",  # Is the child sick today?
    "CHE.B3.DE06",  # Type of consultation
    # --- life-threatening illness and danger signs -------------------------
    "CHE.B7.B8.B9.DE01",  # Continue to assess sick child
    "CHE.B7.DE08",  # Number of convulsions in this illness
    "CHE.B7.DE11",  # Convulsion(s) lasting 15 minutes or longer
    # --- measurements ------------------------------------------------------
    # The whole tab: every measurement is `C`, and the classification thresholds are read off
    # them. A weight-for-height z-score with no weight on the form is a threshold with no input.
    "CHE.B6.DE01",  # Axillary temperature (degrees C)
    "CHE.B6.DE02",  # Prefer to take rectal temperature
    "CHE.B6.DE03",  # Rectal temperature (degrees C)
    "CHE.B6.DE05",  # Thermometer not available
    "CHE.B6.DE06",  # Hot to touch
    "CHE.B6.DE07",  # Weight (kilograms)
    "CHE.B6.DE08",  # Weight cannot be measured
    "CHE.B6.DE09",  # Estimated weight
    "CHE.B6.DE10",  # Height (cm)
    "CHE.B6.DE11",  # Prefer to measure length
    "CHE.B6.DE12",  # Height cannot be measured
    "CHE.B6.DE13",  # Length (cm)
    "CHE.B6.DE14",  # Prefer to measure height
    "CHE.B6.DE15",  # Length cannot be measured
    "CHE.B6.DE16",  # Weight for height (WFH) z-score
    "CHE.B6.DE17",  # Weight for length (WFL) z-score
    "CHE.B6.DE18",  # Weight for age (WFA) z-score
    "CHE.B6.DE19",  # Mid-upper arm circumference (MUAC) (mm)
    "CHE.B6.DE20",  # MUAC cannot be measured
    "CHE.B6.DE21",  # Visually assess whether underweight
    # --- symptoms, 2-59 months ---------------------------------------------
    "CHE.B10S1.DE06",  # Cough for how long?
    "CHE.B10S1.DE02",  # Difficulty breathing for how long?
    "CHE.B11S1.DE02",  # Diarrhoea for how long?
    "CHE.B12S1.DE03",  # Fever for how long?
    "CHE.B12S1.DE06",  # Has fever been present every day for more than 7 days?
    "CHE.B12S1.DE08",  # Pain
    "CHE.B12S1.DE15",  # Malaria risk
    "CHE.B12S1.DE19",  # Recent travel to a high malaria risk area
    "CHE.B13S1.DE02",  # Ear pain
    "CHE.B13S1.DE03",  # Ear discharge
    "CHE.B13S1.DE04",  # Ear discharge for how long?
    # --- signs, 2-59 months -------------------------------------------------
    "CHE.B10S2.DE03",  # Chest indrawing
    "CHE.B10S2.DE04",  # Stridor in a calm child
    "CHE.B10S2.DE05",  # Wheezing
    "CHE.B10S2.DE06",  # Recurrent wheeze
    "CHE.B10S2.DE07",  # Oxygen saturation (%)
    "CHE.B11S2.DE01",  # Sunken eyes
    "CHE.B11S2.DE02",  # Skin pinch of abdomen
    "CHE.B11S2.DE06",  # Restless and irritable
    "CHE.B12S2.DE01",  # Stiff neck
    "CHE.B12S2.DE02",  # Refusal to use a limb
    "CHE.B12S2.DE03",  # Warm, tender or swollen joint or bone
    "CHE.B12S2.DE05",  # Runny nose
    "CHE.B13S2.DE01",  # Tender swelling behind the ear
    "CHE.B13S2.DE02",  # Pus seen draining from the ear
    "CHE.B13S2.DE03",  # Pus seen draining from the ear for how long?
    "CHE.B14S2.DE01",  # Red eyes
    "CHE.B14S2.DE02",  # Pus draining from the eye
    "CHE.B14S2.DE03",  # Clouding of the cornea
    "CHE.B14S2.DE04",  # Is clouding of the cornea a new problem?
    "CHE.B14S2.DE05",  # Has clouding of the cornea previously been treated?
    "CHE.B14S2.DE06",  # Generalized or localized skin problem
    "CHE.B14S2.DE10",  # Measles rash
    "CHE.B14S2.DE11",  # Measles within the last 3 months
    "CHE.B14S2.DE11A",  # Itchy skin
    "CHE.B14S2.DE012",  # Blisters, sores or pustules
    "CHE.B14S2.DE15",  # Deep or extends to muscle
    "CHE.B14S2.DE17",  # Rapidly spreading, extensive or not responding to oral antibiotics
    "CHE.B14S2.DE20",  # Extensive ringworm (tinea)
    "CHE.B14S2.DE24",  # Eye involvement
    "CHE.B14S2.DE26",  # Signs of severe impetigo or folliculitis
    "CHE.B14S2.DE34",  # Severe seborrhoea
    "CHE.B14S2.DE38",  # Oral sores or mouth ulcers
    "CHE.B14S2.DE43",  # Add a skin or mouth or eye problem
    "CHE.B15S2.DE02",  # Severe palmar pallor
    # --- symptoms and signs, young infant ------------------------------------
    "CHE.B18S1.DE01",  # Convulsions in this illness
    "CHE.B19S2.DE04",  # When did the jaundice first appear?
    "CHE.B20S2.DE01",  # Sunken eyes
    "CHE.B20S2.DE02",  # Skin pinch of abdomen
    "CHE.B20S2.DE06",  # Restless and irritable
    "CHE.B21S2.DE01",  # Weight status
    "CHE.B21S2.DE05",  # Breastfed how many times in 24 hours?
    "CHE.B21S2.DE08",  # Infant's movements / receives food or fluids other than breast milk
    "CHE.B21S2.DE09",  # What milk is being given as a replacement feed?
    "CHE.B21S2.DE12",  # How many replacement feeds during the day and night?
    "CHE.B21S2.DE15",  # How much milk is given at each feed?
    "CHE.B21S2.DE18",  # How is the milk prepared?
    "CHE.B21S2.DE21",  # How is the milk given?
    "CHE.B21S2.DE24",  # How are the feeding utensils cleaned?
    "CHE.B21S2.DE30",  # Ulcers or white patches in mouth
    "CHE.B21S2.DE31",  # Unable to check if ulcers or white patches in mouth
    # --- the questions inside the clusters the process tabs reference ---------
    # The cluster ids themselves - `CHE.B24.DE01` and its siblings - are not here: a reference
    # row becomes the heading over its group, and a heading is carried whatever the selection
    # rule says. What has to be selected is the questions the group expands to.
    "CHE.B24.G.DE01",  # Respiratory rate (breaths per minute)
    "CHE.B24.G.DE02",  # Unable to perform respiratory rate at this time
    "CHE.B24.G.DE03",  # Respiratory rate second count (breaths per minute)
    "CHE.B24.G.DE04",  # Respiratory rate second count not possible
    "CHE.B24.G.DE05",  # Fast breathing
    "CHE.B24.G.DE07",  # Oral fluid test results
    "CHE.B24.G.DE13",  # Unable to perform oral fluid test
    "CHE.B24.G.DE15",  # Has the child had anything to drink today?
    "CHE.B24.G.DE16",  # How did the child last drink?
    "CHE.B24.G.DE17",  # Inhaled bronchodilator trial results
    "CHE.B24.G.DE18",  # Chest indrawing (after the inhaled bronchodilator trial)
    "CHE.B24.G.DE19",  # Respiratory rate (after the inhaled bronchodilator trial)
    "CHE.B24.G.DE20",  # Fast breathing (after the inhaled bronchodilator trial)
    "CHE.B24.G.DE21",  # No fast breathing and no chest indrawing after the trial
    "CHE.B24.G.DE22",  # Inhaled bronchodilator trial not feasible or available
    "CHE.B24.G.DE23",  # Appetite test (using RUTF) results
    "CHE.B24.G.DE28",  # Mother reports difficulty breastfeeding
    "CHE.B24.G.DE29",  # Good attachment
    "CHE.B24.G.DE30",  # Sucking effectively
    "CHE.B24.G.DE31",  # Difficulty breastfeeding reported
    "CHE.B24.G.DE32",  # Difficulty breastfeeding observed
    "CHE.B24.G.DE33",  # Breastfeeding assessment not possible
    "CHE.B24.G.DE39",  # Axillary temperature (second measurement)
    "CHE.B24.G.DE40",  # Prefer to take rectal temperature (second measurement)
    "CHE.B24.G.DE41",  # Rectal temperature (second measurement)
    "CHE.B24.G.DE42",  # Second temperature measurement not feasible
    "CHE.B24.G.DE44",  # Malaria test
    "CHE.B24.G.DE48",  # Type of malaria test
    "CHE.B24.G.DE52",  # RDT species results
    "CHE.B24.G.DE59",  # Microscopy species results
    "CHE.B24.G.DE67",  # Parasite density (%)
    "CHE.B24.G.DE68",  # Parasite density unknown
    "CHE.B24.G.DE69",  # Prefer to provide per microlitre
    "CHE.B24.G.DE70",  # Parasite density (per microlitre)
    # --- health promotion ----------------------------------------------------
    # The tab marks nothing `R`, so without these the vitamin A, deworming, HIV and immunization
    # status the health-promotion classifications are reached from is collected nowhere.
    "CHE.B17.DE01",  # Date of last vitamin A supplementation
    "CHE.B17.DE07",  # Can record of vitamin A supplementation be obtained at a future visit?
    "CHE.B17.DE10",  # Treatment for malnutrition containing vitamin A received in the last month
    "CHE.B17.DE11",  # Date of last deworming treatment
    "CHE.B17.DE16",  # Can record of deworming treatment be obtained at a future visit?
    "CHE.B17.DE22",  # HIV prevalence
    "CHE.B17.DE25",  # Mother's HIV status
    "CHE.B17.DE30",  # Child's last HIV test results
    "CHE.B17.DE37",  # Child breastfed at the time or 6 weeks before HIV test
    "CHE.B17.DE41",  # Child 18 months or older when last tested for HIV
    "CHE.B17.DE45",  # Has the child received all immunizations recommended for age?
    "CHE.B17.DE50",  # Immunizations for age
    # --- the severe-classification summary ------------------------------------
    # None flagged and none linked, so without these the tab contributes nothing. Each is the
    # composite the treatment tables read where a rule turns on more than one classification.
    "CHE.B27.G.DE01",  # Danger signs
    "CHE.B27.G.DE02",  # History of obstructed or absent breathing
    "CHE.B27.G.DE03",  # Severe acute malnutrition
    "CHE.B27.G.DE04",  # Medical complications of severe acute malnutrition
    "CHE.B27.G.DE05",  # 2-59 months - severe classification other than severe dehydration
    "CHE.B27.G.DE06",  # Fever
    "CHE.B27.G.DE07",  # Severe dehydration with unconscious/lethargy or unable to drink
    "CHE.B27.G.DE08",  # Possible serious bacterial infection other than temperature
    "CHE.B27.G.DE09",  # PSBI
    "CHE.B27.G.DE10",  # Young infant severe classification other than severe dehydration
    "CHE.B27.G.DE11",  # Young infant severe classification including severe dehydration
}

# Annex B states its logic as four decision tables: one classifying each age band from the signs
# recorded before it, and one giving the treatment for each classification either band reaches.
# The classification tables are not expressible in a survey - a rule reads up to seven inputs
# spread across the symptom, sign, measurement and assessment forms, and concludes the
# classification the health worker is about to record.
#
# The treatment tables are, because they key on the classification alone:
# `"Classification" = "CHE.B23.DE01 - Very severe disease"` is one input, and it is an option of
# a question this program carries. So the prompts gate on the recorded classification and carry
# the kit's own action text for it.
#
# Carried here are the classifications whose treatment begins with referral or a pre-referral
# dose, which are the ones where a prompt arriving late is the harm. The rest of the kit's
# treatment rules are dosing tables, which belong with the prescription rather than on the
# assessment form.
#
# `after` and the gate name the classification question by code rather than by data element id,
# because a classification question is one this reader built from a group of the kit's rows and
# the dictionary has no single id for it. One rule per group, gating on every severe
# classification in that group, so a child classified twice raises one prompt per assessment
# rather than one per classification.
DECISION_SUPPORT = [
    {
        "rule": "CHE.DT.03.TR01",
        "survey": "classification",
        "after": "whodakche-b23-danger-signs-classification",
        "code": "whodakche-ds-b23-danger-signs",
        "name": "Danger signs - refer urgently",
        "guidance": (
            "Quickly complete the assessment. Give the first dose of pre-referral ampicillin (IM) "
            "and gentamicin (IM), give diazepam (rectal) if convulsing now, treat to prevent low "
            "blood sugar, and refer URGENTLY to hospital."
        ),
        "gate": {
            "whodakche-b23-danger-signs-classification": [
                "Very severe disease",
                "History of obstructed or absent breathing",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Danger signs - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR01",
        "survey": "classification",
        "after": "whodakche-b23-life-threatening-illness-classification",
        "code": "whodakche-ds-b23-life-threatening",
        "name": "Life-threatening illness - refer urgently",
        "guidance": "Refer URGENTLY to the hospital.",
        "gate": {
            "whodakche-b23-life-threatening-illness-classification": ["History of obstructed or absent breathing"]
        },
        "issue": {"issueType": "warning", "issueNote": "Life-threatening illness - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR04",
        "survey": "classification",
        "after": "whodakche-b23-cough-or-difficulty-breathing-classifica",
        "code": "whodakche-ds-b23-severe-pneumonia",
        "name": "Severe pneumonia - refer urgently",
        "guidance": (
            "Give the first dose of pre-referral ampicillin (IM) and gentamicin (IM). Give oxygen "
            "where oxygen saturation is below 90%. Refer URGENTLY to hospital."
        ),
        "gate": {"whodakche-b23-cough-or-difficulty-breathing-classifica": ["Severe pneumonia or very severe disease"]},
        "issue": {"issueType": "warning", "issueNote": "Severe pneumonia - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR16",
        "survey": "classification",
        "after": "whodakche-b23-diarrhoea-and-dehydration-classification",
        "code": "whodakche-ds-b23-severe-dehydration",
        "name": "Severe dehydration - start Plan C",
        "guidance": (
            "Start Plan C and give fluid for severe dehydration. Refer URGENTLY to hospital where "
            "the child cannot be treated here, and advise the caregiver to continue breastfeeding "
            "on the way."
        ),
        "gate": {"whodakche-b23-diarrhoea-and-dehydration-classification": ["Severe dehydration"]},
        "issue": {"issueType": "warning", "issueNote": "Severe dehydration - Plan C and urgent referral"},
    },
    {
        "rule": "CHE.DT.03.TR22",
        "survey": "classification",
        "after": "whodakche-b23-fever-classification",
        "code": "whodakche-ds-b23-severe-febrile",
        "name": "Very severe febrile disease - refer urgently",
        "guidance": (
            "Give the first dose of pre-referral ampicillin (IM) and gentamicin (IM), the first "
            "dose of artesunate where there is malaria risk, and vitamin A for measles. Refer "
            "URGENTLY to hospital."
        ),
        "gate": {
            "whodakche-b23-fever-classification": [
                "Very severe febrile disease",
                "Severe complicated measles",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Very severe febrile disease - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR33",
        "survey": "classification",
        "after": "whodakche-b23-ear-problem-classification",
        "code": "whodakche-ds-b23-mastoiditis",
        "name": "Mastoiditis - refer urgently",
        "guidance": (
            "Give the first dose of a pre-referral antibiotic and one dose of paracetamol for "
            "pain. Refer URGENTLY to hospital."
        ),
        "gate": {"whodakche-b23-ear-problem-classification": ["Mastoiditis"]},
        "issue": {"issueType": "warning", "issueNote": "Mastoiditis - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR38",
        "survey": "classification",
        "after": "whodakche-b23-skin-mouth-or-eye-problem-classification",
        "code": "whodakche-ds-b23-severe-skin-eye",
        "name": "Severe eye or skin condition - refer urgently",
        "guidance": (
            "Refer URGENTLY to hospital. Give vitamin A and apply tetracycline eye ointment where "
            "the cornea is clouded."
        ),
        "gate": {
            "whodakche-b23-skin-mouth-or-eye-problem-classification": [
                "Clouding of the cornea",
                "Steven–Johnson syndrome",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Severe eye or skin condition - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR52",
        "survey": "classification",
        "after": "whodakche-b23-anaemia-classification",
        "code": "whodakche-ds-b23-severe-anaemia",
        "name": "Severe anaemia - refer urgently",
        "guidance": "Refer URGENTLY to hospital.",
        "gate": {"whodakche-b23-anaemia-classification": ["Severe anaemia"]},
        "issue": {"issueType": "warning", "issueNote": "Severe anaemia - urgent referral required"},
    },
    {
        "rule": "CHE.DT.03.TR55",
        "survey": "classification",
        "after": "whodakche-b23-acute-malnutrition-classification",
        "code": "whodakche-ds-b23-complicated-sam",
        "name": "Complicated severe acute malnutrition - refer urgently",
        "guidance": (
            "Give the first dose of a pre-referral antibiotic, treat to prevent low blood sugar, "
            "keep the child warm, and refer URGENTLY to hospital."
        ),
        # `CHE.B23.DE68` only. Annex A gives `CHE.B23.DE70` the same label, so the group carries
        # two options reading "with medical complications"; Annex B calls DE70 "without medical
        # complications" throughout, and refers only DE68. Annex A's label is the typo, and it is
        # carried as written rather than corrected here - see `dak-conformance.md` § A
        # classification labelled as its own opposite.
        "gate": {
            "whodakche-b23-acute-malnutrition-classification": [
                "Severe acute malnutrition (or very low weight for age [WFA] if less than 12 months old) "
                "with medical complications",
            ]
        },
        "issue": {
            "issueType": "warning",
            "issueNote": "Complicated severe acute malnutrition - urgent referral required",
        },
    },
    {
        "rule": "CHE.DT.04.TR02",
        "survey": "classification",
        "after": "whodakche-b23-young-infant-bacterial-infection-classif",
        "code": "whodakche-ds-b23-psbi",
        "name": "Possible serious bacterial infection - refer urgently",
        "guidance": (
            "Give the first dose of ampicillin (IM) 50 mg/kg and gentamicin (IM). Treat to prevent "
            "low blood sugar, keep the young infant warm, and refer URGENTLY to hospital."
        ),
        "gate": {
            "whodakche-b23-young-infant-bacterial-infection-classif": [
                "Possible serious bacterial infection OR very severe disease"
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Possible serious bacterial infection - urgent referral"},
    },
    {
        "rule": "CHE.DT.04.TR06",
        "survey": "classification",
        "after": "whodakche-b23-jaundice-classification",
        "code": "whodakche-ds-b23-severe-jaundice",
        "name": "Severe jaundice - refer urgently",
        "guidance": (
            "Treat to prevent low blood sugar, keep the young infant warm, and refer URGENTLY to "
            "hospital. Advise the mother to continue breastfeeding on the way."
        ),
        "gate": {"whodakche-b23-jaundice-classification": ["Severe jaundice"]},
        "issue": {"issueType": "warning", "issueNote": "Severe jaundice - urgent referral required"},
    },
    {
        "rule": "CHE.DT.04.TR10",
        "survey": "classification",
        "after": "whodakche-b23-young-infant-diarrhoea-classification",
        "code": "whodakche-ds-b23-infant-severe-dehydration",
        "name": "Young infant severe dehydration - refer urgently",
        "guidance": (
            "Start Plan C. Treat to prevent low blood sugar, keep the young infant warm, and refer "
            "URGENTLY to hospital."
        ),
        "gate": {"whodakche-b23-young-infant-diarrhoea-classification": ["Severe dehydration"]},
        "issue": {"issueType": "warning", "issueNote": "Young infant severe dehydration - urgent referral"},
    },
    # The two health-promotion prompts the kit reaches at every consultation, neither of which is
    # a referral: they are what the visit is for when nothing is classified as severe.
    {
        "rule": "CHE.DT.03.TR60",
        "survey": "classification",
        "after": "whodakche-b23-immunization-status-classification",
        "code": "whodakche-ds-b23-immunization",
        "name": "Immunizations due",
        "guidance": (
            "Give the immunizations the child is due for today unless they are contraindicated, "
            "and tell the caregiver when the next dose is due."
        ),
        "gate": {
            "whodakche-b23-immunization-status-classification": [
                "Immunization(s) incomplete for age",
                "Immunization status unknown",
            ]
        },
    },
    {
        "rule": "CHE.DT.03.TR62",
        "survey": "classification",
        "after": "whodakche-b23-hiv-status-classification",
        "code": "whodakche-ds-b23-hiv",
        "name": "HIV infection or exposure - link to care",
        "guidance": (
            "Start or continue co-trimoxazole prophylaxis and link the child to HIV care. Test an "
            "exposed child according to the national schedule."
        ),
        "gate": {
            "whodakche-b23-hiv-status-classification": [
                "Confirmed HIV infection",
                "HIV exposed",
            ]
        },
    },
]

# --- the Tamanu program registry --------------------------------------------
# Not from the DAK, which has no registry concept.
REGISTRY = {
    "registryCode": "who-dak-che",
    "registryName": "WHO DAK Child Health",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    # On, because this kit does give the interval to set it from: every classification whose
    # treatment does not refer the child ends in a follow-up date, running from the two days a
    # child with pneumonia or dysentery is asked to come back in to the 30 days a child in
    # nutritional care is. Twice the longest of those, so a child still inside the slowest
    # routine schedule is never marked lost, and one who has missed even that has left the
    # pathway. Set explicitly rather than left to Tamanu's 90-day default, which is longer than
    # any interval this kit schedules.
    "lossToFollowUpEnabled": True,
    "lossToFollowUpThresholdDays": 60,
    # Where the child stands in the IMCI pathway. The kit has no element that opens or closes a
    # child's record, so these are the pathway's rather than the dictionary's, and they describe
    # the consultation outcome the treatment tables reach: referral, treatment at this facility,
    # or a routine visit with nothing to treat.
    "clinicalStatuses": [
        {"code": "who-dak-che-well", "name": "Well child", "color": "green"},
        {"code": "who-dak-che-treated", "name": "Treated at this facility", "color": "blue"},
        {"code": "who-dak-che-follow-up-due", "name": "Follow-up due", "color": "yellow"},
        {"code": "who-dak-che-follow-up-overdue", "name": "Follow-up overdue", "color": "orange"},
        {"code": "who-dak-che-referred", "name": "Referred urgently", "color": "red"},
        {"code": "who-dak-che-nutrition-programme", "name": "In a nutrition programme", "color": "purple"},
        {"code": "who-dak-che-defaulted", "name": "Defaulted", "color": "brown"},
        {"code": "who-dak-che-transferred-out", "name": "Transferred out", "color": "grey"},
        {"code": "who-dak-che-aged-out", "name": "Aged out at 5 years", "color": "teal"},
        {"code": "who-dak-che-died", "name": "Child died", "color": "pink"},
    ],
    # What the child carries between consultations and what the algorithm therefore reads at each
    # one rather than re-establishing. Each traces to an element or a classification of the kit:
    # the HIV status and exposure the pneumonia and PSBI branches turn on, the nutritional state
    # that decides whether a severe classification is complicated, and the two chronic conditions
    # the skin and ear assessments ask whether the child has been treated for before.
    "conditions": [
        {"code": "who-dak-che-cond-hiv-confirmed", "name": "Confirmed HIV infection"},
        {"code": "who-dak-che-cond-hiv-exposed", "name": "HIV exposed"},
        {"code": "who-dak-che-cond-severe-acute-malnutrition", "name": "Severe acute malnutrition"},
        {"code": "who-dak-che-cond-moderate-acute-malnutrition", "name": "Moderate acute malnutrition"},
        {"code": "who-dak-che-cond-low-weight-for-age", "name": "Low weight for age"},
        {"code": "who-dak-che-cond-preterm", "name": "Preterm birth"},
        {"code": "who-dak-che-cond-chronic-ear-infection", "name": "Chronic ear infection"},
        {"code": "who-dak-che-cond-recurrent-wheeze", "name": "Recurrent wheeze"},
        {"code": "who-dak-che-cond-immunization-incomplete", "name": "Immunizations incomplete for age"},
    ],
}
