# dbt Model Spec: `metric__user_login`

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__user_login` |
| **Type** | dbt model (D5 metric view) |
| **Layer** | metric |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6980](https://linear.app/bes/issue/MAUI-6980/tupaia-user-login-activity) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-10-08 |
| **Last updated** | 2026-10-08 |

## Purpose

Supplies the user and login counts behind a "share of users who logged in" indicator, such as a Tupaia dashboard item. Registered in `documentations/metrics/user.yml` as `active_user` and `user_login`.

## Grain

- `active_user`: one row per user x designation x allowed facility.
- `user_login`: one row per successful login x designation x allowed facility.

A user with several designations or facilities appears several times, so consumers count distinct `subject_id`.

## Inputs

`users`, `user_designations`, `reference_data` (type `designation`), `user_facilities`, `user_login_attempts`.

## Business logic

- **BL-001:** Every non-deleted user of any status or role, except the Tamanu system user (`00000000-0000-0000-0000-000000000000`). `role_id` and `visibility_status` are exposed so consumers choose who counts, for example activated users only.
- **BL-002:** Every designation in reference data, as `designation_id` and `designation`. No names are fixed here. Consumers choose which designations to show.
- **BL-003:** One row per user (`active_user`) or per login (`user_login`), so `value_numeric` is always 1.
- **BL-004:** A login is a `user_login_attempts` row with `outcome = 'succeeded'`, dated to the login day in the deployment timezone. `active_user` is dated to the day the view is read.
- **BL-005:** The share of users who logged in is distinct `subject_id` in `user_login` over distinct `subject_id` in `active_user`, for the same filters. Summing across designations would double-count multi-designation users.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | Unique per `metric_id`, `subject_id`, `event_id`, `designation`, `facility_id` | grain |
| AC-002 | `metric_id` is `active_user` or `user_login` and is registered | BL-003 |
| AC-003 | `active_user` counts by designation equal the `user-login-activity` report's user counts for the same filters | BL-001, BL-002 |
| AC-004 | Distinct `user_login` users in a range equal the report's users with Number logins above 0 | BL-004 |

## Notes

Logins exist only since `user_login_attempts` was introduced (Tamanu migration `1757268197134`).

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-08 | Maui team | Initial draft |
