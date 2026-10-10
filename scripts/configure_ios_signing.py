"""Configure only Runner's reviewed build settings for signed CI archives."""
import os
from pathlib import Path


ANCHOR = "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"


def configure(project, team, profile):
    for value in (team, profile):
        if not value or any(c in value for c in ('"', '\\', '\n', '\r', ';')):
            raise ValueError("Invalid manual iOS signing setting.")
    if project.count(ANCHOR) != 3:
        raise ValueError("Expected Runner entitlement settings in Debug, Release and Profile.")
    settings = (
        ANCHOR + '\n'
        '\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
        f'\t\t\t\tDEVELOPMENT_TEAM = "{team}";\n'
        '\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";\n'
        f'\t\t\t\t"PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]" = "{profile}";'
    )
    return project.replace(ANCHOR, settings)


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    try:
        updated = configure(
            args.project.read_text(), os.environ.get("APPLE_TEAM_ID", ""),
            os.environ.get("IOS_PROVISIONING_PROFILE_NAME", ""),
        )
    except ValueError as error:
        raise SystemExit(str(error)) from None
    args.project.write_text(updated)
    print("Runner manual archive signing configured; app entitlements preserved.")


if __name__ == "__main__":
    main()
