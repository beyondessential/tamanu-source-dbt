"""The SMBP domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is that a **tab is an activity**. Every other kit divides a
process tab into activities and a survey into a screen per activity; this one gives each of its
two tabs a single activity — all 72 rows of the set-up tab are `SMBP.A9`, all 50 of the reading
tab are `SMBP.B4` — and heads no sections, so each survey is one screen. See
`dak-conformance.md` § One activity, one screen.

The other thing to know is that this kit **publishes no Annex C**, so the selection rule's second
clause reaches nothing and the core shortlist carries what `Required = R` alone leaves out. The
one row whose indicator-linkage column is not blank names a decision table rather than an
indicator. See `dak-conformance.md` § No indicators.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for self-monitoring of blood pressure in pregnancy (2025), DAK version
# 1.0.0.
#
# `elementPrefix` is the kit's own name, which every id carries: `SMBP.A9.DE.1` and
# `SMBP.B4.DE.1` stay apart on the segment after it.
DAK = {
    "title": "Digital adaptation kit for self-monitoring of blood pressure in pregnancy (2025)",
    "elementPrefix": "SMBP.",
}

# The kit's components, fetched not committed (see ../../../.gitignore). The sha256 is the copy
# these artefacts were generated from, so a WHO revision announces itself rather than quietly
# changing a form.
#
# Hosted the way the TB, IMMZ, CHE, SRV and BDS kits are: WHO ships the components through its
# SMART guidelines implementation guide, whose component pages serve whatever the site last built,
# so `url` points at WHO's own source repository — `WorldHealthOrganization/smart-dak-smbp` — at
# the `v1.0.0` tag, whose `sushi-config.yaml` declares `status: active` and
# `releaseLabel: release`. Pin the tag, never the branch: `main` is a continuous integration
# build.
#
# **This kit publishes no Annex C.** Its `input/indicators/` directory holds nothing but the
# `.gitignore` that would have hidden the workbook, so there are no aggregate indicators to read,
# there is no `ANNEX_C` layout, and `annex_c_coverage.py` reports the kit as publishing none. See
# `dak-conformance.md` § No indicators.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "SMBP DAK_core data dictionary.xlsx",
        "page": "https://smart.who.int/dak-smbp/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-smbp/v1.0.0/"
            "input/dictionary/SMBP%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "7369c1420c9f659b56610e83752a885139859bbd78f47482816e33e526102890",
    },
    "B": {
        "name": "decision-support logic",
        "filename": "SMBP DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-smbp/decision-logic.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-smbp/v1.0.0/"
            "input/decision-logic/SMBP%20DAK_decision-support%20logic.xlsx"
        ),
        "sha256": "847eac6f5d441ed919da5e30e57206fcefa168ea73d0d80291def0f400c1523f",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "SMBP DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-smbp/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-smbp/v1.0.0/"
            "input/system-requirements/"
            "SMBP%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK Self-monitoring of Blood Pressure in Pregnancy",
    "programCode": "who-dak-smbp",
    "codePrefix": "whodaksmbp",  # question codes: whodaksmbp-b4-de-2
}

# Two tabs, two surveys, and the division is the kit's own: the set-up tab is answered once when
# the client is enrolled and her baseline is taken, the reading tab every time she measures.
#
# No `activities` slice, because there is nothing to slice: each tab carries one activity id
# across every one of its rows.
PROCESSES = [
    {
        "tab": "SMBP.A Identification & prep",
        "code": "setup",
        "name": "SMBP Set-up and Baseline",
        "surveyType": "programs",
    },
    {
        "tab": "SMBP.Conduct SMBP",
        "code": "reading",
        "name": "SMBP Reading",
        "surveyType": "programs",
    },
]

# Elements the patient record already holds. A DAK registers its own client because it cannot
# assume a record exists; Tamanu has one, and collecting a name or a telephone number onto a form
# as well gives a deployment two places to write one fact and no rule for which counts.
#
# The client's support network — `SMBP.A9.DE.20` through `DE.31`, the closest facility, her health
# worker, her pharmacy and her community health worker — is left off the form by the selection
# rule rather than by this list, because it configures the client's own tracking application
# rather than stating a fact about her that Tamanu holds.
PATIENT_RECORD = frozenset(
    {
        "SMBP.A9.DE.1",  # Unique identification
        "SMBP.A9.DE.2",  # First name
        "SMBP.A9.DE.3",  # Last name
        "SMBP.A9.DE.4",  # Date of birth
        "SMBP.A9.DE.5",  # Address
        "SMBP.A9.DE.6",  # Telephone number
        "SMBP.A9.DE.7",  # Email address
    }
)

CORE_TABS = {
    "SMBP.A Identification & prep",
    "SMBP.Conduct SMBP",
}

# One row the kit types as a value of the list it follows rather than as the free-text follow-up
# its own description makes it: `Name of antihypertensive medication the client currently uses`,
# typed `List value` in `Current medications` and conditional on that list having
# `Antihypertensive`. Read literally it is an eighth medication a client can tick, and
# `Antihypertensive name` lands in `survey_response_answers.body` as the drug she is taking. The
# type comes from the element's own description rather than from a judgement about it, and lives
# here rather than in the generator so the divergence from Annex A is visible and reviewable. See
# `dak-conformance.md` § A follow-up typed as one of its parent's values.
ELEMENT_TYPES = {
    "SMBP.A9.DE.49": "String",  # Antihypertensive name - typed `List value`
}

# The third rule exists because the first two drop clinically central but unreported elements, and
# this kit leans on it harder than any other: with no Annex C the indicator clause reaches
# nothing, so `Required = R` is the only rule left standing beside it.
CORE_ELEMENTS = {
    # --- what a reading is read against --------------------------------------
    # Body mass index is `C` on the two measurements it is computed from, and both of those are
    # `O`. All three are the risk stratification a raised reading in pregnancy is interpreted
    # against, and carrying the index alone would leave the kit's own calculation with no inputs.
    "SMBP.A9.DE.8",  # Height
    "SMBP.A9.DE.9",  # Current weight
    "SMBP.A9.DE.10",  # Body mass index
    # Gestational age is what makes a hypertensive disorder of pregnancy classifiable at all —
    # before and after 20 weeks are different diagnoses — and the expected date of delivery is the
    # only element the kit gives it from.
    "SMBP.A9.DE.11",  # Expected date of delivery
    # The drug name, recovered from the medication list by `ELEMENT_TYPES` above. It is `O`, so
    # without this the retyped row is dropped and the antihypertensive a client is taking is
    # recorded as the fact that she takes one.
    "SMBP.A9.DE.49",  # Antihypertensive name
    # --- the prior reading the mandatory question asks after ------------------
    # `SMBP.A9.DE.51 Pre-pregnancy BP readings` is `R` and asks which prior reading is available;
    # the reading itself is three `C` elements. Carrying the question without them records that a
    # prior measurement exists and none of its numbers.
    "SMBP.A9.DE.55",  # Date of prior BP measurement
    "SMBP.A9.DE.56",  # Prior systolic reading
    "SMBP.A9.DE.57",  # Prior diastolic reading
    # --- the baseline the whole set-up process exists to establish ------------
    # Both averages are `C` on the four readings above them, which are `R`. Every later reading is
    # read against these two numbers, so a set-up form collecting the four and not the average of
    # each records the measurements and not the baseline.
    "SMBP.A9.DE.66",  # Baseline average seated systolic reading
    "SMBP.A9.DE.71",  # Baseline average seated diastolic reading
    # --- the contextual block, and the gate that opens it --------------------
    # The gate is `C`, and its own indicator-linkage column names a decision table rather than an
    # indicator. Read strictly the linkage rule should not reach it, so it is named here as well:
    # a WHO revision that tidies that column would otherwise drop the gate and with it every
    # question below.
    "SMBP.B4.DE.8",  # Contextual data for measurement required
    # What the gate opens. Caffeine, tobacco, exercise, a full bladder, the room, the noise, the
    # client's posture and what she was doing all move a blood pressure reading, which is why the
    # kit asks after them the moment one comes back high. All nine are `O` or `C` and none is
    # linked to anything, so the first two rules carry the question asking whether context is
    # needed and none of the context.
    "SMBP.B4.DE.9",  # Time of last caffeinated drink
    "SMBP.B4.DE.10",  # Time of last tobacco product
    "SMBP.B4.DE.11",  # Time of last exercise or other physical activity
    "SMBP.B4.DE.12",  # Bladder empty?
    "SMBP.B4.DE.13",  # SMBP measurement location
    "SMBP.B4.DE.20",  # Location temperature
    "SMBP.B4.DE.24",  # Location noise
    "SMBP.B4.DE.29",  # Activity level
    "SMBP.B4.DE.34",  # Body position during SMBP measurement
}

# --- Annex B ----------------------------------------------------------------
# Three decision tables, of which a form expresses the referral thresholds that hold for every
# client and the danger-sign list.
#
# What it cannot express is the lowered threshold the kit gives a client with diabetes — 130/80
# rather than 140/90 — because every one of those rows reads `Current health conditions`, which is
# collected once at set-up and so is not a question of the reading survey that a gate could name.
# The thresholds below are the ones that hold regardless, and a client with diabetes is prompted
# at the general threshold rather than at hers; the registry carries her diabetes as a condition,
# which is what makes the lowered threshold recoverable downstream. See `dak-conformance.md` § A
# threshold that reads another survey.
#
# No reassurance is encoded at all — neither `SMBP.B7.DT.01`'s "blood pressure is controlled" rows
# nor `SMBP.B7.DT.02`'s "no danger sign" row. Each of them can fire beside the warning it
# contradicts, and the asymmetry is the point: a warning this form cannot raise under-triggers,
# where a reassurance it cannot suppress misinforms. See `dak-conformance.md` § No reassurance is
# encoded.
#
# Ranges are bounded rather than open-ended so that one reading raises one prompt. The kit's rows
# overlap — 165 mmHg satisfies both `≥ 160` and `≥ 140` — and a decision table takes the first
# matching row where a form shows every prompt whose gate is met.
#
# `end` is **exclusive**: Tamanu evaluates a range gate with lodash's `inRange`, so `start <= v <
# end` (`@tamanu/utils/src/criteria.ts`). A band ending at the value the next band starts at is
# therefore contiguous, and one written to its own last value leaves that value in neither —
# `end: 159` is 140-158, and a systolic of exactly 159 raises nothing at all.
DECISION_SUPPORT = [
    {
        "rule": "SMBP.B4.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.4",
        "code": "whodaksmbp-ds-b4dt01-systolic",
        "name": "Systolic 140 or above - record the context",
        "guidance": (
            "The reading is high. Record what the client was doing and where she was immediately "
            "before and during the measurement - these change how the reading is interpreted."
        ),
        "gate": {"SMBP.B4.DE.4": {"type": "range", "start": 140, "end": 1000}},
    },
    {
        "rule": "SMBP.B4.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.7",
        "code": "whodaksmbp-ds-b4dt01-diastolic",
        "name": "Diastolic 90 or above - record the context",
        "guidance": (
            "The reading is high. Record what the client was doing and where she was immediately "
            "before and during the measurement - these change how the reading is interpreted."
        ),
        "gate": {"SMBP.B4.DE.7": {"type": "range", "start": 90, "end": 1000}},
    },
    {
        "rule": "SMBP.B7.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.4",
        "code": "whodaksmbp-ds-b7dt01-systolic-severe",
        "name": "Systolic 160 or above - go to a facility right away",
        "guidance": (
            "Blood pressure is very high. The client needs to go to a health facility right now "
            "to protect herself and her baby."
        ),
        "gate": {"SMBP.B4.DE.4": {"type": "range", "start": 160, "end": 1000}},
        "issue": {
            "issueType": "warning",
            "issueNote": "Systolic 160 or above - immediate referral required",
        },
    },
    {
        "rule": "SMBP.B7.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.7",
        "code": "whodaksmbp-ds-b7dt01-diastolic-severe",
        "name": "Diastolic 110 or above - go to a facility right away",
        "guidance": (
            "Blood pressure is very high. The client needs to go to a health facility right now "
            "to protect herself and her baby."
        ),
        "gate": {"SMBP.B4.DE.7": {"type": "range", "start": 110, "end": 1000}},
        "issue": {
            "issueType": "warning",
            "issueNote": "Diastolic 110 or above - immediate referral required",
        },
    },
    {
        "rule": "SMBP.B7.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.4",
        "code": "whodaksmbp-ds-b7dt01-systolic-high",
        "name": "Systolic 140-159 - contact a health worker",
        "guidance": ("Blood pressure is high. The client needs to contact a health worker or go to a health facility."),
        "gate": {"SMBP.B4.DE.4": {"type": "range", "start": 140, "end": 160}},
    },
    {
        "rule": "SMBP.B7.DT.01",
        "survey": "reading",
        "after": "SMBP.B4.DE.7",
        "code": "whodaksmbp-ds-b7dt01-diastolic-high",
        "name": "Diastolic 90-109 - contact a health worker",
        "guidance": ("Blood pressure is high. The client needs to contact a health worker or go to a health facility."),
        "gate": {"SMBP.B4.DE.7": {"type": "range", "start": 90, "end": 110}},
    },
    {
        "rule": "SMBP.B7.DT.02",
        "survey": "reading",
        "after": "SMBP.B4.DE.40",
        "code": "whodaksmbp-ds-b7dt02-danger-sign",
        "name": "Danger sign - contact a health worker right away",
        "guidance": ("The client should contact a health worker and go to her nearest health facility right away."),
        # The eight the decision table classifies as danger signs. `Severe non-abdominal pain` is
        # an option of the dictionary's list and a row of no decision table, so it raises nothing;
        # a rule for it would be a clinical recommendation WHO has not made.
        "gate": {
            "SMBP.B4.DE.40": [
                "Breathing difficulty",
                "Bleeding vaginally",
                "Convulsing",
                "Fever",
                "Severe headache",
                "Severe vomiting",
                "Severe abdominal pain",
                "Visual disturbance",
            ]
        },
        "issue": {
            "issueType": "warning",
            "issueNote": "Danger sign of pregnancy - urgent referral",
        },
    },
    # `SMBP.B7.DT.02`'s ninth row — `No symptoms` -> "continue to self-monitor regularly" — is not
    # encoded. `Danger signs` is a `List - select all that apply`, so the kit's own guard against
    # picking `No symptoms` beside a real sign is a `Validation condition` ("Cannot select with any
    # other option") and nothing else; the form carries the mandatory flag and no exclusivity rule,
    # and a Tamanu multi-select gate matches on any selected value. Answered `["No symptoms",
    # "Severe headache"]` the reassurance and the urgent referral would render side by side.
]

# --- the Tamanu program registry --------------------------------------------
# Not from the DAK. A DAK has no registry concept: it specifies the data a reading is recorded
# with, not the enrolment that says a client is being followed. The registry is what makes a
# stream of readings an episode in Tamanu, and its vocabulary is taken from the kit's own elements
# and decision tables so that what the registry says and what the forms collect are the same
# statement.
REGISTRY = {
    "registryCode": "who-dak-smbp",
    "registryName": "WHO DAK Self-monitoring of Blood Pressure",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    # Self-monitoring is a schedule of repeated readings and a client who stops submitting them is
    # exactly what the program watches for, but the kit states no monitoring interval: its
    # scheduling-logic column is empty on all 122 rows and it publishes no scheduling annexe. A
    # threshold chosen here would mark a client lost to follow-up on a cadence WHO has not set, so
    # the deployment sets one or leaves it off.
    "lossToFollowUpEnabled": False,
    # Where the episode stands. The kit has no case-status element — unlike the surveillance kits,
    # whose statuses are their own — so this is our own modelling of its two processes: enrolment
    # and baseline, then the readings, then a close.
    "clinicalStatuses": [
        {"code": "who-dak-smbp-enrolled", "name": "Enrolled", "color": "blue"},
        {"code": "who-dak-smbp-monitoring", "name": "Monitoring", "color": "green"},
        {"code": "who-dak-smbp-referred", "name": "Referred to health worker", "color": "orange"},
        {"code": "who-dak-smbp-pregnancy-ended", "name": "Pregnancy ended", "color": "purple"},
        {"code": "who-dak-smbp-stopped", "name": "Monitoring stopped", "color": "yellow"},
        {"code": "who-dak-smbp-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-smbp-moved-away", "name": "Moved away", "color": "teal"},
    ],
    # What the client is monitored for, carried across readings rather than held only by the
    # set-up form. The first four are the value set of `SMBP.A9.DE.32 Type of hypertensive
    # disorder of pregnancy`, which is `R`.
    #
    # The four diabetes rows are load-bearing rather than descriptive: `SMBP.B7.DT.01` lowers the
    # referral threshold from 140/90 to 130/80 for a client with diabetes, and that gate cannot be
    # expressed on the reading form because the answer lives on the set-up form. Held as a
    # registry condition, the diabetes is attached to the registration every reading is recorded
    # against, which is what lets a `metric__` layer apply the threshold the form could not.
    #
    # Two of them are named by the decision table and by no row of the dictionary, whose `Current
    # health conditions` list offers gestational diabetes and `Diabetes, other or unspecified` and
    # nothing between. The strings are the decision table's own. See `dak-conformance.md` § A
    # value the decision logic names and the dictionary does not.
    "conditions": [
        {"code": "who-dak-smbp-cond-chronic-hypertension", "name": "Chronic hypertension"},
        {"code": "who-dak-smbp-cond-gestational-hypertension", "name": "Gestational hypertension"},
        {"code": "who-dak-smbp-cond-pre-eclampsia", "name": "Pre-eclampsia"},
        {
            "code": "who-dak-smbp-cond-superimposed-pre-eclampsia",
            "name": "Chronic hypertension with superimposed pre-eclampsia",
        },
        {"code": "who-dak-smbp-cond-gdm", "name": "Diabetes arising in pregnancy (gestational diabetes)"},
        {"code": "who-dak-smbp-cond-diabetes-type-1", "name": "Diabetes, pre-existing type 1"},
        {"code": "who-dak-smbp-cond-diabetes-type-2", "name": "Diabetes, pre-existing type 2"},
        {"code": "who-dak-smbp-cond-diabetes-other", "name": "Diabetes, other or unspecified"},
    ],
    # Tamanu hard-loads unknown / disproven / resolved / recordedInError into every registry and
    # merges spreadsheet rows over them. Those four cannot express a condition that is *held*, and
    # self-monitoring exists to catch a rise before it is diagnosed, so the two ends of that are
    # added. These codes are deliberately unprefixed: Tamanu's UI carries labels for exactly these
    # strings, and they are scoped per registry.
    "conditionCategories": [
        {"code": "suspected", "name": "Suspected"},
        {"code": "confirmed", "name": "Confirmed"},
    ],
}
