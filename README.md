# Task Tracker

Enterprise task tracker with photo proof of completion. Single unified Flutter app with role-based UI for **Managers** and **Employees**.

## Overview

| | |
|---|---|
| **Version** | 0.2.2 |
| **Flutter** | 3.44.8+ |
| **Backend** | Firebase (Auth + Firestore + FCM) |
| **Platforms** | Android APK, Web (GitHub Pages), Windows Desktop |
| **Languages** | English, French, Arabic (RTL) |

---

## Features

- **Role-based UI** — Managers create/manage tasks; Employees view, claim, and complete with photo proof
- **Photo proof of completion** — Camera capture on Android, gallery on web/desktop
- **Task lifecycle** — Pending → In Progress → Pending Review → Approved/Rejected
- **Problem reporting** — Employees report problems; managers convert them to tasks
- **Push notifications** — FCM v1 via service account, per-type toggles, notification preferences
- **Auto-update** — Checks GitHub Releases on startup, downloads APK via in-app prompt
- **Preset templates** — Reusable task templates and item lists, scoped per manager
- **Multi-language** — EN/FR/AR with RTL support
- **Theme** — Light/dark mode, configurable accent color
- **Data isolation** — Each manager only sees their own tasks, employees, and presets

---

## Architecture

### State Management

`ChangeNotifier` + `Provider`. Single `TaskProvider` handles tasks, employees, presets, and problems.

### Project Structure

```
lib/
├── main.dart                    # Entry point, providers, auth gate, splash
├── config/
│   └── brand.dart               # Colors, radii, brand constants
├── models/
│   ├── task.dart                # AppTask + HistoryEvent
│   ├── problem.dart             # Problem model
│   ├── preset_task.dart         # PresetTask template
│   ├── preset_item.dart         # PresetItem template
│   └── app_notification.dart    # Notification model
├── providers/
│   └── task_provider.dart       # All state management
├── screens/
│   ├── login_screen.dart        # Sign-in (no in-app sign-up)
│   ├── manager_dashboard.dart   # Manager UI: tasks + problems tabs
│   ├── employee_tasks_screen.dart  # Employee UI: task list + search
│   ├── task_detail_screen.dart  # Task detail (shared, isManager flag)
│   ├── manage_employees_screen.dart  # Employee CRUD
│   ├── problems_screen.dart     # Problem list / convert to task
│   ├── report_problem_screen.dart  # Employee problem reporting
│   ├── settings_screen.dart     # Theme, language, presets, notifications
│   ├── notifications_screen.dart  # Notification list
│   ├── notification_preferences_screen.dart  # Per-type toggles
│   ├── preset_items_screen.dart  # Preset item management
│   └── update_modal.dart        # Update prompt modal
├── services/
│   ├── auth_gate.dart           # Auth routing based on role
│   ├── auth_service.dart        # Firebase Auth operations
│   ├── firestore_service.dart   # Firestore CRUD
│   ├── user_service.dart        # Role management
│   ├── session_service.dart     # Manager credential storage
│   ├── settings_service.dart    # Theme/language/i18n + all translations
│   ├── notification_service.dart  # Firestore notifications CRUD + FCM push
│   ├── push_notification_service.dart  # FCM token, foreground messages, local notifications
│   ├── fcm_sender.dart          # FCM v1 HTTP push via service account
│   ├── storage_service.dart     # Image encoding/storage
│   └── update_service.dart      # GitHub Releases auto-update
├── utils/
│   ├── connectivity.dart        # (removed)
│   ├── error_handler.dart       # Friendly error messages
│   └── toast.dart               # Toast utility
└── widgets/
    └── task_card.dart           # Reusable task card widget

web_admin/
├── index.html                   # Admin account creation page
└── moderator.html               # Moderator self-service page

firestore.rules                  # Firestore security rules
```

---

## Firebase Setup

### Project

- **Project ID**: `task-tracker-6d7e1`
- **Plan**: Spark (free) — no Cloud Functions
- **Config**: `lib/firebase_options.dart` (Android, iOS, Web)

