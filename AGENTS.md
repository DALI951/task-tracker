# AGENTS.md — Task Tracker

## Project Overview
Two Flutter apps in a monorepo:
- **Manager app** (root `./`) — create/manage employees, assign tasks, review completions, view reported problems
- **Employee app** (`employee/`) — sign in, view/claim/complete tasks, report problems, settings (theme/language)

---

## Current Architecture

### State Management
- `ChangeNotifier` + `Provider` (no Riverpod/Bloc)
- `TaskProvider` in manager app handles tasks, employees, preset items, problems
- `EmployeeState` in employee app handles tasks + problem reporting

### Firebase Auth
- Client-side only (Spark plan). **No Cloud Functions deployed**.
- `createUserWithEmailAndPassword` signs in as the **new** user. After creating an employee, the manager app re-authenticates the manager from stored credentials.
- `SessionService` stores manager email/password in `shared_preferences`. On manager re-auth, the app reads email from `FirebaseAuth.instance.currentUser?.email` and prompts for password once per session (`_ensureManagerPass`).
- `UserService.ensureManager()` creates `users/{uid}` with `role: 'manager'` on every sign-in (required for Firestore rules).

### Firestore Collections
| Collection | Read | Write | Notes |
|---|---|---|---|
| `users/{uid}` | owner | owner | Role storage (`manager` / `employee`) |
| `tasks/{id}` | manager + assigned employee | manager | Employees can update status/photo |
| `problems/{id}` | any auth'd user | any auth'd user create; manager update | Employees report, managers convert to tasks |
| `employees/{email}` | manager only | manager only | Employee directory |
| `preset_tasks/{id}` | any auth'd user | manager only | Task templates |
| `preset_items/{id}` | any auth'd user | manager only | Item templates |

### Pull-to-Refresh
- Manager tasks tab: `RefreshIndicator` in `manager_dashboard.dart`
- Problems screen: `RefreshIndicator` in `problems_screen.dart`
- Employee tasks: `RefreshIndicator` in `employee/lib/screens/home_screen.dart`
- All refresh handlers re-subscribe to the Firestore stream.

### Filters
- Employee tasks: status filter dropdown (All / Pending / In Progress / Pending Review / Completed)
- Problems: status filter dropdown (Open / All / Assigned / Resolved)

### Key Files

#### Manager App
| File | Purpose |
|---|---|
| `lib/main.dart` | Entry point, providers, auth gate |
| `lib/screens/manager_dashboard.dart` | Main screen with tasks + problems tabs |
| `lib/screens/manage_employees_screen.dart` | CRUD employees |
| `lib/screens/problems_screen.dart` | View/convert problems |
| `lib/screens/settings_screen.dart` | Theme, language |
| `lib/providers/task_provider.dart` | All state management |
| `lib/services/firestore_service.dart` | Firestore CRUD |
| `lib/services/session_service.dart` | Manager credential storage |
| `lib/services/settings_service.dart` | Theme/language prefs |
| `lib/services/user_service.dart` | Role management |

#### Employee App (`employee/`)
| File | Purpose |
|---|---|
| `lib/main.dart` | Entry point, EmployeeState, auth gate |
| `lib/screens/home_screen.dart` | Task list + claim/complete |
| `lib/screens/report_problem_screen.dart` | Report a problem with photo |
| `lib/screens/settings_screen.dart` | Theme, language, sign out |
| `lib/services/firestore_service.dart` | Firestore CRUD |
| `lib/services/settings_service.dart` | Theme/language prefs |

### App Icons
- Manager: default Flutter icon
- Employee: custom blue icon with white "E" (generated via `flutter_launcher_icons` from `employee/assets/icon.png`)

---

## Build & Release

```powershell
# Manager app
cd C:\Users\Dali\Documents\Projects\task_tracker
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk

# Employee app
cd C:\Users\Dali\Documents\Projects\task_tracker\employee
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk

# Copy to releases/ with versioned names
Copy-Item ...\app-release.apk ...\releases\task-tracker-manager-v{version}.apk
Copy-Item ...\app-release.apk ...\releases\task-tracker-employee-v{version}.apk
```

---

## Known Issues
- **Delete Employee** removes Firestore doc but does NOT delete the Firebase Auth user (would need Admin SDK).
- **Password reset** requires stored password to be current. Falls back to `sendPasswordResetEmail`.
- **Manager APK** exceeds GitHub's recommended 50MB (actual ~55MB) — works fine but shows a warning.

## Recent Fixes

### v1.2.0 fixes
- **Status filter** — added dropdown to employee app to filter tasks by status.
- **Replace "Claim Task" with "Start Task"** — tasks are pre-assigned, no claiming needed.
- **Photo compression** — `maxWidth: 1024, maxHeight: 1024, imageQuality: 70` to keep base64 under Firestore's 1MB limit.
- **Stream subscription leak** — `listenToTasks` now cancels previous subscription before creating new one.
- **Optimistic UI updates** — local state updates instantly without waiting for Firestore stream.

---

## Future Improvements
1. Deploy Cloud Functions (requires Blaze plan) to eliminate client-side re-auth
2. Add push notifications for new task assignments
3. Add offline support (Firestore persistence)
4. Add multi-language support beyond en/fr/ar
