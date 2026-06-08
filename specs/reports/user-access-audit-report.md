# dbt Model Spec: `user-access-audit-report`

## Identity

| Field | Value |
|---|---|
| **Name** | `user-access-audit-report` (and supporting `ds__user_access_audit`) |
| **Type** | dbt model (Tamanu report + supporting dataset) |
| **Layer** | `report` (built on `ds__`) |
| **Materialisation** | `view` |
| **Status** | `review` |
| **Owner** | @julianam-w |
| **Linear issue** | [MAUI-6642](https://linear.app/bes/issue/MAUI-6642/create-new-user-management-audit-report-for-palau-team) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-08 |
| **Last updated** | 2026-06-08 |

## Purpose

**Why does this model exist?** The Palau MoH requires a periodic government audit of who has access to Tamanu and what each user can do. Existing reports are encounter-focused and do not list users, designations, emails, or permission sets in a single view.

**Who consumes it?** Palau MoH auditors (external); Tamanu system administrators reviewing access.

**Business context:** Palau Tamanu deployment; government information-security audit obligation.

## Grain

**One row per:** user (filtered to currently visible users).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('users') }}` | User identity, email, role assignment |
| `{{ ref('roles') }}` | Role names; parameter lookup |
| `{{ ref('user_designations') }}` | Designation assignments per user |
| `{{ ref('reference_data') }}` | Designation labels (`reference_data.name`) |
| `{{ ref('permissions') }}` | Role-scoped verb/noun permissions |

### Required input columns

| Upstream | Columns used |
|---|---|
| `users` | `id`, `display_id`, `display_name`, `email`, `role`, `visibility_status` |
| `roles` | `id`, `name` |
| `user_designations` | `user_id`, `designation_id`, `deleted_at` |
| `reference_data` | `id`, `name` |
| `permissions` | `role_id`, `verb`, `noun`, `deleted_at` |

### Freshness expectations

Bases refreshed within 24 hours. Audit cadence is monthly or on-demand; intra-day freshness is not required.

## Output schema

| Column | Type | Description | Tests |
|---|---|---|---|
| `user_id` | varchar | User PK (dataset only; not exposed in report) | `not_null`, `unique` |
| `user_display_id` | varchar | Human-readable user identifier | `not_null` |
| `user_name` | varchar | User display name; report sort key | `not_null` |
| `user_email` | varchar | User email (PII) | |
| `user_role_id` | varchar | Role FK (`users.role`); used by the report parameter filter | |
| `user_role` | varchar | Role name assigned to the user | |
| `user_designations` | text | Comma-separated designation labels, alphabetically sorted | |
| `role_permissions` | text | Comma-separated `verb:noun` permissions for the user's role, alphabetically sorted | |
| `visibility_status` | varchar | User visibility flag (dataset only; report pre-filters) | |

## Business logic

- **BL-001:** Include only users with `visibility_status = 'current'`. Decommissioned and inactive accounts are out of scope; this is a snapshot of active access, not a historical access log.
- **BL-002:** Exclude soft-deleted users (`users.deleted_at is null`); handled by `base__users`.
- **BL-003:** Aggregate designations per user as a comma-separated list, alphabetically sorted, deduplicated.
- **BL-004:** Exclude soft-deleted designation links (`user_designations.deleted_at is null`).
- **BL-005:** Resolve designation labels via `reference_data.name` joined on `designation_id`.
- **BL-006:** Aggregate permissions per role as `verb:noun` tokens joined by `, `, alphabetically sorted, deduplicated.
- **BL-007:** Exclude soft-deleted permissions (`permissions.deleted_at is null`).
- **BL-008:** Permissions are role-scoped — Tamanu's permission model has no user-level overrides, so two users with the same role share `role_permissions`.
- **BL-009:** Report output is sorted by `user_name` ascending.
- **BL-010:** Optional `roleId` parameter restricts output to users whose `users.role = roleId`; when null, no filter is applied.
- **BL-011:** Role filtering matches on `roles.id`, not `roles.name`, so the filter survives role renames.
- **BL-012:** The report has no sensitive variant. All users — including those associated with sensitive facilities — appear in the single audit output.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `user_id` is `not_null` and `unique` in `ds__user_access_audit` | grain | dbt schema test |
| AC-002 | Every `user_id` exists in `base__users` | BL-002 | dbt `relationships` |
| AC-003 | No rows in the dataset have `visibility_status != 'current'` | BL-001 | dbt singular test |
| AC-004 | When the report is run with a `roleId` parameter, every returned row has `users.role = roleId` | BL-010, BL-011 | manual / integration |
| AC-005 | If `role_permissions` is `null`, the user's role has no rows in `base__permissions` (i.e. the aggregation didn't silently drop a role with permissions) | BL-008 | dbt singular test |
| AC-006 | Every non-null `role_permissions` value matches `^[a-z][a-zA-Z0-9_-]*:[A-Z][a-zA-Z0-9_-]*(, [a-z][a-zA-Z0-9_-]*:[A-Z][a-zA-Z0-9_-]*)*$` (verb:Noun shape; permissive on content) | BL-006 | dbt singular test |
| AC-007 | Every non-null `user_designations` value is alphabetically sorted with no duplicate substrings | BL-003 | dbt singular test |

## Lineage

```
source('tamanu', 'users')             ──► base__users
source('tamanu', 'user_designations') ──► base__user_designations
source('tamanu', 'permissions')       ──► base__permissions
source('tamanu', 'roles')             ──► base__roles
source('tamanu', 'reference_data')    ──► base__reference_data
                                            │
                                            └──► ds__user_access_audit ──► user-access-audit-report
```

## Open questions

_None outstanding._

## Divergence from current code

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-06-08 | @julianam-w | Initial retrospective draft (MAUI-6642) |
