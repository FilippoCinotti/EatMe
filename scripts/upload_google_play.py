"""Upload a signed Android App Bundle through a transactional Google Play edit."""

import argparse
import json
from pathlib import Path
from urllib.parse import quote

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account


SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def checked_json(response, action):
    if not response.ok:
        detail = response.text[:2000].replace("\n", " ")
        raise SystemExit(f"Google Play {action} failed ({response.status_code}): {detail}")
    return response.json() if response.content else {}


def upload(bundle, credentials_file, package_name, track, release_name):
    credentials = service_account.Credentials.from_service_account_file(
        credentials_file,
        scopes=[SCOPE],
    )
    session = AuthorizedSession(credentials)
    package = quote(package_name, safe="")
    api = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}"

    edit = checked_json(
        session.post(f"{api}/edits", json={}, timeout=60),
        "edit creation",
    )
    edit_id = edit["id"]
    upload_url = (
        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/"
        f"applications/{package}/edits/{quote(edit_id, safe='')}/bundles"
    )
    with bundle.open("rb") as artifact:
        uploaded = checked_json(
            session.post(
                upload_url,
                params={"uploadType": "media"},
                headers={"Content-Type": "application/octet-stream"},
                data=artifact,
                timeout=300,
            ),
            "bundle upload",
        )

    version_code = str(uploaded["versionCode"])
    track_url = f"{api}/edits/{quote(edit_id, safe='')}/tracks/{quote(track, safe='')}"
    checked_json(
        session.put(
            track_url,
            json={
                "track": track,
                "releases": [
                    {
                        "name": release_name,
                        "versionCodes": [version_code],
                        "status": "completed",
                    }
                ],
            },
            timeout=60,
        ),
        "track update",
    )
    checked_json(
        session.post(f"{api}/edits/{quote(edit_id, safe='')}:commit", timeout=60),
        "edit commit",
    )
    return {"track": track, "version_code": version_code, "status": "committed"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--track", default="internal")
    parser.add_argument("--release-name", required=True)
    args = parser.parse_args()
    if not args.bundle.is_file():
        raise SystemExit(f"Bundle not found: {args.bundle}")
    if not args.credentials.is_file():
        raise SystemExit("Google Play credentials file not found")
    result = upload(
        args.bundle,
        args.credentials,
        args.package,
        args.track,
        args.release_name,
    )
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
