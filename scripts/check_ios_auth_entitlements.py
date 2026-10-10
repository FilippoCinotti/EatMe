"""Reject signed iOS releases missing the native Apple login capability."""
import argparse
import plistlib
from pathlib import Path


def validate(app, profile, bundle_id):
    errors = []
    allowed = profile.get("Entitlements", {})
    capability = "com.apple.developer.applesignin"
    if app.get(capability) != ["Default"]:
        errors.append("Signed app is missing the Sign in with Apple entitlement.")
    if allowed.get(capability) != ["Default"]:
        errors.append("Provisioning profile does not allow Sign in with Apple.")
    app_id = app.get("application-identifier", "")
    if not app_id.endswith("." + bundle_id) or app_id != allowed.get("application-identifier"):
        errors.append("Signed app and provisioning profile must match the production bundle identifier.")
    if app.get("get-task-allow") is not False:
        errors.append("Release app must not allow debugger attachment.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("entitlements", type=Path)
    parser.add_argument("provisioning", type=Path)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()
    with args.entitlements.open("rb") as stream:
        app = plistlib.load(stream)
    with args.provisioning.open("rb") as stream:
        profile = plistlib.load(stream)
    errors = validate(app, profile, args.bundle_id)
    if errors:
        raise SystemExit("\n".join(errors))
    print("Signed Apple login capability and production app identity verified.")


if __name__ == "__main__":
    main()
