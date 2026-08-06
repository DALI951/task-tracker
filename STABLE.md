# ⭐ STABLE MARKER — v0.4.9 (known good)

**THIS version is the CLOSEST to "done" the app has ever been.**

If anything breaks — a bad release, an app crash on launch, a messed-up push —
**roll back to this commit before doing anything else.**

| Field    | Value |
|----------|-------|
| Version  | `0.4.9+11` (`pubspec.yaml`) |
| Commit   | **`c877cc9`** |
| Tag      | `v0.4.9` (release with APK + web.zip + ipa) |
| Released | 2026-08-06 |
| Release URL | https://github.com/DALI951/task-tracker/releases/tag/v0.4.9 |
| Web live | https://dali951.github.io/task-tracker/ |

## How to roll back if a disturbance happens

```powershell
cd C:\Users\Dali\Documents\Projects\task_tracker
git fetch origin master
git checkout --detach backup-or-any-safe-point   # or simply:
git reset --hard c877cc9    # the known-good commit
git push --force origin master   # ONLY if you accept rewinding remote
```

Safer path (no force-push): create a new branch from the good commit and
release from **that** instead of rewriting `master`:

```powershell
git checkout c877cc9
git switch -c v0.4.9-stable
git push origin v0.4.9-stable
```

## What makes v0.4.9 the stable baseline

- All 11 spec changes applied cleanly on top of the v0.4.7 rollback
- `flutter analyze` clean for `lib/` (only pre-existing infos)
- API endpoints protected with `X-App-Secret` (verified: wrong → 401)
- Problems are tenant-scoped with `managerEmail` stamping + strict rules
- Firestore rules + composite index deployed
- CI all green (build-apk, build-web, build-ios, deploy-web)
- Web deployed to GitHub Pages

## Things to NOT re-enable without a clean strategy

- **flutter_foreground_task** background photo-upload (caused the cold-start crash in v0.4.8–v0.4.10)
- **flutter_downloader** persistent downloads (same crash family)
- The photo-upload foreground service code in `backup-broken-0.4.8-0.4.10` branch

---

⚠️ Dali: if you ever see "the app won't open" or "sends me to home page" again,
ask OpenCode to **restore commit `c877cc9` first** before fixing.