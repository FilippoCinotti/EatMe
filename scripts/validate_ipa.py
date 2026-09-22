#!/usr/bin/env python3
"""Validate release metadata and required files inside an exported IPA."""

from __future__ import annotations

import argparse
import plistlib
import zipfile
from pathlib import Path, PurePosixPath


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    failures: list[str] = []
    with zipfile.ZipFile(args.ipa) as archive:
        info_names = []
        for name in archive.namelist():
            parts = PurePosixPath(name).parts
            if (
                len(parts) == 3
                and parts[0] == "Payload"
                and parts[1].endswith(".app")
                and parts[2] == "Info.plist"
            ):
                info_names.append(name)
        if len(info_names) != 1:
            raise SystemExit(f"Expected one application Info.plist, found {len(info_names)}")
        app_prefix = info_names[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(info_names[0]))
        expected = {
            "CFBundleIdentifier": args.bundle_id,
            "CFBundleShortVersionString": args.version,
            "CFBundleVersion": args.build,
        }
        for key, value in expected.items():
            if str(info.get(key)) != value:
                failures.append(f"{key}: expected {value!r}, found {info.get(key)!r}")
        required = (
            app_prefix + "embedded.mobileprovision",
            app_prefix + "PrivacyInfo.xcprivacy",
        )
        for name in required:
            if name not in archive.namelist():
                failures.append(f"Missing {name}")
        executable = app_prefix + str(info.get("CFBundleExecutable", "Runner"))
        if executable not in archive.namelist():
            failures.append("Application executable is missing")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"IPA metadata passed for {args.bundle_id} {args.version} ({args.build})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
