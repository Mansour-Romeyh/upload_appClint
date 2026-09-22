# Add-Customer for Reception / Sales Mobile — Design

Date: 2026-07-08
Scope: `sar_app` (Flutter mobile app)
Supersedes: `2026-07-08-call-center-role-design.md` (removed — see below)

## Goal

Let mobile users whose role is **Reception** (`RECEPTION`) or **Sales Mobile**
(`SALES_MOBILE`) create new customers from the app. Drop the previously-planned
dedicated `CALL_CENTER` role entirely; the add-customer capability belongs to
these existing roles instead.

## Context

- The app already has an **Add-customer feature built** in
  `lib/screens/customers.dart` (uncommitted working-tree change): an "إضافة
  عميل" button in the Customers header and a `CustomerFormScreen` that `POST`s
  to `/api/mobile/customers`. It is currently shown to **every** user, ungated.
- The app has **no concept of roles today**. `lib/services/auth_service.dart`
  persists `user_id`, `user_email`, `full_name`, `employee_id` — but no role.
  `lib/app_shell.dart` shows the same full 6-tab nav to everyone.
- The **backend already returns the user's role(s)** in both the login response
  and `/api/mobile/me` (confirmed with the product owner). The field is
  `user.roles` — a JSON **array** (a user may hold several roles) — with legacy
  single-value `user.role` as a fallback.
- The only "Call Center" artifact in this repo is the design spec
  `2026-07-08-call-center-role-design.md`; **no `CALL_CENTER` code was ever
  added here**. Roles and permissions live in the separate `real-estate-app`
  backend.

## Approach

Gate the existing Add-customer button on the user's role, read app-side. Persist
roles at login, read them from `SharedPreferences`, and fall back to a one-time
`/api/mobile/me` fetch for users who were already logged in before this update
ships. All role logic lives behind a single `AuthService` method.

## Flutter changes (`sar_app`)

### 1. `lib/services/auth_service.dart` — store and expose roles

- **On `login`**: persist `roles` to prefs under key `user_roles` as a
  JSON-encoded `List<String>`. Coerce from the login response: use
  `user['roles']` if present (a list), else `[user['role']]` if a single role
  string is present, else `[]`.
- **In `logout` and `deleteAccount`**: `prefs.remove('user_roles')`.
- **New `getRoles()` → `Future<List<String>>`**:
  - Read `user_roles` from prefs; if non-empty, decode and return it.
  - Otherwise (upgrade case), fetch `/api/mobile/me`, extract roles with the
    same coercion (`user['roles']` → list, fallback `[user['role']]`), persist
    them under `user_roles`, and return. On any error, return `[]`.
- **New `canAddCustomer()` → `Future<bool>`**: true iff `getRoles()` contains
  `RECEPTION` or `SALES_MOBILE`, compared **case-insensitively**. The target
  roles are defined as a private constant set so it is easy to extend later.

### 2. `lib/screens/customers.dart` — gate the button

- Add a `bool _canAddCustomer = false;` field.
- In `initState`, call a `_loadRole()` helper that awaits
  `AuthService.canAddCustomer()` and, if `mounted`, `setState`s the flag.
- Make **only the "إضافة عميل" button** conditional on `_canAddCustomer`; the
  header `Row`/title stay as they are. When the flag is false the button is
  omitted, leaving the title occupying the header (visually the same as before
  the feature).
- **No change** to `CustomerFormScreen`, the form fields, validation, or the
  `POST /api/mobile/customers` call — they are role-agnostic and stay as built.

### 3. Remove the Call Center role

- Delete `docs/superpowers/specs/2026-07-08-call-center-role-design.md`. It is
  the only Call Center artifact in this repo and is fully superseded by this
  spec.

## Out of scope / dependency (not this repo)

- **Backend (`real-estate-app`)** must grant the `create` action on `customers`
  to the `RECEPTION` and `SALES_MOBILE` roles in its RBAC matrix, and must keep
  returning `roles` in the login and `/me` responses. This is a separate repo
  and is **not** modified here; it is a hard dependency for the feature to work
  end to end (the button appears, but the `POST` 403s until the backend grants
  the permission).
- No new role is created. No `CALL_CENTER` anywhere.
- No role-based changes to navigation or any other screen — only the
  Add-customer button is gated. The full 6-tab nav is unchanged.
- No update/delete of customers from mobile.

## Verification

- **Reception / Sales Mobile user**: log in → open Customers → the "إضافة عميل"
  button is visible → add a customer → it appears in the list.
- **Any other role**: log in → open Customers → the button is **absent**; the
  rest of the screen is unchanged.
- **Already-logged-in user (upgrade path)**: without re-login, open Customers →
  `getRoles()` falls back to `/me`, persists roles, and the button visibility is
  correct.
- **Logout**: `user_roles` is cleared from prefs; a subsequent login for a
  different role recomputes visibility correctly.
