# Local development and debugging

## Tools

| Target | Required tools |
| --- | --- |
| API and worker | Python 3.12, pip, Git |
| Android | Flutter 3.47.2, Android Studio, Android SDK 36, emulator system image, JDK 17 |
| iOS | macOS, Flutter 3.47.2, compatible Xcode with iOS simulator runtime, command-line tools; CocoaPods for plugin integration |
| Editorial studio and guest RSVP | Node.js 22 and npm |
| Production-like database | PostgreSQL 17 or Supabase; Docker is convenient locally |

Use `flutter doctor -v` to resolve SDK, license and native toolchain issues. Android Studio's Device Manager creates Android virtual devices. Xcode's Settings → Platforms installs simulator runtimes; launch Simulator from Xcode's developer tools. iOS Simulator cannot run on Windows or Linux. A Windows development computer can run Android immediately and use a Mac for iOS.

Official setup references: [Android](https://docs.flutter.dev/platform-integration/android/setup) and [iOS](https://docs.flutter.dev/platform-integration/ios/setup).

## Backend

From the repository root:

```bash
python -m venv .venv
# macOS/Linux
source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install -e 'services/api[dev]'
python scripts/dev.py
```

The development server listens on `127.0.0.1:8000`. It uses SQLite and a demonstration catalog. It is not a production HTTP server. `GET /api/v1/health` verifies availability. Stop both development processes with Ctrl+C. Keep the environment's `AI_PROVIDER` unset unless you need processing; `development` enables conspicuously labelled fixtures, while `openai` requires live configuration.

For the production HTTP adapter locally:

```bash
uvicorn eatme.api:create_app --factory --host 127.0.0.1 --port 8000
```

Run the worker in another terminal with `python services/worker/main.py` when using photo, receipt or assisted recipe jobs.

## Flutter

Run `python scripts/bootstrap_mobile.py` once after a fresh checkout. It verifies the committed native projects and resolves dependencies with the committed lockfile. Restore missing native files from Git; a generic Flutter runner does not contain EatMe's permissions, privacy manifest, signing or authentication capabilities. Review native source and lockfile changes whenever the Flutter version changes.

```bash
cd apps/mobile
flutter emulators
flutter emulators --launch YOUR_EMULATOR_ID
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define=API_URL=http://10.0.2.2:8000/api/v1
```

For iOS Simulator, use `http://127.0.0.1:8000/api/v1`. On a physical phone use the development computer's reachable LAN address and deliberately bind a development API to that interface; do not expose local authentication publicly. Use HTTPS for staging and release.

Debug builds support breakpoints, Flutter DevTools, hot reload and the widget inspector. Release builds reject development authentication and non-HTTPS API URLs. A scanner's camera needs a physical device or emulator camera input. Gallery import and manual barcode entry provide simulator-friendly paths.

CI publishes Android debug APK and iOS simulator application artifacts when their build succeeds. These development artifacts use the default loopback API address; on Android use `adb reverse tcp:8000 tcp:8000` before launching an installed artifact. Building with `flutter run` and the explicit emulator URL above is the easiest source-debugging path. On macOS, unzip the simulator archive, boot a simulator, then use `xcrun simctl install booted Runner.app` and `xcrun simctl launch booted com.filippocinotti.eatme`. A simulator application cannot be installed on a physical iPhone.

## Studio

```bash
cd apps/admin
npm ci --ignore-scripts
npm run dev
```

Set `EATME_API_URL=http://127.0.0.1:8000/api/v1`. Create/onboard an account through the app, then add its UUID to the API's `ADMIN_USER_IDS` for local administration and restart the API. Use a separate account for independent publication review. Production deployments should assign persisted editorial roles and restrict bootstrap superadmin UUIDs.

## Guest RSVP

```bash
cd apps/guest
cp .env.example .env.local
npm ci --ignore-scripts
npm run dev
```

The guest app listens on `127.0.0.1:3000` and calls the public capability-link endpoints configured by `NEXT_PUBLIC_API_URL`. Set the API's `GUEST_APP_URL` to the externally reachable guest origin when testing links on another device. No Supabase key, login credential or analytics provider belongs in this app.

## Verification commands

```bash
python -m unittest discover -s services/api/tests -v
python -m ruff check services/api services/worker scripts
python scripts/check_repository.py
cd apps/guest
npm ci --ignore-scripts
npm run typecheck
npm run build
cd apps/mobile
flutter analyze
flutter test
flutter build apk --debug
# macOS only
flutter build ios --simulator --debug
```

CI runs the dependency-equipped API checks, PostgreSQL RLS checks, studio build and mobile platform matrix. Read the verification report for the exact tested commit and outstanding gates.
