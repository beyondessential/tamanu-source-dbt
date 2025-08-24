import great_expectations as gx
from great_expectations.core.expectation_suite import ExpectationSuite


def main():
    context = gx.get_context()
    suite_name = "ds__lab_tests_expectations"

    # Delete existing suite and create new one to ensure clean state
    try:
        context.suites.delete(suite_name)
    except Exception:
        pass  # Suite doesn't exist, that's fine

    # Create fresh expectation suite
    suite = context.suites.add(ExpectationSuite(name=suite_name))

    # Table-level expectations
    suite.add_expectation(
        gx.expectations.ExpectQueryResultsToMatchComparison(
            base_query="select count(*) from reporting.ds__lab_tests",
            comparison_data_source_name="tamanu_release",
            comparison_query="select count(*) from lab_tests lt join lab_test_types ltt on ltt.id = lt.lab_test_type_id where not ltt.is_sensitive",
            mostly=1,
            meta={
                "description": "Lab tests dataset should equal the number of non-sensitive lab tests in base table"
            },
        )
    )

    # Patient identifier expectations
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="patient_id", meta={"description": "Patient ID should not be null"}
        )
    )

    # Status validations using actual status values from the dataset
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="status_id",
            meta={"description": "Status ID should not be null"},
        )
    )

    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeInSet(
            column="status_id",
            value_set=[
                "reception_pending",
                "results_pending",
                "to_be_verified",
                "verified",
                "published",
                "cancelled",
                "deleted",
                "sample-not-collected",
                "entered-in-error",
            ],
            meta={
                "description": "Status ID should be one of the valid lab request statuses"
            },
        )
    )

    # Date and time validations
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="requested_datetime",
            meta={"description": "Requested datetime should not be null"},
        )
    )

    suite.add_expectation(
        gx.expectations.UnexpectedRowsExpectation(
            unexpected_rows_query="""
select * 
from {batch} 
where lab_test_completed_datetime notnull 
    and requested_datetime > lab_test_completed_datetime""",
            meta={
                "description": "Lab test completion datetime should be after request datetime"
            },
        )
    )

    # Request expectations
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="lab_request_id", meta={"description": "Lab request ID should not be null"}
        )
    )

    # Requesting user expectations
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="requested_by_id",
            meta={"description": "Request by user ID should not be null"},
        )
    )

    suite.add_expectation(
        gx.expectations.UnexpectedRowsExpectation(
            unexpected_rows_query="""
select * 
from {batch} lr
left join reporting.reference_data rd on rd.id = lr.lab_test_category_id
where rd.id is null""",
            meta={
                "description": "Lab test category ID should match a valid reference data entry"
            },
        )
    )

    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="lab_test_type_id", meta={"description": "Lab test type ID should not be null"}
        )
    )

    print(f"Successfully created expectation suite: {suite.name}")
    print(f"Number of expectations: {len(suite.expectations)}")
    return suite


if __name__ == "__main__":
    main()
