# AGENTS.md — Task Tracker

## Project Overview
Single unified Flutter app with role-based UI:
- **Manager** — create/manage employees, assign tasks, review completions, view reported problems
- **Employee** — view assigned tasks, start/complete with photo proof, report problems

Account creation is done via `web_admin/index.html` (not in-app).

---

## Architecture

### State Management
- `ChangeNotifier` + `Provider`
- `TaskProvider` handles tasks, employees, preset items, problems

### Firebase Auth
- Client-side only (Spark plan). **No Cloud Functions deployed**.
- `createUserWithEmailAndPassword` signs in as the **new** user. After creating an employee, the manager app re-authenticates the manager from stored credentials.
- `SessionService` stores manager email/password in `shared_preferences`. On manager re-auth, the app reads email from `FirebaseAuth.instance.currentUser?.email` and prompts for password once per session (`_ensureManagerPass`).
- `UserService.ensureManager()` creates `users/{uid}` with `role: 'manager'` on every sign-in (required for Firestore rules).
- **No sign-up in app.** Accounts are created via `web_admin/index.html` or Firebase Console.

### Auto-Update
- `UpdateService` checks GitHub Releases API on app startup (after 2s delay)
- Compares installed version (via `package_info_plus`) with latest release tag
- Shows `UpdateModal` with changelog + 3 options: Install Now / Later / Never for this version
- "Later" retries after 10 minutes, only when on home screen (ManagerDashboard or EmployeeTasksScreen)
- "Never" saves dismissed version to SharedPreferences; can manually check from Settings
- Settings has "Check for Updates" button that forces a check (bypasses dismiss)
- Downloads APK via `dio`, opens via `open_file` (triggers Android installer)

### Firestore Collections
| Collection | Read | Write | Notes |
|---|---|---|---|
| `users/{uid}` | owner | owner | Role storage (`manager` / `employee`) |
| `tasks/{id}` | manager + assigned employee | manager | Employees can update status/photo |
| `problems/{id}` | any auth'd user | any auth'd user create; manager update | Employees report, managers convert to tasks |
| `employees/{email}` | manager only | manager only | Employee directory |
| `preset_tasks/{id}` | any auth'd user | manager only | Task templates |
| `preset_items/{id}` | any auth'd user | manager only | Item templates |

### Key Files

| File | Purpose |
|---|---|
| `lib/main.dart` | Entry point, providers, auth gate, update check |
| `lib/screens/login_screen.dart` | Sign-in only (no sign-up) |
| `lib/screens/manager_dashboard.dart` | Manager UI: tasks + problems tabs, create task |
| `lib/screens/employee_tasks_screen.dart` | Employee UI: task list, start/complete |
| `lib/screens/task_detail_screen.dart` | Task detail (shared, `isManager` flag) |
| `lib/screens/manage_employees_screen.dart` | CRUD employees |
| `lib/screens/problems_screen.dart` | View/convert problems |
| `lib/screens/settings_screen.dart` | Theme, language, check for updates |
| `lib/screens/update_modal.dart` | Update prompt modal |
| `lib/services/update_service.dart` | GitHub API check, download, install |
| `lib/providers/task_provider.dart` | All state management |
| `lib/services/firestore_service.dart` | Firestore CRUD |
| `lib/services/session_service.dart` | Manager credential storage |
| `lib/services/settings_service.dart` | Theme/language prefs + i18n |
| `lib/services/user_service.dart` | Role management |
| `web_admin/index.html` | Account creation website |

### App Icon
- Custom app icon generated via `flutter_launcher_icons` from `assets/app_icon.png`

---

## Build & Release

### Local Build
```powershell
cd C:\Users\Dali\Documents\Projects\task_tracker
flutter pub get
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk
```

### CI/CD (GitHub Actions)
- Push to `master` triggers `.github/workflows/build.yml`
- Extracts version from `pubspec.yaml`
- Builds release APK
- Creates GitHub release with `Task-Tracker-v{version}.apk`
- Release URL: `https://github.com/DALI951/task-tracker/releases`

### To trigger a release:
1. Update `version:` in `pubspec.yaml`
2. Push to `master`
3. GitHub Actions builds and creates a release with the APK

---

## Account Creation

Use `web_admin/index.html`:
1. Open in browser
2. Enter admin passphrase: `tasktracker2024`
3. Fill: email, password, display name, role (manager/employee)
4. Click "Create Account"

Creates Firebase Auth user + Firestore `users/{uid}` doc with role.

---

## Known Issues
- **Delete Employee** removes Firestore doc but does NOT delete the Firebase Auth user (would need Admin SDK).
- **Password reset** requires stored password to be current. Falls back to `sendPasswordResetEmail`.
- **Manager APK** exceeds GitHub's recommended 50MB — works fine but shows a warning.
- **APK install** requires "Install Unknown Apps" permission on Android (granted once by user).
