# Add-Customer for Reception / Sales Mobile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the existing mobile "Add customer" button only to users whose role is `RECEPTION` or `SALES_MOBILE`, and remove the superseded Call Center role spec.

**Architecture:** Pure role-matching logic lives in a new `lib/services/roles.dart` (unit-tested, no I/O). `AuthService` persists the roles the backend already returns at login and exposes `getRoles()` / `canAddCustomer()`, with a one-time `/api/mobile/me` fallback for sessions that predate this change. `CustomersScreen` loads the flag in `initState` and renders the button conditionally.

**Tech Stack:** Flutter / Dart, `shared_preferences` (already a dependency), `flutter_test` (unit tests only).

## Global Constraints

- Flutter SDK is **not on PATH**. It lives at `/home/frappe/.flutter-sdk/bin/flutter`. Start every shell session with:
  `export PATH="$HOME/.flutter-sdk/bin:$PATH"`
- No new dependencies. Use only `flutter_test` + `shared_preferences`'s built-in `setMockInitialValues`.
- Target roles: `RECEPTION` and `SALES_MOBILE`, compared **case-insensitively**.
- Backend field: role(s) arrive as `user['roles']` (a JSON list); legacy single `user['role']` is the fallback. Never assume a single string.
- Follow existing code style: `const` where possible, Arabic UI strings unchanged, 2-space indent.
- **Out-of-repo dependency (do not attempt here):** the `real-estate-app` backend must grant `customers: create` to `RECEPTION` and `SALES_MOBILE`. Until it does, the button appears but the `POST` 403s — that is expected and handled by the existing toast.

---

## Task 1: Pure role logic module

**Files:**
- Create: `lib/services/roles.dart`
- Test: `test/services/roles_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `const Set<String> kAddCustomerRoles`
  - `List<String> extractRoles(Map? user)` — coerces a login/`me` user object to a role list.
  - `bool canAddCustomerFromRoles(Iterable<String> roles)` — case-insensitive membership test.

- [ ] **Step 1: Write the failing test**

Create `test/services/roles_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sar_app/services/roles.dart';

void main() {
  group('extractRoles', () {
    test('reads the roles list', () {
      expect(extractRoles({'roles': ['RECEPTION', 'ADMIN']}),
          ['RECEPTION', 'ADMIN']);
    });
    test('falls back to a single role', () {
      expect(extractRoles({'role': 'SALES_MOBILE'}), ['SALES_MOBILE']);
    });
    test('returns empty when neither field is present', () {
      expect(extractRoles({'name': 'x'}), isEmpty);
    });
    test('returns empty for null', () {
      expect(extractRoles(null), isEmpty);
    });
  });

  group('canAddCustomerFromRoles', () {
    test('true for RECEPTION', () {
      expect(canAddCustomerFromRoles(['RECEPTION']), isTrue);
    });
    test('true when SALES_MOBILE is among several roles', () {
      expect(canAddCustomerFromRoles(['ADMIN', 'SALES_MOBILE']), isTrue);
    });
    test('is case-insensitive', () {
      expect(canAddCustomerFromRoles(['sales_mobile']), isTrue);
    });
    test('false for unrelated roles', () {
      expect(canAddCustomerFromRoles(['ADMIN', 'HR']), isFalse);
    });
    test('false for an empty list', () {
      expect(canAddCustomerFromRoles([]), isFalse);
    });
  });
}
```

- [ ] **Step 2: Ensure dependencies are resolved, then run the test to verify it fails**

Run:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter pub get
flutter test test/services/roles_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package 'sar_app/services/roles.dart'` (the file does not exist yet).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/services/roles.dart`:

```dart
/// Role identifiers (as the backend sends them) allowed to create customers.
/// Compared case-insensitively; add entries here to grant the button to more
/// roles.
const Set<String> kAddCustomerRoles = {'RECEPTION', 'SALES_MOBILE'};

