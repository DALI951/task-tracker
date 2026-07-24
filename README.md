# Task Tracker

Unified task management app with role-based UI. Single APK for both managers and employees.

## Features

- **Role-based UI** — interface changes based on user type (manager/employee)
- **Photo proof** — employees submit photos as task completion proof
- **Real-time sync** — Firestore streams for live updates
- **Pull-to-refresh** — swipe down to refresh task/problem lists
- **Status filters** — filter tasks by status (pending/in progress/review/completed)
- **Auto-update** — checks GitHub Releases for new versions, downloads silently
- **Multi-language** — English, French, Arabic (RTL support)
- **Dark/Light theme** — with accent color customization

## Releases

Download the latest APK from [GitHub Releases](https://github.com/DALI951/task-tracker/releases).

## Setup

### Prerequisites

- Flutter SDK 3.24+
- Android Studio (or IntelliJ with Flutter plugin)
- Git

### Install

```bash
git clone https://github.com/DALI951/task-tracker.git
cd task-tracker
flutter pub get
flutter run
```

### Build Release

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Account Creation

Accounts are created via `web_admin/index.html` (not in-app):

1. Open `web_admin/index.html` in a browser
2. Enter admin passphrase: `tasktracker2024`
3. Fill in email, password, display name, and role
4. Click "Create Account"

## Project Structure

```
task_tracker/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── config/brand.dart                  # Design constants
│   ├── screens/
│   │   ├── login_screen.dart              # Sign-in (no sign-up)
│   │   ├── manager_dashboard.dart         # Manager: tasks + problems tabs
│   │   ├── employee_tasks_screen.dart     # Employee: task list
│   │   ├── task_detail_screen.dart        # Task detail (shared)
│   │   ├── manage_employees_screen.dart   # CRUD employees
│   │   ├── problems_screen.dart           # View/convert problems
│   │   ├── report_problem_screen.dart     # Report problem with photo
│   │   ├── settings_screen.dart           # Theme, language, updates
│   │   ├── preset_items_screen.dart       # Manage preset items
│   │   └── update_modal.dart              # Update prompt modal
│   ├── services/
│   │   ├── auth_service.dart              # Firebase Auth wrapper
│   │   ├── auth_gate.dart                 # Auth state → role routing
│   │   ├── update_service.dart            # GitHub API, download, install
│   │   ├── session_service.dart           # Manager credential storage
│   │   ├── firestore_service.dart         # Firestore CRUD
│   │   ├── settings_service.dart          # Prefs + i18n
│   │   └── user_service.dart              # Role management
│   ├── providers/task_provider.dart       # State management
│   ├── models/                            # Data models
│   ├── utils/                             # Error handler, connectivity
│   └── widgets/                           # Reusable widgets
├── web_admin/index.html                   # Account creation website
├── .github/workflows/build.yml            # CI/CD: build → GitHub Release
├── releases/                              # Release APKs
├── firestore.rules                        # Security rules
├── pubspec.yaml                           # Dependencies (v2.0.0)
└── README.md
```

## CI/CD

Push to `master` triggers GitHub Actions:
1. Builds release APK
2. Creates GitHub release with `Task-Tracker-v{version}.apk`

To trigger a release: update `version:` in `pubspec.yaml` and push.

## Firebase

Connected to project `task-tracker-6d7e1`. See `lib/firebase_options.dart` for config.

## License

Private project.
