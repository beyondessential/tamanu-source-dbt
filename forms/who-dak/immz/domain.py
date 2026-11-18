"""The immunization domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is one tab to nine activities. Every other kit read here gives a
process its own tab; this one puts client history, the schedule determination, contraindications,
counselling, the dose record, adverse events, the next visit and certificate issuance on a single
`IMMZ.D Administer vaccine` tab and separates them only by activity id. A process here is
therefore a slice of a tab rather than the whole of it, which is what `activities` names. The kit
also writes two ids in one cell — `IMMZ.D1.Capture or update client history OR IMMZ.D13.Update
client record` — on the 48 rows either process records. See `dak-conformance.md` § One tab,
nine activities.

Where this program stops is the other thing to know about it. Tamanu records administered doses
natively, so the dose record stays there and this program carries what Tamanu has no construct
for: the history and risk factors the schedule is computed from, the recommendation status and
contraindications, adverse events, and a registry holding the client's place in the schedule.
See `dak-conformance.md` § What the native vaccine module keeps.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for immunizations (2025), DAK version 1.1.0.
# Publication: https://www.who.int/publications/i/item/9789240099456
DAK = {
    "title": "Digital adaptation kit for immunizations (2025)",
    "elementPrefix": "IMMZ.",  # stripped from data element ids when deriving question codes
}

# The kit's four components, fetched not committed (see ../../../.gitignore). The sha256 is the
# copy these artefacts were generated from, so a WHO revision announces itself rather than
# quietly changing a form.
#
# Hosted the way the TB kit is: IRIS carries the PDF and WHO ships the four components through
# its SMART guidelines implementation guide at https://smart.who.int/dak-immz/, whose component
# pages serve whatever the site last built. `url` therefore points at WHO's own source repository
# for the guide — `WorldHealthOrganization/smart-dak-immz` — at the `v1.1.0` tag, which is a
# version-pinned path to the released bytes; `page` records the human-facing publication.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "IMMZ DAK_core data dictionary.xlsx",
        "handle": "10665/380303",
        "page": "https://smart.who.int/dak-immz/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-immz/v1.1.0/"
            "input/dictionary/IMMZ%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "8bb64f9681ff4cd07ce37b8ad2162b9b7884749bc05c05ae73073273ddfb3c78",
    },
    "B": {
        # This kit publishes its scheduling logic inside the decision-support component rather
        # than as a fifth annexe: one decision table per antigen, each ending in a schedule that
        # names the due, overdue, expiration and completion dates for that antigen's doses.
        "name": "decision-support and scheduling logic",
        "filename": "IMMZ DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-immz/decision-logic.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-immz/v1.1.0/"
            "input/decision-logic/IMMZ%20DAK_decision-support%20logic.xlsx"
        ),
        "sha256": "07a9c6f97e49f76521712a3eb32b7aeb00f7e86bae20d97580e3137a3ab29320",
    },
    "C": {
        "name": "indicators",
        "filename": "IMMZ DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-immz/indicators.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-immz/v1.1.0/"
            "input/indicators/IMMZ%20DAK_indicators.xlsx"
        ),
        "sha256": "40e8c7ffe1d7f532e86cdd505dd6ac28710d3fb1c4aa8eeecf97e4ffc3a8dfae",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "IMMZ DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-immz/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-immz/v1.1.0/"
            "input/system-requirements/"
            "IMMZ%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header names:
# like the TB and FP kits, this one splits its header across two rows — `Numerator` spans two
# columns on the first, `Description` and `Computation` name them on the second — so there is no
# single header row to match on. This sheet also leaves column A empty, which shifts every offset
# one to the right of the TB kit's.
#
# `firstDataRow` is the spreadsheet's own row number; `columns` are zero-based offsets, so
# `id: 1` is column B. `numerator` is the Computation column rather than the prose Description
# beside it, because the computation is where the kit quotes Annex A's labels.
ANNEX_C = {
    "sheet": "Indicator table",
    "firstDataRow": 4,
    "columns": {"id": 1, "name": 2, "numerator": 5, "denominator": 7},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK Immunization",
    "programCode": "who-dak-immz",
    "codePrefix": "whodakimmz",  # question codes: whodakimmz-d-de-19, whodakimmz-d-de156
}

# One survey per business process, and here a process is a slice of the one clinical tab rather
# than a tab of its own, so each names the activities it takes.
#
# Four of the kit's activities are not surveys. `IMMZ.D13 Update client record` is the dose
# itself — vaccine brand, manufacturer, batch, expiry, dose quantity, the administering health
# worker — which Tamanu records natively; carrying it here would give a deployment two places to
# write a dose and no rule for which one counts. `IMMZ.D20` and `IMMZ.D21` issue a verifiable
# digital certificate, which is a signing service rather than a question a clinician answers.
# Two whole tabs are out for the same reason: `IMMZ.C Client registration` is the patient record
# (name, sex, date of birth, address), `IMMZ.I Report generation` is aggregate stock and coverage
# reporting, which belongs to the metric layer, and `IMMZ.Z Vaccine library` is the value set of
# `Vaccine type` rather than a process (see `OPTION_SOURCES`).
PROCESSES = [
    {
        "tab": "IMMZ.D Administer vaccine",
        "activities": ["IMMZ.D1"],
        "code": "history",
        "name": "Immunization History and Risk Factors",
        "surveyType": "programs",
    },
    {
        "tab": "IMMZ.D Administer vaccine",
        "activities": ["IMMZ.D2", "IMMZ.D5", "IMMZ.D7", "IMMZ.D18"],
        "code": "status",
        "name": "Immunization Status and Contraindications",
        "surveyType": "programs",
    },
    {
        "tab": "IMMZ.D Administer vaccine",
        "activities": ["IMMZ.D17"],
        "code": "aefi",
        "name": "Adverse Event Following Immunization",
        "surveyType": "programs",
    },
]

# An element whose value set the kit publishes as a tab rather than as option rows beneath it.
#
# `IMMZ.D.DE.19 Vaccine type` is the element every coverage indicator counts, and Annex A gives
# it no options: the kit puts them on `IMMZ.Z Vaccine library`, whose 34 rows name one vaccine
# family each. Those labels are the strings Annex B and Annex C quote - `"Vaccine type" = "BCG
# vaccines"`, `= "DTP-containing vaccines"` - so they are the only values an indicator can match.
OPTION_SOURCES = {
    "IMMZ.D.DE.19": "IMMZ.Z Vaccine library",
}

# A type the kit states inconsistently, read off its sibling rows rather than invented.
#
# `IMMZ.D.DE.254 Type of hepatitis B dose` is typed `Codes` but declares `Select one` and carries
# two `Input Option` rows, which `Codes` maps to free text and drops. Every sibling dose-type
# element on the tab — JE, TBE, typhoid, cholera, meningococcal, hepatitis A — is typed `Coding`.
ELEMENT_TYPES = {
    "IMMZ.D.DE.254": "Coding",  # Type of hepatitis B dose - Select one, with two options
}

# The kit's own core shortlist. `Required = R` and an Annex C indicator link between them carry
# the schedule status, the contraindication list and the dose history, but this kit states every
# client characteristic its decision tables read as `Required = C` — so the risk factors that
# decide what a client is due for would select down to nothing, and the history form would ask
# what was given without asking any of what governs what comes next.
#
# Each entry below is an input named by an Annex B antigen decision table, or an element those
# tables' guidance turns on.
CORE_TABS = {"IMMZ.D Administer vaccine"}

CORE_ELEMENTS = {
    # --- what the client has already had -----------------------------------
    # The series-level history every antigen table opens by counting.
    "IMMZ.D.DE.263",  # Birth dose
    "IMMZ.D.DE.203",  # Completed the primary vaccination series
    "IMMZ.D.DE.257",  # Completed the booster series
    "IMMZ.D.DE.242",  # Date when primary vaccination series was completed - the TBE booster gate
    # --- immune status -----------------------------------------------------
    # The BCG, measles, rubella, varicella and dengue tables all branch on these, and a live
    # vaccine given to a severely immunocompromised client is the harm the branch exists to stop.
    "IMMZ.D.DE.204",  # HIV status
    "IMMZ.D.DE.209",  # Immunocompromised
    "IMMZ.D.DE.210",  # Currently on ART
    "IMMZ.D.DE.215",  # ART start date
    "IMMZ.D.DE.249",  # Immunologically stable - `IMMZ.D2.DT.BCG`
    "IMMZ.D.DE.250",  # Clinically well - `IMMZ.D2.DT.BCG`
    # --- birth and infancy -------------------------------------------------
    "IMMZ.D.DE.208",  # Preterm birth - the hepatitis B and rotavirus schedules
    "IMMZ.D.DE.211",  # Birth weight in grams - the hepatitis B birth-dose branch
    # --- antigen-specific inputs -------------------------------------------
    # A dose type the schedule needs in order to say what the next dose is: the tables count
    # doses of a particular kind, not doses in general.
    "IMMZ.D.DE.212",  # Type of poliovirus dose - IPV / bOPV
    "IMMZ.D.DE.216",  # Type of JE dose
    "IMMZ.D.DE.220",  # Type of TBE dose
    "IMMZ.D.DE.225",  # Type of typhoid dose
    "IMMZ.D.DE.229",  # Type of cholera dose
    "IMMZ.D.DE.232",  # Type of meningococcal dose
    "IMMZ.D.DE.236",  # Age in months when client received first meningococcal dose
    "IMMZ.D.DE.237",  # Type of hepatitis A dose
    "IMMZ.D.DE.254",  # Type of hepatitis B dose - see ELEMENT_TYPES
    # --- eligibility tests the tables read ---------------------------------
    "IMMZ.D.DE.243",  # Type of TB infection test performed - IGRA / TST
    "IMMZ.D.DE.246",  # TB infection test result - the BCG branch past 28 days
    "IMMZ.D.DE.251",  # High risk of pneumococcal infection
    "IMMZ.D.DE.240",  # VNA level - the rabies booster decision
    "IMMZ.D.DE.253",  # Risk of occupational exposure to rabies virus
    "IMMZ.D.DE.241",  # Dengue serostatus - dengue vaccination requires seropositivity
    # --- counselling and the next visit ------------------------------------
    # `IMMZ.D7` and `IMMZ.D18` hold one and two elements; none is flagged or linked, so without
    # these the two activities contribute nothing and the schedule's own output - when to come
    # back - would have nowhere to be written.
    "IMMZ.D.DE.86",  # Client education and counselling on immunization
    "IMMZ.D.DE.185",  # Date/time of follow-up appointment
    "IMMZ.D.DE.186",  # Recommended follow-up date
    # --- adverse events ----------------------------------------------------
    # Annex C's `IMMZ.IND.44` carries the reaction, its manifestation and its type; the date it
    # happened and how it ended are unlinked, and an adverse event recorded without them cannot
    # be followed up or closed.
    "IMMZ.D.DE.93",  # Reaction date
    "IMMZ.D.DE.115",  # Reaction outcome
}

# Annex B states its logic as one decision table per antigen — 24 of them — each computing
# `IMMZ.D.DE156 Immunization recommendation status` from the client's age, the doses already
# counted and the immune-status elements above. None of that is expressible in a survey form: the
# inputs are date arithmetic over a dose history the form does not hold. What a form can do is
# carry the kit's guidance for the status a health worker records, which is the same guidance
# every antigen table reaches for that status, so the prompts gate on the recorded value rather
# than reproducing 498 antigen-and-dose-specific strings.
DECISION_SUPPORT = [
    {
        "rule": "IMMZ.D2.DT",
        "survey": "status",
        "after": "IMMZ.D.DE156",
        "code": "whodakimmz-ds-d2-due",
        "name": "Dose due - check for contraindications",
        "guidance": ("Vaccinate the client with the dose the schedule calls for. Check for contraindications first."),
        "gate": {"IMMZ.D.DE156": "Due"},
    },
    {
        "rule": "IMMZ.D2.DT",
        "survey": "status",
        "after": "IMMZ.D.DE156",
        "code": "whodakimmz-ds-d2-not-due",
        "name": "Not due - schedule the next visit",
        "guidance": ("Check for any vaccines due and inform the caregiver of when to come back for the next dose."),
        "gate": {"IMMZ.D.DE156": "Not due"},
    },
    {
        "rule": "IMMZ.D2.DT",
        "survey": "status",
        "after": "IMMZ.D.DE156",
        "code": "whodakimmz-ds-d2-complete",
        "name": "Schedule complete",
        "guidance": (
            "The immunization schedule is complete. Check for any other vaccines due and inform "
            "the caregiver of when to come back."
        ),
        "gate": {"IMMZ.D.DE156": "Completed"},
    },
    {
        "rule": "IMMZ.D5.DT",
        "survey": "status",
        "after": "IMMZ.D.DE156",
        "code": "whodakimmz-ds-d5-contraindicated",
        "name": "Contraindicated - do not vaccinate",
        "guidance": (
            "Do not vaccinate the client. Record the contraindication, check for any other "
            "vaccines due and inform the caregiver of when to come back."
        ),
        "gate": {"IMMZ.D.DE156": "Contraindicated"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Vaccination contraindicated - record the contraindication",
        },
    },
    {
        "rule": "IMMZ.D2.DT",
        "survey": "status",
        "after": "IMMZ.D.DE156",
        "code": "whodakimmz-ds-d2-further-evaluation",
        "name": "Further evaluation needed",
        "guidance": "Clinical judgement is required. Create a clinical note.",
        "gate": {"IMMZ.D.DE156": "Further evaluation needed"},
        "issue": {
            "issueType": "warning",
            "issueNote": "Immunization status needs clinical evaluation",
        },
    },
    # Annex C counts serious adverse events on `IMMZ.IND.44`, and the kit's severity list is the
    # WHO definition of a serious AEFI. A non-serious reaction is recorded and no prompt fires.
    {
        "rule": "IMMZ.D17",
        "survey": "aefi",
        "after": "IMMZ.D.DE.107",
        "code": "whodakimmz-ds-d17-serious-aefi",
        "name": "Serious adverse event - report and follow up",
        "guidance": (
            "Report the adverse event through the national AEFI reporting system and follow the "
            "client up until the outcome is known."
        ),
        "gate": {
            "IMMZ.D.DE.107": [
                "Death",
                "Life threatening",
                "Disability",
                "Hospitalization",
                "Congenital anomaly",
                "Other important medical event (specify)",
            ]
        },
        "issue": {
            "issueType": "warning",
            "issueNote": "Serious adverse event following immunization - reporting required",
        },
    },
]

# --- the Tamanu program registry --------------------------------------------
# Not from the DAK, which has no registry concept.
REGISTRY = {
    "registryCode": "who-dak-immz",
    "registryName": "WHO DAK Immunization",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    # Off, because this kit gives no interval to set it from. Tamanu's loss to follow-up is one
    # threshold over the whole registration, and an immunisation schedule has no single interval:
    # the routine gap runs from four weeks between primary-series doses to years between a
    # toddler booster and an adolescent dose. The kit says so itself — most of its antigen
    # schedules answer "when does the service become overdue?" with "to be determined by Member
    # States; however, there is no recommended overdue date", and the ones that do give a date
    # anchor it to the client's date of birth or to their latest dose of that antigen. Any single
    # number here marks a correctly scheduled child as lost, so being overdue is recorded as a
    # clinical status against what the client is actually due for.
    "lossToFollowUpEnabled": False,
    # Where this client stands against their schedule. The first five are the kit's own
    # `IMMZ.D.DE156 Immunization recommendation status` values read at the client level rather
    # than per antigen dose; the rest are the pathway's, since the kit has no element that closes
    # a client's immunisation record.
    "clinicalStatuses": [
        {"code": "who-dak-immz-up-to-date", "name": "Up to date", "color": "green"},
        {"code": "who-dak-immz-due", "name": "Dose due", "color": "yellow"},
        {"code": "who-dak-immz-overdue", "name": "Dose overdue", "color": "orange"},
        {"code": "who-dak-immz-complete", "name": "Schedule complete", "color": "blue"},
        {"code": "who-dak-immz-further-evaluation", "name": "Further evaluation needed", "color": "teal"},
        {"code": "who-dak-immz-contraindicated", "name": "Contraindicated", "color": "brown"},
        {"code": "who-dak-immz-refused", "name": "Caregiver refusal", "color": "pink"},
        {"code": "who-dak-immz-defaulted", "name": "Defaulted", "color": "red"},
        {"code": "who-dak-immz-transferred-out", "name": "Transferred out", "color": "grey"},
        {"code": "who-dak-immz-died", "name": "Client died", "color": "purple"},
    ],
    # The contraindications that decide which vaccines a client can be given and that they carry
    # between contacts, so the registry holds them rather than each contact re-collecting them.
    # Each traces to an option of `IMMZ.D.DE.161 Potential contraindications`. The transient
    # members of that list are not here — pregnancy, planning pregnancy within the month,
    # breastfeeding, receiving blood products, acute gastroenteritis, severe acute illness,
    # moderate to severe fever and taking antibiotics defer today's dose rather than describing
    # the client, and the form records them at the contact where they apply.
    "conditions": [
        {"code": "who-dak-immz-cond-immunocompromised", "name": "Immunocompromised"},
        {"code": "who-dak-immz-cond-severely-immunocompromised", "name": "Severely immunocompromised"},
        {"code": "who-dak-immz-cond-immunosuppressive-treatment", "name": "Exposed to immunosuppressive treatment"},
        {"code": "who-dak-immz-cond-severely-immunosuppressed", "name": "Severely immunosuppressed"},
        {"code": "who-dak-immz-cond-immunodeficiency", "name": "Immunodeficiency syndromes"},
        {"code": "who-dak-immz-cond-altered-immunocompetence", "name": "Altered immunocompetence"},
        {"code": "who-dak-immz-cond-anaphylaxis-history", "name": "History of anaphylactic reactions"},
        {"code": "who-dak-immz-cond-severe-allergic-reaction", "name": "Severe allergic reactions"},
        {"code": "who-dak-immz-cond-vaccine-hypersensitivity", "name": "Hypersensitivity to vaccine components"},
        {"code": "who-dak-immz-cond-symptomatic-hiv", "name": "Symptomatic HIV infection"},
        {"code": "who-dak-immz-cond-tb-disease", "name": "TB disease"},
        {"code": "who-dak-immz-cond-spina-bifida", "name": "Spina bifida"},
        {"code": "who-dak-immz-cond-bladder-exstrophy", "name": "Bladder exstrophy"},
        {"code": "who-dak-immz-cond-intussusception", "name": "Prior history of intussusception"},
    ],
}
