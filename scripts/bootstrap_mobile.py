"""Resolve dependencies without regenerating reviewed native application projects."""
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
mobile = root / "apps/mobile"
required = [
    "android/app/src/main/AndroidManifest.xml",
    "android/app/build.gradle.kts",
    "ios/Runner.xcodeproj/project.pbxproj",
    "ios/Runner/Runner.entitlements",
    "ios/Runner/PrivacyInfo.xcprivacy",
    "pubspec.lock",
]
missing = [name for name in required if not (mobile / name).is_file()]
if missing:
    raise SystemExit("Restore the reviewed project files from Git before continuing: " + ", ".join(missing))
flutter = shutil.which("flutter")
if not flutter:
    raise SystemExit("Install Flutter 3.47.2 and add flutter to PATH, then run this command again.")
subprocess.run([flutter, "pub", "get", "--enforce-lockfile"], cwd=mobile, check=True)
print("Dependencies resolved using the committed lockfile. Native configuration preserved.")
