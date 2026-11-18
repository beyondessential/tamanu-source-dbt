"""The family planning domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's Annex A and B. What differs per
domain is which tabs become which surveys, which elements are worth carrying, which decision
rules are encodable, and the registry, which is a Tamanu construct with no DAK equivalent.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for family planning (2021).
# Publication: https://www.who.int/publications/i/item/9789240029743
DAK = {
    "title": "Digital adaptation kit for family planning (2021)",
    "elementPrefix": "FP.",  # stripped from data element ids when deriving codes
}

# Web Annexes, fetched not committed (see ../../../.gitignore). Checksums are the copies these
# artefacts were generated from, so a WHO revision announces itself rather than quietly changing
# a form. `handle` is the IRIS handle; `url` is the DSpace bitstream content URL it resolves to.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "WHO-SRH-21.13-eng.xlsx",
        "handle": "10665/341998",
        "url": "https://iris.who.int/server/api/core/bitstreams/406d65f8-7a8a-49dc-ad11-2c5ea805c7cb/content",
        "sha256": "572369e4b16eab69a1a6224288086eff4062f5fa6a104da17d6da63e28faec1e",
    },
    "B": {
        "name": "decision support logic",
        "filename": "WHO-SRH-21.14-eng.xlsx",
        "handle": "10665/341999",
        "url": "https://iris.who.int/server/api/core/bitstreams/ea37207e-aeed-4675-b1c3-94e76aa0ba25/content",
    },
    "C": {
        "name": "indicators and performance metrics",
        "filename": "WHO-SRH-21.15-eng.xlsx",
        "handle": "10665/342000",
        "url": "https://iris.who.int/server/api/core/bitstreams/ac9db106-a2d2-4ac4-8c51-628b366ab8b6/content",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "WHO-SRH-21.16-eng.xlsx",
        "handle": "10665/342001",
        "url": "https://iris.who.int/server/api/core/bitstreams/93aebec4-1089-4267-a464-8e56c7aa4a28/content",
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header
# names: this kit spreads its header over three rows of merged cells and gives the two
# computation columns - the ones quoting the element labels - no heading of their own, so there
# is no single header row to match on. Annex A's checksum pins the file these were read from.
#
# `firstDataRow` is the spreadsheet's own row number; `columns` are zero-based offsets, so
# `id: 1` is column B. An off-by-one on `numerator` reads the prose Definition column instead
# and every indicator then reports no quoted elements rather than failing.
ANNEX_C = {
    "sheet": "Indicator table",
    "firstDataRow": 6,
    "columns": {"id": 1, "name": 2, "numerator": 4, "denominator": 6},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK FP",
    "programCode": "who-dak-fp",
    "codePrefix": "whodakfp",  # question codes: whodakfp-b-de257
}

# One survey per business process. Annex A has four `FP.*` tabs and all four define patient
# encounter data, so unlike the ANC and PNC kits there is no configuration tab to leave out.
#
# `FP.D. Referral` maps onto Tamanu's own `referral` survey type; the rest are `programs`.
PROCESSES = [
    {"tab": "FP.A. Registration", "code": "registration", "name": "FP Registration", "surveyType": "programs"},
    {"tab": "FP.B. Counselling", "code": "counselling", "name": "FP Counselling", "surveyType": "programs"},
    {
        "tab": "FP.C. Service provision",
        "code": "serviceprovision",
        "name": "FP Service Provision",
        "surveyType": "programs",
    },
    {"tab": "FP.D. Referral", "code": "referral", "name": "FP Referral", "surveyType": "referral"},
]

# This kit leans on `Required = C` far harder than the others: only 41 of its 121 parent
# elements are `Required = R` and only three carry an Annex C indicator link, so the first two
# selection rules alone leave `FP.C` with five questions and no pregnancy checklist. The
# shortlist is therefore used on the two clinical tabs, and each entry below is either an input
# to an encoded Annex B rule, an element an Annex C calculation names, or a branch the care
# pathway turns on.
CORE_TABS = {"FP.B. Counselling", "FP.C. Service provision"}

CORE_ELEMENTS = {
    # Annex C names these in a numerator or denominator but Annex A links no element to the
    # indicator, so the indicator rule cannot reach them: FP.IND.5 counts "Stopping
    # contraception", FP.IND.4 method switching, FP.IND.7 "Recent miscarriage or abortion" and
    # FP.IND.8 "Time postpartum ≤ 365.25 days".
    "FP.B.DE12",  # Reason for stopping contraception or method
    "FP.B.DE33",  # Postpartum
    "FP.B.DE34",  # Time since delivery
    "FP.B.DE42",  # Miscarriage or abortion within past 4 weeks
    "FP.B.DE105",  # Methods previously used
    # Inputs FP.DT.10's pregnancy checklist reads. Without them the checklist on `FP.C` asks
    # questions whose answers the kit derives from this tab.
    "FP.B.DE35",  # Breastfeeding - see ELEMENT_TYPES
    "FP.B.DE47",  # Start date of last normal menses
    "FP.B.DE50",  # Amenorrhea
    # FP.DT.03, encoded below, and its two Boolean bookends.
    "FP.B.DE133",  # STI risk assessment conducted
    "FP.B.DE134",  # STI risk assessment factors
    "FP.B.DE148",  # Increased risk of STIs
    # The counselling entry point, and why a client who left without one has no method.
    "FP.B.DE16",  # Pregnancy intention
    "FP.B.DE83",  # Reason for no contraceptive method
    "FP.B.DE149",  # Issues and concerns
    # When the method a client arrived on was administered, which is what FP.S.1's follow-up
    # schedule counts from for a client already using one.
    "FP.B.DE79",  # IUD insertion date
    "FP.B.DE80",  # Implant date
    "FP.B.DE81",  # Injection date
    "FP.B.DE82",  # Sterilization date
    # The three branches `FP.B7`, `FP.B9` and `FP.B10` exist to decide, and which say whether
    # this contact ends in a resupply, a removal or a new method.
    "FP.B.DE209",  # Keep method?
    "FP.B.DE213",  # Method removal procedure required?
    "FP.B.DE214",  # Need resupply?
    # How long since unprotected sex, which is the eligibility window for emergency
    # contraception - one of the three `Reason for visit` options.
    "FP.B.DE28",  # Days since unprotected sex
    # The pregnancy checklist, and the conclusion it reaches. Ruling out pregnancy is the safety
    # gate before a hormonal method or an IUD, and every element of it is `Required = C`, so
    # without the shortlist the service-provision form records a method given with no record
    # that pregnancy was excluded.
    "FP.C.DE1",  # Last menstrual bleeding started within the past 7 days
    "FP.C.DE2",  # Abstained from sexual intercourse since last normal menses
    "FP.C.DE3",  # Consistently and correctly using reliable contraceptive method
    "FP.C.DE4",  # Gave birth in the last 4 weeks
    "FP.C.DE5",  # Gave birth less than 6 months ago, fully or nearly fully breastfeeding
    "FP.C.DE6",  # Miscarriage or abortion in the past 7 days
    "FP.C.DE7",  # Miscarriage or abortion in the past 12 days
    "FP.C.DE8",  # Reasonably certain a woman is not pregnant
    "FP.C.DE9",  # Pregnancy test result
    "FP.C.DE12",  # Informed consent
    # Why the client did not leave with the method they chose. FP.IND.6 is "received method of
    # choice", and the stock-out options are the only place this kit records a supply failure.
    "FP.C.DE47",  # Reason for no method at exit
    "FP.C.DE54",  # Reason client did not receive chosen method
    "FP.C.DE62",  # Type of back-up method selected
    # FP.DT.14's output, and the date FP.S.1's whole schedule is expressed against.
    "FP.C.DE68",  # Recommended follow-up date
}

# `FP.B.DE35 Breastfeeding` is typed `Boolean`, with `Input Options` of "Yes/No", and is then
# followed by five `Input Option` rows giving breastfeeding *intensity* — exclusive, fully,
# nearly fully, partially. Read as the dictionary types it, those five options have no `Coding`
# parent to attach to and are dropped, and the element becomes a yes-no.
#
# Annex B settles it: every row of `FP.DT.10`'s pregnancy checklist reads "Breastfeeding status"
# = "Fully breastfeeding" OR "Nearly fully breastfeeding", comparing the element against the
# option strings this kit lists under it. The type comes from the kit's own decision logic
# rather than from a judgement about the element, and lives here rather than in the generator so
# the divergence from Annex A is visible and reviewable. See dak-conformance.md.
ELEMENT_TYPES = {
    "FP.B.DE35": "Coding",  # Breastfeeding - Boolean, with five intensity options beneath it
}

# --- decision support (Annex B) ---------------------------------------------
# A form can prompt; it cannot conclude. Each rule shows the DAK's own guidance when its inputs
# are answered, and leaves the judgement with the clinician. This kit puts twelve of its
# twenty-eight decision tables into the WHO medical eligibility criteria, which a form cannot
# evaluate at all — see dak-conformance.md for what is not encodable and why.
DECISION_SUPPORT = [
    # FP.DT.01 splits returning clients by why they came back: the two rows about problems carry
    # one guidance, the row about routine continuation carries the opposite advice, so they are
    # two prompts rather than one. Annex B's third input, "Reason for follow-up" = "Method
    # switch", is not an option Annex A offers on this element and so cannot be gated on.
    {
        "rule": "FP.DT.01",
        "survey": "counselling",
        "after": "FP.B.DE5",
        "code": "whodakfp-ds-dt01-returning-with-problems",
        "name": "Returning client with a problem - allow more time",
        "guidance": (
            "Give time to clients who need it: returning clients with problems need the most. "
            "Understand the problem and help resolve it, whether that means managing side "
            "effects, treating a condition, or helping the client switch method."
        ),
        "gate": {"FP.B.DE5": ["Issues and concerns / method failure"]},
    },
    {
        "rule": "FP.DT.01",
        "survey": "counselling",
        "after": "FP.B.DE5",
        "code": "whodakfp-ds-dt01-routine-continuation",
        "name": "Routine continuation - little counselling needed",
        "guidance": (
            "Many clients return with no problems and need little counselling. Provide more "
            "supplies or routine follow-up, ask whether the client has any questions, and "
            "confirm the method is still the one they want."
        ),
        "gate": {"FP.B.DE5": ["Contraceptive continuation"]},
    },
    # FP.DT.03 raises on any one of twelve STI risk factors and gives the same guidance for all
    # of them, so a gate naming every factor would be the whole rule in one prompt. It
    # serialises to 430 characters against a varchar(255) `visibility_criteria` column, so the
    # rule is emitted as three prompts carrying the same guidance, split where the list crosses
    # the limit rather than on any clinical grouping - Annex B draws no distinction between the
    # factors, and dropping factors to fit is not an option when the point of the rule is that
    # any one of them raises the client's risk. All twelve are gated across the three parts; a
    # client with factors from more than one part sees more than one prompt, which is the right
    # failure.
    #
    # "No risk factors" is Annex A's thirteenth option and is deliberately not gated on: it is
    # the answer that means the rule does not apply.
    {
        "rule": "FP.DT.03 (1 of 3)",
        "survey": "counselling",
        "after": "FP.B.DE134",
        "code": "whodakfp-ds-dt03-sti-risk-a",
        "name": "Increased risk of STIs - counsel on dual protection",
        "guidance": (
            "This client is at increased risk of sexually transmitted infections. Male and "
            "female condoms prevent STIs when used consistently and correctly, so discuss dual "
            "protection: condoms alone, or condoms together with another contraceptive method."
        ),
        "gate": {
            "FP.B.DE134": [
                "Adolescent female",
                "HIV+",
                "Frequent change in sexual partners",
                "Multiple sexual partners",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Increased risk of STIs recorded at FP counselling"},
    },
    {
        "rule": "FP.DT.03 (2 of 3)",
        "survey": "counselling",
        "after": "FP.B.DE134",
        "code": "whodakfp-ds-dt03-sti-risk-b",
        "name": "Increased risk of STIs - counsel on dual protection",
        "guidance": (
            "This client is at increased risk of sexually transmitted infections. Male and "
            "female condoms prevent STIs when used consistently and correctly, so discuss dual "
            "protection: condoms alone, or condoms together with another contraceptive method."
        ),
        "gate": {
            "FP.B.DE134": [
                "Sex worker",
                "Sex worker client",
                "Unprotected sex",
                "Skin piercing",
                "History of STI in the last year",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Increased risk of STIs recorded at FP counselling"},
    },
    {
        "rule": "FP.DT.03 (3 of 3)",
        "survey": "counselling",
        "after": "FP.B.DE134",
        "code": "whodakfp-ds-dt03-sti-risk-c",
        "name": "Increased risk of STIs - counsel on dual protection",
        "guidance": (
            "This client is at increased risk of sexually transmitted infections. Male and "
            "female condoms prevent STIs when used consistently and correctly, so discuss dual "
            "protection: condoms alone, or condoms together with another contraceptive method."
        ),
        "gate": {
            "FP.B.DE134": [
                "Sex with partner who has STI symptoms",
                "Sex with partner who has recently been diagnosed with or treated for an STI",
                "Separated from regular sex partners for long periods of time",
            ]
        },
        "issue": {"issueType": "warning", "issueNote": "Increased risk of STIs recorded at FP counselling"},
    },
    # FP.DT.06 is the counselling-time rule, and its two branches give opposite advice: a client
    # who already knows what they want needs their understanding checked, a client who does not
    # needs the longest consultation the service gives. Gated on the Boolean's answer body,
    # which is what Tamanu stores for a Binary question.
    {
        "rule": "FP.DT.06",
        "survey": "counselling",
        "after": "FP.B.DE215",
        "code": "whodakfp-ds-dt06-method-in-mind",
        "name": "Client has a method in mind - check their understanding",
        "guidance": (
            "Check that the client's understanding of the method is accurate. Support their "
            "choice if they are medically eligible, and discuss how to use the method and what "
            "to do about side effects."
        ),
        "gate": {"FP.B.DE215": "Yes"},
    },
    {
        "rule": "FP.DT.06",
        "survey": "counselling",
        "after": "FP.B.DE215",
        "code": "whodakfp-ds-dt06-no-method-in-mind",
        "name": "No method in mind - allow the most time",
        "guidance": (
            "New clients with no method in mind need the most time. Discuss the client's "
            "situation and plans, what matters most to them about a method, and which of the "
            "methods available here fit what they describe."
        ),
        "gate": {"FP.B.DE215": "No"},
    },
    # FP.DT.10 concludes that pregnancy can be ruled out when any one of its seven checklist
    # questions is answered yes. A Tamanu gate spanning several questions is a conjunction, so
    # the disjunction itself is not encodable; what is encodable is the branch the kit takes
    # when the checklist fails, which is the one with a clinical consequence.
    {
        "rule": "FP.DT.10",
        "survey": "serviceprovision",
        "after": "FP.C.DE8",
        "code": "whodakfp-ds-dt10-pregnancy-not-excluded",
        "name": "Pregnancy not ruled out - test before starting",
        "guidance": (
            "No checklist question was answered yes, so pregnancy cannot be reasonably excluded. "
            "Perform a pregnancy test before starting a hormonal method or inserting an IUD, or "
            "offer a barrier method now and the client's chosen method once pregnancy is "
            "excluded."
        ),
        "gate": {"FP.C.DE8": "No"},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct, and this is our own modelling of
# a client's family planning care. Clinical status and condition codes are prefixed with the
# registry code because `prClinicalStatus-<code>` is a global id and the status code is unique
# database-wide.
REGISTRY = {
    "registryCode": "who-dak-fp",
    "registryName": "WHO DAK FP",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    # The widest routine resupply window in Annex B's own `FP.S.1` schedule: an injectable
    # expires at "Service provision date" + 119 days, against 92 for pills, the patch and the
    # rings. A threshold below that would flag a client who is still inside the interval the kit
    # gives them, and Tamanu's default of 90 days does exactly that for every DMPA client.
    "lossToFollowUpThresholdDays": 119,
    # Where this client's family planning care stands. The kit defines no closing element of its
    # own, so these are the states its pathway distinguishes rather than a list the DAK supplies:
    # using a method is the outcome the service exists to reach and reads as the good state,
    # every interruption reads as warm or dark.
    "clinicalStatuses": [
        {"code": "who-dak-fp-using-method", "name": "Using a method", "color": "green"},
        {"code": "who-dak-fp-permanent-method", "name": "Permanent method", "color": "blue"},
        {"code": "who-dak-fp-awaiting-method", "name": "Awaiting method or procedure", "color": "yellow"},
        {"code": "who-dak-fp-no-method", "name": "No method - unmet need", "color": "orange"},
        {"code": "who-dak-fp-referred", "name": "Referred", "color": "teal"},
        {"code": "who-dak-fp-seeking-pregnancy", "name": "Stopped - seeking pregnancy", "color": "pink"},
        {"code": "who-dak-fp-stopped", "name": "Stopped contraception", "color": "brown"},
        {"code": "who-dak-fp-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-fp-transferred-out", "name": "Transferred out", "color": "grey"},
    ],
    # The conditions that restrict which contraceptive methods a client can use and that they
    # carry between contacts, so the registry holds them rather than each contact re-collecting
    # them. Each traces to an option of `FP.B.DE257 Health condition(s)`, and the grouping is the
    # kit's own: these are the condition classes its 21 option-group headings name, which is
    # also the structure the forms have to drop because Tamanu has no option-group construct.
    #
    # Eight are shared with the ANC or PNC registry by design - hypertension, diabetes, anaemia,
    # HIV, tuberculosis, epilepsy, kidney disease and syphilis are carried by the same client
    # across services. Seven are named identically so a deployment reading more than one sees
    # one condition rather than several; diabetes is the exception, because the ANC registry
    # splits it into a gestational and a pre-existing form that a family planning contact does
    # not distinguish.
    #
    # The kit's transient findings are deliberately excluded: `Vaginitis`, `Urinary tract
    # infection`, `Local infection` and the surgical-site options are what one contact observed,
    # and the `Conditions relevant to sterilization and FAB` group is a procedural relevance
    # bucket rather than a condition at all.
    "conditions": [
        {"code": "who-dak-fp-cond-hypertension", "name": "Hypertension"},
        {"code": "who-dak-fp-cond-cardiovascular", "name": "Cardiovascular disease"},
        {"code": "who-dak-fp-cond-vte", "name": "Venous thromboembolism"},
        {"code": "who-dak-fp-cond-diabetes", "name": "Diabetes mellitus"},
        {"code": "who-dak-fp-cond-migraine-aura", "name": "Migraine with aura"},
        {"code": "who-dak-fp-cond-epilepsy", "name": "Epilepsy"},
        {"code": "who-dak-fp-cond-depression", "name": "Depressive disorders"},
        {"code": "who-dak-fp-cond-sle", "name": "Systemic lupus erythematosus"},
        {"code": "who-dak-fp-cond-anaemia", "name": "Anaemia"},
        {"code": "who-dak-fp-cond-thyroid", "name": "Thyroid disorder"},
        {"code": "who-dak-fp-cond-gall-bladder", "name": "Gall bladder disease"},
        {"code": "who-dak-fp-cond-liver-disorder", "name": "Liver disorder"},
        {"code": "who-dak-fp-cond-viral-hepatitis", "name": "Viral hepatitis"},
        {"code": "who-dak-fp-cond-kidney-disease", "name": "Kidney disease"},
        {"code": "who-dak-fp-cond-breast-cancer", "name": "Breast cancer"},
        {"code": "who-dak-fp-cond-cervical-cancer", "name": "Cervical cancer"},
        {"code": "who-dak-fp-cond-gynae-cancer", "name": "Endometrial or ovarian cancer"},
        {"code": "who-dak-fp-cond-gtd", "name": "Gestational trophoblastic disease"},
        {"code": "who-dak-fp-cond-fibroids", "name": "Uterine fibroids"},
        {"code": "who-dak-fp-cond-pid", "name": "Pelvic inflammatory disease"},
        {"code": "who-dak-fp-cond-sti", "name": "Sexually transmitted infection"},
        {"code": "who-dak-fp-cond-hiv", "name": "HIV"},
        {"code": "who-dak-fp-cond-syphilis", "name": "Syphilis"},
        {"code": "who-dak-fp-cond-tb", "name": "Tuberculosis"},
        {"code": "who-dak-fp-cond-schistosomiasis", "name": "Schistosomiasis"},
        {"code": "who-dak-fp-cond-unexplained-bleeding", "name": "Unexplained vaginal bleeding"},
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
