with filtered_ds as (
	select *
	from {{ ref("ds__lab_tests_msf") }}
	where
		case when {{ parameter('toDate', default_value='2025-01-31', data_type='text') }} is null then true
			else epi_year = extract('year' from {{ parameter('toDate', default_value='2025-01-31', data_type='text') }}::date)
		end
),
combined_attributes as (
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of new patients tested (North facility)", 
            1,
            "count(distinct patient_id)", 
            "department_id = 'department-medicalnorth'
                and visit_rank = 1"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of new patients tested (South facility)", 
            2,
            "count(distinct patient_id)", 
            "department_id = 'department-medicalsouth'
                and visit_rank = 1"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests cancelled (North facility)", 
            3,
            "count(*)", 
            "department_id = 'department-medicalnorth'
                and status = 'cancelled'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests cancelled (South facility)", 
            4,
            "count(*)", 
            "department_id = 'department-medicalsouth'
                and status = 'cancelled'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests pending without sample collected (North facility)",
            5, 
            "count(*)", 
            "department_id = 'department-medicalnorth'
                and status = 'sample-not-collected'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests pending without sample collected (South facility)",
            6, 
            "count(*)", 
            "department_id = 'department-medicalsouth'
                and status = 'sample-not-collected'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests pending (North facility)", 
            7,
            "count(*)", 
            "department_id = 'department-medicalnorth'
                and status in ('interim_results', 'reception_pending', 'results_pending', 'verified')"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of tests pending (South facility)", 
            8,
            "count(*)", 
            "department_id = 'department-medicalsouth'
                and status in ('interim_results', 'reception_pending', 'results_pending', 'verified')"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of invalidated tests (North facility)", 
            9,
            "count(*)", 
            "department_id = 'department-medicalnorth'
                and status = 'invalidated'"
        )
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of invalidated tests (South facility)", 
            10,
            "count(*)", 
            "department_id = 'department-medicalsouth'
                and status = 'invalidated'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of test results published (North facility)", 
            11,
            "count(*)", 
            "department_id = 'department-medicalnorth'
                and status = 'published'"
        )
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of test results published (South facility)", 
            12,
            "count(*)", 
            "department_id = 'department-medicalsouth'
                and status = 'published'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of unique patients (North facility)", 
            13,
            "count(distinct patient_id)", 
            "department_id = 'department-medicalnorth'
                and status = 'published'"
        )
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Number of unique patients (South facility)", 
            14,
            "count(distinct patient_id)", 
            "department_id = 'department-medicalsouth'
                and status = 'published'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Pregnancy test", 
            15,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-PregnancyTest'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Hemoglobin", 
            16,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-Haemoglobin'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Urineanalysis", 
            17,
            "count(distinct lab_request_id)", 
            "status = 'published'
                and lab_test_panel_id = 'labTestPanel-Urinealysis'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Glucose fasting", 
            18,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-GlucoseFasting'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Glucose random", 
            19,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-GlucoseRandom'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "HbA1c", 
            20,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-HbA1c'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "CBC", 
            21,
            "count(distinct lab_request_id)", 
            "status = 'published'
                and lab_test_panel_id = 'labTestPanel-CBC'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Biochemistry tests", 
            22,
            "count(distinct lab_request_id)", 
            "status = 'published'
                and lab_test_panel_id = 'labTestPanel-Biochemistryfull'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Triglyceride", 
            23,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-Triglycerides'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Cholesterol", 
            24,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-TotalCholesterol'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Creatinine", 
            25,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-Creatinine'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "ALT", 
            26,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-ALT'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Na / K / Cl", 
            27,
            "count(distinct lab_request_id)", 
            "status = 'published'
                and lab_test_panel_id = 'labTestPanel-Biochemistrypart'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Calcium", 
            28,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-Calcium'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Magnesium", 
            29,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-Magnesium'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "TSH", 
            30,
            "count(*)", 
            "status = 'published'
                and lab_test_type_id = 'labTestType-TSH'"
        ) 
    }}
    union
    {{ 
        generate_select_attribute_values(
            "epi_week", 
            "Other", 
            31,
            "count(*)", 
            "status = 'published'
                and (lab_test_panel_id not in ('labTestPanel-CBC',
                                                'labTestPanel-Biochemistryfull', 
                                                'labTestPanel-Biochemistrypart',
                                                'labTestPanel-Urinealysis')
                    or lab_test_type_id not in ('labTestType-ALT',
                                                'labTestType-Calcium',
                                                'labTestType-Creatinine',
                                                'labTestType-Haemoglobin',
                                                'labTestType-GlucoseFasting',
                                                'labTestType-GlucoseRandom',
                                                'labTestType-HbA1c',
                                                'labTestType-Magnesium',
                                                'labTestType-PregnancyTest',
                                                'labTestType-Triglycerides',
                                                'labTestType-TSH',
                                                'labTestType-TotalCholesterol'))"
        ) 
    }}
)
select attribute,
{{ generate_sum_case('epi_week', 'value', range(1, 54)) }}
from combined_attributes
group by attribute_order, attribute
order by attribute_order, attribute