/// Coerces the `user` object from a login or `/api/mobile/me` response into a
/// list of role strings. Prefers `user['roles']` (a list); falls back to the
/// legacy single `user['role']`; returns an empty list if neither is present.
List<String> extractRoles(Map? user) {
  if (user == null) return const [];
  final roles = user['roles'];
  if (roles is List) {
    return roles.map((r) => r.toString()).toList();
  }
  final role = user['role'];
  if (role is String && role.isNotEmpty) {
    return [role];
  }
  return const [];
}

/// True if any of [roles] is allowed to create customers (case-insensitive).
bool canAddCustomerFromRoles(Iterable<String> roles) {
  return roles.any((r) => kAddCustomerRoles.contains(r.toUpperCase()));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter test test/services/roles_test.dart
```
Expected: PASS — all 9 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/services/roles.dart test/services/roles_test.dart
git commit -m "$(cat <<'EOF'
feat: add pure role-matching helpers for add-customer gating

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Persist and expose roles in AuthService

**Files:**
- Modify: `lib/services/auth_service.dart`
- Test: `test/services/auth_service_roles_test.dart`

**Interfaces:**
- Consumes: `extractRoles`, `canAddCustomerFromRoles` from `lib/services/roles.dart` (Task 1).
- Produces:
  - `AuthService.getRoles()` → `Future<List<String>>` (prefs-first, one-time `/me` fallback).
  - `AuthService.canAddCustomer()` → `Future<bool>`.
  - `login` now persists prefs key `user_roles` (JSON-encoded `List<String>`); `logout` and `deleteAccount` remove it.

- [ ] **Step 1: Write the failing test**

Create `test/services/auth_service_roles_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sar_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getRoles returns persisted roles without any network call', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['SALES_MOBILE', 'ADMIN']),
    });
    expect(await AuthService.getRoles(), ['SALES_MOBILE', 'ADMIN']);
  });

  test('canAddCustomer is true for a persisted allowed role', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['RECEPTION']),
    });
    expect(await AuthService.canAddCustomer(), isTrue);
  });

  test('canAddCustomer is false for a persisted disallowed role', () async {
    SharedPreferences.setMockInitialValues({
      'user_roles': jsonEncode(['ADMIN']),
    });
    expect(await AuthService.canAddCustomer(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter test test/services/auth_service_roles_test.dart
```
Expected: FAIL — `The method 'getRoles' isn't defined for the type 'AuthService'`.

- [ ] **Step 3: Add the imports**

At the top of `lib/services/auth_service.dart`, replace:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
```

with:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'roles.dart';
```

- [ ] **Step 4: Persist roles on login**

In `lib/services/auth_service.dart`, inside `login`, immediately after the line:

```dart
    await prefs.setString('employee_id', employee?['employeeCode'] ?? '');
```

add:

```dart
    await prefs.setString('user_roles', jsonEncode(extractRoles(user)));
```

(`user` is the existing `data['user'] as Map?` local — `extractRoles` accepts `Map?`.)

- [ ] **Step 5: Clear roles on logout and account deletion**

In `deleteAccount`, after:

```dart
    await prefs.remove('employee_id');
```

add:

```dart
    await prefs.remove('user_roles');
```

In `logout`, after its own:

```dart
    await prefs.remove('employee_id');
```

add:

```dart
    await prefs.remove('user_roles');
```

- [ ] **Step 6: Add the accessors**

In `lib/services/auth_service.dart`, add these two methods inside the `AuthService` class (e.g. after `getEmployeeId`):

```dart
  /// Roles for the current user. Reads the persisted list first; if none was
  /// stored (a session that predates role persistence), fetches `/api/mobile/me`
  /// once, persists, and returns. Returns an empty list on any failure.
  static Future<List<String>> getRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_roles');
    if (stored != null && stored.isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is List) return decoded.map((r) => r.toString()).toList();
    }
    try {
      final data = await ApiService.getJson('/api/mobile/me');
      final user = (data is Map ? data['user'] as Map? : null);
      final roles = extractRoles(user);
      await prefs.setString('user_roles', jsonEncode(roles));
      return roles;
    } catch (_) {
      return const [];
    }
  }

  /// Whether the current user may create customers (Reception / Sales Mobile).
  static Future<bool> canAddCustomer() async {
    return canAddCustomerFromRoles(await getRoles());
  }
```

- [ ] **Step 7: Run the test to verify it passes**

Run:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter test test/services/auth_service_roles_test.dart
```
Expected: PASS — all 3 tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/services/auth_service.dart test/services/auth_service_roles_test.dart
git commit -m "$(cat <<'EOF'
feat: persist and expose user roles in AuthService

Store roles from the login response and expose getRoles()/canAddCustomer(),
with a one-time /me fallback for pre-existing sessions.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Gate the Add-customer button

**Files:**
- Modify: `lib/screens/customers.dart`

**Interfaces:**
- Consumes: `AuthService.canAddCustomer()` (Task 2).
- Produces: nothing consumed by later tasks.

This task has no automated test — a widget test of `CustomersScreen` would require mocking the customers HTTP call (`initState` → `_loadData`), and no HTTP-mock dependency exists. The gating decision itself is already covered by Task 1/Task 2 unit tests. Verify with `flutter analyze` plus the manual steps below.

- [ ] **Step 1: Add the AuthService import**

At the top of `lib/screens/customers.dart`, after:

```dart
import '../services/api_service.dart';
```

add:

```dart
import '../services/auth_service.dart';
```

- [ ] **Step 2: Add the state field**

In `_CustomersScreenState`, after:

```dart
  String _search = '';
```

add:

```dart
  bool _canAddCustomer = false;
```

- [ ] **Step 3: Load the role flag in initState**

Change `initState` from:

```dart
  @override
  void initState() {
    super.initState();
    _loadData();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _loadData();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final canAdd = await AuthService.canAddCustomer();
    if (mounted) setState(() => _canAddCustomer = canAdd);
  }
```

- [ ] **Step 4: Make the button conditional**

In `build`, inside the header `Row`, wrap the button so only it is conditional. Change:

```dart
                      Material(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _openAddCustomer,
```

to:

```dart
                      if (_canAddCustomer)
                        Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _openAddCustomer,
```

Then re-indent the remaining lines of that `Material(...)` widget (its `child` `Padding`, the inner `Row`, and the closing `),`) by two spaces to match the added `if` nesting, so the widget tree still closes correctly. After editing, confirm the block is balanced with the analyzer in Step 5.

- [ ] **Step 5: Analyze**

Run:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter analyze lib/screens/customers.dart lib/services/auth_service.dart lib/services/roles.dart
```
Expected: `No issues found!`

- [ ] **Step 6: Manual verification**

Build/run against a backend that returns roles (`flutter run --dart-define=API_BASE_URL=...`) and confirm:
- Login as a `RECEPTION` or `SALES_MOBILE` user → Customers tab shows "إضافة عميل"; tapping it opens the form; saving adds the customer to the list.
- Login as any other role → the "إضافة عميل" button is absent; the rest of the screen is unchanged.
- (Upgrade path) With a session that predates this change, opening Customers still resolves the flag via `/me`.

If a live backend is unavailable, note that automated unit coverage (Tasks 1–2) plus a clean `flutter analyze` is the completion bar, and record that the end-to-end step is pending a backend.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/customers.dart
git commit -m "$(cat <<'EOF'
feat: show add-customer button only for Reception/Sales Mobile roles

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Remove the superseded Call Center spec

**Files:**
- Delete: `docs/superpowers/specs/2026-07-08-call-center-role-design.md`

**Interfaces:**
- Consumes: nothing. Produces: nothing.

- [ ] **Step 1: Delete the old spec**

Run:
```bash
git rm docs/superpowers/specs/2026-07-08-call-center-role-design.md
```
Expected: `rm 'docs/superpowers/specs/2026-07-08-call-center-role-design.md'`.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
docs: remove superseded Call Center role spec

Replaced by add-customer-reception-sales-mobile: the capability moves to the
existing RECEPTION and SALES_MOBILE roles instead of a new CALL_CENTER role.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Final check

- [ ] Run the full unit suite:
```bash
export PATH="$HOME/.flutter-sdk/bin:$PATH"
flutter test
```
Expected: the existing `App renders` test plus the new `roles`/`auth_service` tests all pass.
