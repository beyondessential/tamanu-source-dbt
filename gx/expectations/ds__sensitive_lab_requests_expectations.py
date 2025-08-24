import great_expectations as gx
from great_expectations.core.expectation_suite import ExpectationSuite


def main():
    context = gx.get_context()
    suite_name = "ds__sensitive_lab_requests_expectations"

    # Delete existing suite and create new one to ensure clean state
    try:
        context.suites.delete(suite_name)
    except:
        pass  # Suite doesn't exist, that's fine

    # Create fresh expectation suite
    suite = context.suites.add(ExpectationSuite(name=suite_name))

    # Table-level expectations
    suite.add_expectation(
        gx.expectations.ExpectQueryResultsToMatchComparison(
            base_query="select count(*) from reporting.ds__sensitive_lab_requests",
            comparison_data_source_name="tamanu_rl",
            comparison_query="""
    select count(distinct lr.id)
    from lab_requests lr
    join lab_tests lt on lt.lab_request_id = lr.id
    join lab_test_types ltt on ltt.id = lt.lab_test_type_id
    where ltt.is_sensitive""",
            mostly=1,
            meta={
                "description": "Lab requests dataset should equal the number of distinct request_id in base lab requests table"
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

    # Workflow date and time validations
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
where (collected_datetime notnull and requested_datetime > collected_datetime)
    or (completed_datetime notnull and requested_datetime > completed_datetime)
    or (collected_datetime notnull and completed_datetime notnull and collected_datetime > completed_datetime)""",
            meta={
                "description": "Workflow datetimes should be in correct order: requested <= collected <= completed"
            },
        )
    )

    # Request expectations
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="requested_by_id",
            meta={"description": "Request by user ID should not be null"},
        )
    )

    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(
            column="requesting_department_id",
            meta={"description": "Requesting department ID should not be null"},
        )
    )

    suite.add_expectation(
        gx.expectations.UnexpectedRowsExpectation(
            unexpected_rows_query="""
select * 
from {batch} lr
left join reporting.reference_data rd on rd.id = lr.priority_id
where rd.id is null""",
            meta={
                "description": "Priority ID should match a valid reference data entry"
            },
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
            column="tests",
            meta={
                "description": "Tests should not be null - every lab request should have associated tests"
            },
        )
    )

    # Collection expectations
    suite.add_expectation(
        gx.expectations.UnexpectedRowsExpectation(
            unexpected_rows_query="""
select * 
from {batch}
where not (collected_datetime is not null and collected_by_id is not null and specimen_type is not null and site is not null)
    or not (collected_datetime is null and collected_by_id is null and specimen_type is null and site is null)""",
            meta={
                "description": "Collection fields should be all present or all null together"
            },
        )
    )

    print(f"Successfully created expectation suite: {suite.name}")
    print(f"Number of expectations: {len(suite.expectations)}")
    return suite


if __name__ == "__main__":
    main()
