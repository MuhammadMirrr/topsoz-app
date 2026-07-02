#!/usr/bin/env python3
"""Avom iOS: App Store Connect da app paydo bo'lgach IPA ni avtomatik yuklaydi."""

from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

KEY_ID = "Y2V5385KN2"
ISSUER_ID = "b69effec-1aef-4317-953f-13c4bb806061"
BUNDLE_ID = "com.uzbapps.avom"
IPA_PATH = Path(__file__).resolve().parents[1] / "build/ios/ipa/Avom.ipa"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys/AuthKey_Y2V5385KN2.p8"
POLL_SECONDS = 15
MAX_WAIT_SECONDS = 3600


def _token() -> str:
    key = KEY_PATH.read_text()
    return jwt.encode(
        {
            "iss": ISSUER_ID,
            "exp": int(time.time()) + 1200,
            "aud": "appstoreconnect-v1",
        },
        key,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def app_exists() -> bool:
    token = _token()
    url = (
        "https://api.appstoreconnect.apple.com/v1/apps"
        f"?filter[bundleId]={BUNDLE_ID}"
    )
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as response:
        payload = json.loads(response.read().decode())
    return bool(payload.get("data"))


def upload_ipa() -> int:
    if not IPA_PATH.is_file():
        print(f"IPA topilmadi: {IPA_PATH}", file=sys.stderr)
        return 1

    env = {
        **dict(subprocess.os.environ),
        "API_PRIVATE_KEYS_DIR": str(KEY_PATH.parent),
    }
    cmd = [
        "xcrun",
        "altool",
        "--upload-app",
        "--type",
        "ios",
        "-f",
        str(IPA_PATH),
        "--apiKey",
        KEY_ID,
        "--apiIssuer",
        ISSUER_ID,
    ]
    print("Yuklanmoqda:", IPA_PATH)
    result = subprocess.run(cmd, env=env, text=True)
    return result.returncode


def main() -> int:
    if not KEY_PATH.is_file():
        print(f"API kalit topilmadi: {KEY_PATH}", file=sys.stderr)
        return 1

    waited = 0
    while not app_exists():
        if waited >= MAX_WAIT_SECONDS:
            print(
                f"App Store Connect da '{BUNDLE_ID}' app {MAX_WAIT_SECONDS}s ichida "
                "paydo bo'lmadi.",
                file=sys.stderr,
            )
            return 2
        print(
            f"Kutilmoqda: App Store Connect da Avom app yaratilishi "
            f"({waited}s / {MAX_WAIT_SECONDS}s)..."
        )
        time.sleep(POLL_SECONDS)
        waited += POLL_SECONDS

    print("Avom app topildi — IPA yuklanmoqda...")
    return upload_ipa()


if __name__ == "__main__":
    raise SystemExit(main())