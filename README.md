# Task Tracker

Enterprise task tracker with photo proof of completion. Two Flutter mobile apps:

- **Manager App** (`task_tracker`) — create/manage employees, assign tasks, review photo proof
- **Employee App** (`task_tracker_employee`) — sign in, view assigned tasks, claim & complete with photos

---

## Prerequisites

Install these **before** opening the project:

### 1. Flutter SDK

- Download: https://docs.flutter.dev/get-started/install
- Version: **3.24+** (Dart SDK `^3.5.0`)
- After installing, verify:

```powershell
flutter doctor
```

**Important:** Run `flutter doctor --android-licenses` and accept all licenses.

### 2. Android Studio (or IntelliJ with Flutter plugin)

- Download: https://developer.android.com/studio
- During setup, install:
  - Android SDK Platform 35
  - Android SDK Build-Tools 35+
  - Google USB Driver (for real device testing)
- Enable **Developer Mode** on your Windows PC (required for symlinks):
  ```powershell
  start ms-settings:developers
  ```
  Toggle **Developer Mode** ON.

### 3. Git

- Download: https://git-scm.com/downloads
- Verify: `git --version`

### 4. Firebase CLI (optional — only for Cloud Functions)

```powershell
npm install -g firebase-tools
firebase login
```

> **Note:** This project currently uses **client-side Firebase Auth** (free, Spark plan). Cloud Functions are prepared but not active. See [Cloud Functions](#cloud-functions) below.

---

## Setup

### 1. Clone

```powershell
git clone <repo-url>
cd task_tracker
```

### 2. Get dependencies

```powershell
flutter pub get
```

### 3. Open the project

```powershell
code .   # or: flutter open -a android-studio .
```

### 4. Run on a connected phone

```powershell
flutter run
```

Or build & install the debug APK:

```powershell
flutter build apk --debug
flutter install --debug
```

---

## Firebase Configuration

The project is already connected to Firebase project **`task-tracker-6d7e1`**.

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Web: `lib/firebase_options.dart`

**Firestore Security Rules** (`firestore.rules`):
- Only authenticated managers can read/write employees, preset tasks, preset items
- Employees can only read/update tasks assigned to their email
- Employees cannot delete anything

### If you need to create a new Firebase project:

1. Go to https://console.firebase.google.com
2. Add an Android app (package: `com.example.task_tracker`)
3. Download `google-services.json` → replace `android/app/google-services.json`
4. Replace `lib/firebase_options.dart` via `flutterfire configure`

## Releases

| Version | Manager APK | Employee APK | Changes |
|---------|------------|-------------|---------|
| v1.2.0 | [Download](releases/task-tracker-manager-v1.2.0.apk) | [Download](releases/task-tracker-employee-v1.2.0.apk) | Start Task replaces Claim Task; status filter; fix settings back button; photo compression; stream subscription fix |
| v1.1.0 | [Download](releases/task-tracker-manager-v1.1.0.apk) | [Download](releases/task-tracker-employee-v1.1.0.apk) | Pull-to-refresh on tasks & problems; settings screen; report problem feature; custom employee icon |
| v1.0.0 | [Download](releases/task-tracker-manager-v1.0.0.apk) | [Download](releases/task-tracker-employee-v1.0.0.apk) | Initial release |

---

## Project Structure

```
task_tracker/
├── lib/                          # Manager app source
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── brand.dart               # Colors, spacing constants
│   ├── screens/
│   │   ├── login_screen.dart         # Sign-in / sign-up
│   │   ├── manager_dashboard.dart    # Main manager dashboard (tasks + problems tabs)
│   │   ├── manage_employees_screen.dart  # Create/rename/delete/reset-password
│   │   ├── assign_tasks_screen.dart  # Assign preset items to employees
│   │   ├── problems_screen.dart      # View & convert reported problems
│   │   └── settings_screen.dart      # Language, theme
│   ├── providers/
│   │   └── task_provider.dart        # State management (ChangeNotifier)
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth wrapper
│   │   ├── auth_gate.dart            # Auth state listener → routes to login/dashboard
│   │   ├── session_service.dart      # Persists manager credentials (shared_preferences)
│   │   ├── firestore_service.dart    # Firestore CRUD operations
│   │   └── settings_service.dart     # Language, theme
│   ├── utils/
│   │   ├── error_handler.dart        # Friendly error messages
│   │   └── connectivity.dart         # Online/offline detection
│   └── widgets/
│       ├── offline_banner.dart        # Shows "No internet" bar
│       ├── options_bottom_sheet.dart
│       ├── photo_preview_dialog.dart
│       ├── task_card.dart
│       └── task_item.dart
├── employee/                      # Employee app (separate Flutter project)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── report_problem_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── services/
│   │       ├── firestore_service.dart
│   │       └── settings_service.dart
│   └── pubspec.yaml
├── functions/                        # Cloud Functions (optional, see below)
│   ├── package.json
│   └── index.js
├── releases/                         # Pre-built APKs
│   ├── task-tracker-manager-v1.1.0.apk
│   ├── task-tracker-manager-v1.0.0.apk
│   ├── task-tracker-employee-v1.1.0.apk
│   └── task-tracker-employee-v1.0.0.apk
├── firebase.json                     # Firebase project config
├── .firebaserc                       # Default project: task-tracker-6d7e1
├── firestore.rules                   # Firestore security rules
├── pubspec.yaml                      # Manager app dependencies
└── README.md
```

---

## How It Works

### Manager App

1. **Sign in** — manager signs in with email/password. Credentials are encrypted and stored via `flutter_secure_storage` for re-authentication (needed when briefly signing in as an employee for password resets or account linking).

2. **Manage Employees** (`manage_employees_screen.dart`):
   - **Create** — enter email, name, password. The app calls `createUserWithEmailAndPassword`, sets the `users/{uid}.role = 'employee'`, then re-authenticates as the manager using stored credentials. The employee document is written to `employees/{email}`.
   - **Email already in use** — dialog asks for the existing password, then either **Replace** (delete + recreate) or **Use Existing** (link the account).
   - **Rename** — updates `employees/{email}.name`.
   - **Delete** — removes `employees/{email}` doc (does NOT delete Firebase Auth user).
   - **Reset Password** — signs in briefly as the employee using the stored password, calls `updatePassword()`, signs back in as manager.

3. **Problems** (`problems_screen.dart`):
   - View reported problems with status filter (open / all / assigned / resolved)
   - Pull down to refresh the list
   - Convert open problems into tasks assigned to employees

4. **Settings** (`settings_screen.dart`):

### Employee App (`employee/`)

Separate Flutter project. Employee logs in, sees pre-assigned tasks, taps **Start Task** to begin working, takes a photo as proof of completion, submits for review. Pull down on the task list to refresh.

---

## Key Files to Understand

### Session Service (`lib/services/session_service.dart`)

Managers need to re-authenticate after employee creation (because Firebase `createUserWithEmailAndPassword` signs in as the **new** user). The session service persists the manager's email + password in `shared_preferences` so re-auth happens automatically.

- `init()` — called in `main.dart` to load from disk
- `saveCredentials()` — called on login
- Getters `managerEmail` / `managerPassword` — synchronous (backed by in-memory cache)

### Manage Employees (`lib/screens/manage_employees_screen.dart`)

The most complex screen. Key methods:
- `_addEmployee()` — shows dialog → calls Firebase Auth → re-auth → writes Firestore
- `_resolveExistingAccount()` — handles email-already-in-use (Replace / Link)
- `_resetPassword()` — brief sign-in as employee → `updatePassword()` → sign back in
- `_ensureManagerPass()` — caches manager's password in memory (prompted once per session)

### Stream-based reactivity

`TaskProvider` listens to Firestore streams for tasks, employees, and preset items. Changes propagate automatically via `notifyListeners()`.

### Pull-to-Refresh

Three screens have `RefreshIndicator`:
- **Manager tasks tab** — `manager_dashboard.dart` wraps task list
- **Problems screen** — `problems_screen.dart` wraps problem list
- **Employee tasks** — `employee/lib/screens/home_screen.dart` wraps task list

All re-subscribe to their Firestore stream on pull-down.

---

## Build & Run

```powershell
# Manager app (from root)
flutter build apk --release   # Output: build/app/outputs/flutter-apk/app-release.apk

# Employee app (from employee/)
cd employee
flutter build apk --release   # Output: build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
flutter install
```

Release APKs are copied to `releases/` with versioned names.

---

## Cloud Functions

Two callable functions are prepared in `functions/` but **not deployed** (they require Blaze plan):

- **`createEmployee`** — creates Firebase Auth user + Firestore docs atomically (Admin SDK)
- **`setEmployeePassword`** — changes employee password directly in Auth

To deploy (paid plan required):

```powershell
firebase deploy --only functions
```

After deployment, you can:
1. Remove `flutter_secure_storage` and `SessionService`
2. Replace `_addEmployee` / `_resetPassword` calls with `FirebaseFunctions.instance.httpsCallable(...)`
3. No more client-side re-auth needed

---

## Known Issues

- **Delete Employee** removes the Firestore doc but does NOT delete the Firebase Auth user (would require Cloud Functions or client-side admin re-auth).
- **Password Reset** requires that the stored password in `employees/{email}.storedPassword` is up to date. If the employee changed their password externally, the reset flow falls back to `sendPasswordResetEmail`.

---

## What to Do Next (for OpenCode / next developer)

After completing all setup steps above:

1. Run `flutter pub get` in both the root and `employee/` directories
2. Build and install both apps: `flutter build apk --release` then `flutter install`
3. Sign in as manager, create an employee
4. Sign in as employee on the employee app
5. Assign a task from the manager app
6. **Start Task** from the employee app, then take a photo and submit
7. Review and approve it from the manager app
8. File a problem report from the employee app, view it in the manager's problems tab
