<div align="center">

# ✅ Task Tracker

**Enterprise task management with photo proof of completion.**

A unified Flutter app with role-based UI for **Managers** and **Employees** — assign tasks, track progress, verify with photos, and get notified in real time.

---

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)]()
[![Web](https://img.shields.io/badge/Web-GitHub%20Pages-222222?style=for-the-badge&logo=githubpages&logoColor=white)]()
[![Windows](https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)]()

<br>

**Version 0.2.2** · **EN / FR / AR** · **Dark Mode** · **Push Notifications** · **Auto-Update**

</div>

---

## ✨ Highlights

<table>
<tr>
<td width="50%">

### 👨‍💼 Manager Features
- Create & assign tasks from **presets** or custom
- **Approve or reject** completions with photo proof
- Manage employees, preset templates, and item lists
- View problems reported by employees
- Convert problems into tasks
- Full data isolation — only see **your own** data

</td>
<td width="50%">

### 👷 Employee Features
- View assigned tasks with **search & filters**
- **Claim** a task → work on it → **submit photo proof**
- Report problems with optional photo
- Real-time **push notifications**
- Notification preferences with per-type toggles
- Multi-language support (EN/FR/AR + RTL)

</td>
</tr>
</table>

---

## 🔄 Task Lifecycle

```
┌──────────┐     ┌──────────┐     ┌────────────────┐     ┌──────────┐
│  Pending  │────▶│    Doing  │────▶│ Pending Review  │────▶│ Completed│
└──────────┘     └──────────┘     └────────────────┘     └──────────┘
                       ▲                    │
                       │         ┌──────────┘
                       └─────────┘  (rejected → back to doing)
```

| Status | Meaning |
|--------|---------|
| 🟠 `Pending` | Task created, waiting for an employee to claim |
| 🔵 `Doing` | Employee has started working on the task |
| 🟣 `Pending Review` | Photo proof submitted, waiting for manager approval |
| 🟢 `Completed` | Manager approved the completion |
| 🔴 `Rejected` | Manager rejected the proof (returns to Doing) |

---

## 📱 Platform Support

| Platform | Camera | Auto-Update | Push Notifications | Installer |
|----------|--------|-------------|-------------------|-----------|
| 🤖 Android | ✅ Direct capture | ✅ In-app download | ✅ FCM v1 | APK sideload |
| 🌐 Web | ❌ Gallery only | ❌ | ✅ In-app only | GitHub Pages |
| 🖥️ Windows | ❌ Gallery only | ❌ | ❌ | Inno Setup `.exe` |

---

## 🚀 Quick Start

### Prerequisites

- Flutter `3.44+`
- Firebase project with Auth, Firestore, and FCM enabled
- Android Studio or VS Code

### 1. Clone & Install

```bash
git clone https://github.com/DALI951/task-tracker.git
cd task-tracker
flutter pub get
```

### 2. Firebase Setup

Place your `google-services.json` in `android/app/` and `lib/firebase_options.dart` should already be configured.

### 3. Run

```bash
# Android
flutter run --release

# Web
flutter run -d chrome --release

# Windows
flutter run -d windows --release
```

### 4. Create Accounts

- **Self-signup (public):** create an employee account at the [Registration Website](https://dali951.github.io/task-tracker-admin/register.html)
- **Admin panel:** the [Admin Panel](https://dali951.github.io/task-tracker-admin/) → enter passphrase `tasktracker2024` → create manager/employee accounts

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                   main.dart                      │
│         Splash → Firebase Init → AuthGate        │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────┐    ┌──────────────────────┐   │
│  │  TaskProvider │    │   SettingsService     │   │
│  │  (ChangeNotif)│    │   (ChangeNotifier)    │   │
│  └──────┬───────┘    └──────────┬───────────┘   │
│         │                       │                │
│  ┌──────▼───────┐    ┌──────────▼───────────┐   │
│  │FirestoreSvc  │    │  AuthService         │   │
│  │NotificationSvc│   │  UserService         │   │
│  │StorageService│    │  SessionService      │   │
│  └──────────────┘    │  PushNotificationSvc │   │
│                      │  UpdateService       │   │
│                      └──────────────────────┘   │
├─────────────────────────────────────────────────┤
│                   Firebase                       │
│          Auth · Firestore · FCM                  │
└─────────────────────────────────────────────────┘
```

### State Management

**`ChangeNotifier` + `Provider`** — single `TaskProvider` handles all app state (tasks, employees, presets, problems). Streams from Firestore auto-update the UI in real time.

### Auth Flow

```
No user? → LoginScreen
Has user? → Read role from Firestore
  ├─ Manager   → ManagerDashboard (tasks + problems tabs)
  ├─ Employee  → EmployeeTasksScreen (task list + search)
  └─ No role   → Auto-provision as employee
```

---

## 📁 Project Structure

<details>
<summary><strong>lib/</strong> — Flutter source code</summary>

```
lib/
├── main.dart                         # Entry, providers, splash screen
├── config/
│   └── brand.dart                    # Colors, radii, brand constants
├── models/
│   ├── task.dart                     # AppTask + HistoryEvent
│   ├── problem.dart                  # Problem model
│   ├── preset_task.dart              # PresetTask template
│   ├── preset_item.dart              # PresetItem template
│   └── app_notification.dart         # Notification model
├── providers/
│   └── task_provider.dart            # All state management
├── screens/
│   ├── login_screen.dart             # Sign-in
│   ├── manager_dashboard.dart        # Manager: tasks + problems tabs
│   ├── employee_tasks_screen.dart    # Employee: task list + search
│   ├── task_detail_screen.dart       # Task detail (shared)
│   ├── manage_employees_screen.dart  # Employee CRUD
│   ├── problems_screen.dart          # Problem list / convert
│   ├── report_problem_screen.dart    # Employee: report problem
│   ├── settings_screen.dart          # Settings, presets, i18n
│   ├── notifications_screen.dart     # Notification list
│   ├── notification_preferences_screen.dart  # Per-type toggles
│   ├── preset_items_screen.dart      # Preset item management
│   └── update_modal.dart             # Update prompt
├── services/
│   ├── auth_gate.dart                # Auth routing by role
│   ├── auth_service.dart             # Firebase Auth
│   ├── firestore_service.dart        # Firestore CRUD
│   ├── user_service.dart             # Role management
│   ├── session_service.dart          # Credential storage
│   ├── settings_service.dart         # Theme/language/i18n
│   ├── notification_service.dart     # Notifications CRUD
│   ├── push_notification_service.dart # FCM + local notifications
│   ├── fcm_sender.dart               # FCM v1 HTTP push
│   ├── storage_service.dart          # Image encoding
│   └── update_service.dart           # GitHub Releases auto-update
├── utils/
│   ├── error_handler.dart            # Friendly error messages
│   └── toast.dart                    # Toast utility
└── widgets/
    └── task_card.dart                # Reusable task card
```

</details>

<details>
<summary><strong>firestore.rules</strong> — Security rules</summary>

```
firestore.rules        # Firestore security rules (data isolation)
```

</details>

---

## 🔥 Firebase & Security

### Firestore Collections

| Collection | Description | Access Control |
|------------|-------------|----------------|
| `users/{uid}` | User profiles, roles, FCM tokens | Owner + managers |
| `tasks/{id}` | Tasks with full lifecycle + history | Manager (own) / Employee (assigned) |
| `employees/{email}` | Employee directory | Manager only (own) |
| `preset_tasks/{id}` | Reusable task templates | Manager (own) / Employee (read) |
| `preset_items/{id}` | Reusable item lists | Manager (own) / Employee (read) |
| `problems/{id}` | Reported problems | Any user create/read; Manager update/delete |
| `notifications/{notifId}` | In-app notifications | Recipient only |

### Data Isolation

Each manager's data is scoped by `createdBy`:

- **Tasks** — managers only see tasks they created
- **Employees** — managers only see employees they created
- **Presets** — managers only see their own preset templates
- **Problems** — any user can create; only managers can update

Employees can only read tasks assigned to their email and update limited fields (status, photo, history).

---

## 🔔 Push Notifications

Powered by **FCM v1 HTTP API** via service account — no Cloud Functions needed.

<details>
<summary><strong>Notification types</strong></summary>

| Type | When | Recipient |
|------|------|-----------|
| `task_assigned` | Manager assigns task | Employee |
| `task_started` | Employee claims task | Manager |
| `task_submitted` | Employee submits proof | Manager |
| `task_approved` | Manager approves | Employee |
| `task_rejected` | Manager rejects | Employee |
| `task_status_changed` | Any status change | Assigned employee |
| `task_reassigned` | Task reassigned | New employee |
| `problem_reported` | Employee reports problem | Managers |
| `problem_resolved` | Problem converted to task | Reporter |

</details>

| Component | File | Role |
|-----------|------|------|
| Send push | `fcm_sender.dart` | Authenticates with Google APIs, sends to FCM v1 |
| Receive | `push_notification_service.dart` | Foreground messages, local notifications, token save |
| Preferences | `notification_preferences_screen.dart` | Per-type toggles |

---

## 🚢 CI/CD Pipeline

Push to `master` → GitHub Actions builds everything automatically.

```
Push to master
     │
     ├──▶ build-apk ──────────┐
     │                         ├──▶ create-release ──▶ GitHub Release
     ├──▶ build-web ──────────┤        (APK + Web + Windows)
     │                         │
     ├──▶ deploy-web ─────────┘──▶ GitHub Pages
     │
     └──▶ build-windows ─────────┘
```

| Job | What it does |
|-----|-------------|
| `build-apk` | Builds signed APK, uploads as artifact |
| `build-web` | Builds web + copies admin pages, zips, uploads |
| `deploy-web` | Deploys web build to GitHub Pages |
| `build-windows` | Builds Windows installer |
| `create-release` | Downloads all artifacts, creates GitHub Release |

### Required Secrets

| Secret | Purpose |
|--------|---------|
| `SERVICE_ACCOUNT_JSON_BASE64` | Firebase service account (FCM push) |
| `ANDROID_KEYBASE64` | Release keystore (APK signing) |
| `ANDROID_KEY_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |

---

## 📦 Dependencies

| Category | Packages |
|----------|----------|
| **Firebase** | `firebase_core` · `firebase_auth` · `cloud_firestore` · `firebase_messaging` |
| **Notifications** | `flutter_local_notifications` · `googleapis_auth` |
| **UI** | `provider` · `image_picker` · `intl` · `url_launcher` |
| **Networking** | `http` · `dio` |
| **Storage** | `shared_preferences` · `path_provider` |
| **Platform** | `package_info_plus` · `permission_handler` · `open_file` |

---

## 🌍 Internationalization

Three languages built-in with full RTL support:

| | English | French | Arabic |
|---|---------|--------|--------|
| Sign In | Sign In | Connexion | تسجيل الدخول |
| My Tasks | My Tasks | Mes Tâches | مهامي |
| Settings | Settings | Paramètres | الإعدادات |
| Task Assigned | Task Assigned | Tâche assignée | تم تعيين مهمة |

All strings go through `settings.t(key)` — add a new language by adding a map to `settings_service.dart`.

---

## ⚠️ Known Limitations

| Issue | Details |
|-------|---------|
| Employee deletion | Removes Firestore doc only; Firebase Auth user requires Admin SDK |
| Spark plan | No Cloud Functions; push works via app-side FCM |
| Legacy presets | Created before v0.2.1 lack `createdBy` — won't appear until updated |
| applicationId | `com.example.task_tracker` — changing requires Firebase Console re-registration |
| Windows build | Requires Inno Setup installed on the build machine |

---

<div align="center">

**Built with ❤️ using Flutter + Firebase**

[Report Bug](https://github.com/DALI951/task-tracker/issues) · [Request Feature](https://github.com/DALI951/task-tracker/issues)

</div>
# Upload behavior

Task proof and problem photos use a bounded, sequential upload queue (maximum
50 photos). The queue publishes completed/total progress through
`TaskProvider`, and the Firestore submission is written only after every photo
has uploaded, so manager actions cannot run against a partial submission. The
queue continues while the app is navigating between screens. It is deliberately
not a process-level Android background service: if the OS force-stops the app,
the in-memory photo bytes are lost and the employee can retry. This avoids the
foreground-service launch crash from the historical v0.4.8 implementation.
