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

---

## Project Structure

```
task_tracker/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── brand.dart               # Colors, spacing constants
│   ├── screens/
│   │   ├── login_screen.dart         # Sign-in / sign-up
│   │   ├── home_screen.dart          # Main manager dashboard
│   │   ├── manage_employees_screen.dart  # Create/rename/delete/reset-password
│   │   ├── assign_tasks_screen.dart  # Assign preset items to employees
│   │   └── review_screen.dart        # Review completed tasks with photos
│   ├── providers/
│   │   └── task_provider.dart        # State management (ChangeNotifier)
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth wrapper
│   │   ├── auth_gate.dart            # Auth state listener → routes to login/dashboard
│   │   ├── session_service.dart      # Persists manager credentials (flutter_secure_storage)
│   │   ├── firestore_service.dart    # Firestore CRUD operations
│   │   ├── user_service.dart         # User role management
│   │   └── settings_service.dart     # Language, theme, remembered accounts
│   ├── utils/
│   │   ├── error_handler.dart        # Friendly error messages
│   │   └── connectivity.dart         # Online/offline detection
│   └── widgets/
│       ├── offline_banner.dart        # Shows "No internet" bar
│       ├── options_bottom_sheet.dart
│       ├── photo_preview_dialog.dart
│       ├── tab_indicator.dart
│       ├── task_card.dart
│       └── task_item.dart
├── functions/                        # Cloud Functions (optional, see below)
│   ├── package.json
│   └── index.js
├── firebase.json                     # Firebase project config
├── .firebaserc                       # Default project: task-tracker-6d7e1
├── firestore.rules                   # Firestore security rules
└── pubspec.yaml
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

3. **Assign Tasks** (`assign_tasks_screen.dart`):
   - Pick an employee, check preset items, optionally add custom text → creates `tasks/{taskId}` in Firestore.

4. **Review** (`review_screen.dart`):
   - View completed tasks with photos. Approve or reject with a reason.

### Employee App (`task_tracker_employee`)

Separate Flutter project. Employee logs in, sees assigned tasks, takes a photo as proof of completion, submits for review.

---

## Key Files to Understand

### Session Service (`lib/services/session_service.dart`)

Managers need to re-authenticate after employee creation (because Firebase `createUserWithEmailAndPassword` signs in as the **new** user). The session service persists the manager's email + password in `flutter_secure_storage` so re-auth happens automatically.

- `init()` — called in `main.dart` to load from disk
- `saveCredentials()` — called on login
- Getters `managerEmail` / `managerPassword` — synchronous (backed by in-memory cache)

### Manage Employees (`lib/screens/manage_employees_screen.dart`)

The most complex screen. Key methods:
- `_addEmployee()` — shows dialog → calls Firebase Auth → re-auth → writes Firestore
- `_resolveExistingAccount()` — handles email-already-in-use (Replace / Link)
- `_resetPassword()` — brief sign-in as employee → `updatePassword()` → sign back in
- `_getManagerCreds()` — reads from `SessionService()`

### Stream-based reactivity

`TaskProvider` listens to Firestore streams for tasks, employees, and preset items. Changes propagate automatically via `notifyListeners()`.

---

## Build & Run

```powershell
# Debug build
flutter build apk --debug
flutter install --debug

# Release build (requires signing key)
flutter build apk --release
```

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

1. Run `flutter pub get` in both `task_tracker` and `task_tracker_employee`
2. Build and install both apps: `flutter build apk --debug` + `flutter install --debug`
3. Sign in as manager, create an employee
4. Sign in as employee on the employee app
5. Assign a task from the manager app
6. Claim and complete it from the employee app (with photo)
7. Review it from the manager app