### Firestore Collections

| Collection | Key Fields | Access |
|---|---|---|
| `users/{uid}` | `role`, `fcmToken`, `displayName` | Owner read/write; manager read |
| `tasks/{id}` | `title`, `status`, `assignedToEmail`, `createdBy`, `photoUrl`, `history[]` | Manager: own tasks; Employee: assigned tasks |
| `employees/{email}` | `email`, `name`, `createdBy` | Manager only (own employees) |
| `preset_tasks/{id}` | `name`, `defaultDescription`, `requireCarOrThing`, `createdBy` | Manager: own presets; Employee: read |
| `preset_items/{id}` | `name`, `createdBy` | Manager: own items; Employee: read |
| `problems/{id}` | `reportedBy`, `description`, `status`, `convertedToTaskId` | Any auth'd user create/read; Manager update/delete |
| `notifications/{notifId}` | `recipientEmail`, `type`, `title`, `message`, `read` | Recipient only |

### Firestore Rules

Security rules enforce data isolation:

- Tasks, employees, presets are scoped by `createdBy == userEmail()` for managers
- Employees can only read tasks assigned to their email
- Employees can only update limited fields on their assigned tasks (status, claimedBy, photoUrl, etc.)

See `firestore.rules` for the full ruleset.

---

## Account Creation

**No sign-up in the app.** Accounts are created via:

1. **Web Admin** — `https://dali951.github.io/task-tracker/admin/index.html`
   - Gated by admin passphrase: `tasktracker2024`
   - Creates Firebase Auth user + Firestore `users/{uid}` doc
   - Roles: Manager or Employee

2. **Moderator Page** — `https://dali951.github.io/task-tracker/admin/moderator.html`
   - Self-service for managers: sign up, log in, change password/display name

---

## App Behavior

### Auth Flow (`auth_gate.dart`)

1. No user → `LoginScreen`
2. User exists → resolve role from Firestore `users/{uid}.role`
3. Role cached in SharedPreferences (`role_{uid}`)
4. Manager → `ManagerDashboard`
5. Employee → `EmployeeTasksScreen`
6. No role found → auto-provision as employee

### Manager Flow

- Dashboard with Tasks + Problems tabs
- Create tasks (preset or custom), assign to employees
- Review pending completions: approve or reject with reason
- Manage employees, preset items, preset tasks
- View problems reported by employees

### Employee Flow

- Task list with search and filters (active/pending/in progress/completed)
- Claim task → start working → submit photo proof
- Report problems with optional photo
- Settings, notification preferences

### Task Lifecycle

```
pending → doing (employee claims)
       → pending_review (employee submits proof)
       → completed (manager approves)
       → doing (manager rejects, back to employee)
```

---

## Push Notifications

FCM v1 HTTP API via service account (`assets/service-account.json`).

- **Sending**: `fcm_sender.dart` authenticates with Google APIs, sends to FCM v1 endpoint
- **Receiving**: `push_notification_service.dart` handles foreground messages, local notifications
- **Token**: Stored in `users/{uid}.fcmToken`
- **Channel**: `task_tracker_channel` (created at startup on Android)
- **Permission**: `POST_NOTIFICATIONS` for Android 13+

### Notification Types

| Type | Trigger |
|---|---|
| `task_assigned` | Manager assigns task to employee |
| `task_started` | Employee claims/starts task |
| `task_submitted` | Employee submits proof for review |
| `task_approved` | Manager approves completed task |
| `task_rejected` | Manager rejects completed task |
| `task_status_changed` | Task status updated |
| `task_reassigned` | Task reassigned to different employee |
| `problem_reported` | Employee reports a problem |
| `problem_resolved` | Problem converted to task |

---

## Auto-Update

`UpdateService` checks GitHub Releases API on startup:

