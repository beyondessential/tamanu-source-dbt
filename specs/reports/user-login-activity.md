# dbt Model Spec: `user-login-activity`

## Identity

| Field | Value |
|---|---|
| **Name** | `user-login-activity` |
| **Type** | dbt model (Tamanu report) |
| **Layer** | `report` (built directly on bases) |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6980](https://linear.app/bes/issue/MAUI-6980/tupaia-user-login-activity) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-10-08 |
| **Last updated** | 2026-10-08 |

## Purpose

Shows which activated users are, and are not, using Tamanu, so administrators can follow up on idle accounts. Consumed through the Tamanu reports interface. Its counts agree with `metric__user_login`.

## Grain

One row per activated, non-system user.

## Inputs

| Reference | Columns used |
|---|---|
| `users` | `id`, `display_id`, `display_name`, `role`, `visibility_status` |
| `roles` | `id`, `name` |
| `user_designations`, `reference_data` | designation links and names |
| `user_facilities`, `facilities` | allowed facility links and names |
| `user_login_attempts` | `user_id`, `created_at`, `outcome` |

## Output

User ID (`display_id`), User name, User role, Designations, Allowed facilities, Last log in date, Number logins.

## Parameters

Facility, role, designation, date range.

## Business logic

- **BL-001:** Soft-deleted rows are excluded by the bases.
- **BL-002:** Activated users only: `visibility_status = 'current'`.
- **BL-003:** The Tamanu system user (`00000000-0000-0000-0000-000000000000`) is excluded. Any other exclusion, such as super admins, is not made here.
- **BL-004:** A login is a `user_login_attempts` row with `outcome = 'succeeded'`.
- **BL-005:** Number logins counts logins dated within the date range, in the user-selected timezone. A user with none shows 0.
- **BL-006:** Last log in date is the latest login over all time, not limited to the date range. Blank if the user has never logged in.
- **BL-007:** The facility filter keeps users allowed at that facility. The Allowed facilities column still lists all of the user's facilities.
- **BL-008:** The role and designation filters match the user's role or any of their designations. The Designations column still lists all of them, comma-separated.
- **BL-009:** The date range sets only Number logins. It does not filter users.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | No system or non-current user appears | BL-002, BL-003 |
| AC-002 | One row per user despite several designations or facilities | grain |
| AC-003 | A user with no login shows a blank last login and 0 logins | BL-005, BL-006 |
| AC-004 | Changing the date range changes Number logins but not the list of users | BL-009 |
| AC-005 | Each filter narrows the rows as described | BL-007, BL-008 |
| AC-006 | Counts per designation agree with `metric__user_login` for the same range | BL-002 |

## Notes

- `user_login_attempts` has been recorded only since it was introduced (Tamanu migration `1757268197134`), so earlier logins are not visible and those users show as never logged in.
- A user with no allowed facility, or no designation, still appears, with a blank cell.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-08 | Maui team | Initial draft |