- Compares installed version with latest release tag
- Shows `UpdateModal` with changelog and 3 options: Install Now / Later / Never
- Downloads APK via `dio`, opens via `open_file` (triggers Android installer)
- Android-only (disabled on web/desktop via `kIsWeb` guard)

---

## Multi-Platform

| Platform | Features | Build |
|---|---|---|
| **Android** | Full (camera, auto-update, APK install, push notifications) | `flutter build apk --release` |
| **Web** | Gallery picker (no camera), deployed to GitHub Pages | `flutter build web --release` |
| **Windows** | Gallery picker, Inno Setup installer, "Open Web Version" button | `flutter build windows --release` |

---

## Build & Release

### Local Build

```powershell
cd C:\Users\Dali\Documents\Projects\task_tracker
flutter pub get

# Android APK
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk

# Web
flutter build web --release
# → build\web\

# Windows
flutter build windows --release
# → build\windows\x64\runner\Release\
```

### CI/CD (GitHub Actions)

Push to `master` triggers `.github/workflows/build.yml` with **4 parallel jobs**:

| Job | Output |
|---|---|
| `build-apk` | `Task-Tracker-v{ver}.apk` |
| `build-web` | `Task-Tracker-v{ver}-web.zip` (includes `web_admin/`) |
| `deploy-web` | Deploys to GitHub Pages |
| `create-release` | Creates GitHub Release with all artifacts |

### Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `SERVICE_ACCOUNT_JSON_BASE64` | Base64-encoded Firebase service account JSON (for FCM) |
| `ANDROID_KEYBASE64` | Base64-encoded release keystore (`release-key.jks`) |
| `ANDROID_KEY_PASSWORD` | Keystore password (`tasktracker123`) |
| `ANDROID_KEY_ALIAS` | Key alias (`task-tracker`) |

### Release Artifacts

| File | Platform | Usage |
|---|---|---|
| `Task-Tracker-v{ver}.apk` | Android | Sideload on phone |
| `Task-Tracker-v{ver}-web.zip` | Web | Unzip, open `index.html` |
| `Task-Tracker-v{ver}-Setup.exe` | Windows | Run installer |

---

## Android Config

| Field | Value |
|---|---|
| `applicationId` | `com.example.task_tracker` |
| `minSdk` | Flutter default |
| `compileSdk` | Flutter default |
| Java/Kotlin | VERSION_17 |
| Desugaring | Enabled (for `flutter_local_notifications`) |
| Signing | Release keystore via `android/key.properties` |

---

## Dependencies

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `firebase_messaging` | FCM token + foreground messages |
| `flutter_local_notifications` | Local notification display |
| `googleapis_auth` | Service account auth for FCM v1 |
| `provider` | State management |
| `image_picker` | Camera/gallery image capture |
| `dio` | HTTP client for auto-update download |
| `open_file` | Open downloaded APK |
| `package_info_plus` | Read installed version |
| `shared_preferences` | Local persistence |
| `permission_handler` | Runtime permissions |
| `url_launcher` | Open web version link |
| `intl` | Date formatting |
| `http` | HTTP requests (FCM sender) |
| `path_provider` | File system paths |

---

## I18n

Translations are in `lib/services/settings_service.dart`. Three languages:

| Key | EN | FR | AR |
|---|---|---|---|
| `sign_in` | Sign In | Connexion | تسجيل الدخول |
| `my_tasks` | My Tasks | Mes Tâches | مهامي |
| `settings` | Settings | Paramètres | الإعدادات |

All UI strings go through `settings.t(key)` for translation. RTL is auto-detected for Arabic.

---

## Known Limitations

- **Delete Employee** removes Firestore doc but not the Firebase Auth user (requires Admin SDK)
- **Firebase on Spark plan** — no Cloud Functions; push notifications work via app-side FCM
- **applicationId** is `com.example.task_tracker` — changing requires re-registering in Firebase Console
- **Existing presets** created before v0.2.1 lack `createdBy` and won't appear until manually updated in Firestore
- **Windows installer** requires Inno Setup installed on the build machine
