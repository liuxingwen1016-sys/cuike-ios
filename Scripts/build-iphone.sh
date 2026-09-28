#!/bin/bash
# Build for physical iPhones. Apple ID signing happens later on Windows.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Run this script on the GitHub macOS runner or a Mac with Xcode.' >&2
  exit 1
fi

mkdir -p build/iphone
xcodebuild -version | tee build/iphone/xcode-version.txt
xcodebuild -project Cuike.xcodeproj -scheme Cuike -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/iphone/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build \
  2>&1 | tee build/iphone/device-build.log

app='build/iphone/DerivedData/Build/Products/Release-iphoneos/Cuike.app'
test -f "$app/Info.plist"
test -f "$app/PlugIns/CuikeWidgets.appex/Info.plist"

# Every invocation stages into a new directory, never an old simulator app.
stage="$(mktemp -d "$PWD/build/iphone/package.XXXXXX")"
mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/Cuike.app"
app="$stage/Payload/Cuike.app"

# Local ad-hoc signatures carry the App Group entitlement for the re-signer.
# They are NOT Apple development signatures and cannot authorize installation.
python3 - "$app" "$stage" <<'PY'
from pathlib import Path
import plistlib
import subprocess
import sys

app, stage = map(Path, sys.argv[1:])
group = None
for bundle in (app / 'PlugIns/CuikeWidgets.appex', app):
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Not a device build'
    executable = bundle / info['CFBundleExecutable']
    arch = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    assert arch == 'arm64', f'Unexpected device architecture: {arch}'
    bundle_group = info['CuikeAppGroup']
    assert bundle_group.startswith('group.') and '$(' not in bundle_group
    assert group in (None, bundle_group), 'App and widget groups differ'
    group = bundle_group
    entitlements = stage / (bundle.name + '.entitlements')
    entitlements.write_bytes(plistlib.dumps({'com.apple.security.application-groups': [group]}))
    subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(entitlements),
                    '--generate-entitlement-der', str(bundle)], check=True)
    print(f"{bundle.name}: {info['CFBundleIdentifier']}, {arch}, iOS {info['MinimumOSVersion']}+")
PY

ipa="$PWD/build/iphone/Cuike-unsigned.ipa"
ditto -c -k --keepParent "$stage/Payload" "$ipa"
python3 - "$ipa" <<'PY'
import sys
import zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    assert 'Payload/Cuike.app/Cuike' in names
    assert 'Payload/Cuike.app/PlugIns/CuikeWidgets.appex/CuikeWidgets' in names
    assert not any(n.endswith('embedded.mobileprovision') for n in names)
print('IPA integrity checked; app and widget extension included.')
PY

{
  echo 'Cuike iPhone package — requires Apple ID re-signing on Windows'
  echo 'Contains the main app and WidgetKit / Live Activity extension.'
  echo 'Temporary ad-hoc signatures preserve entitlement metadata only.'
  echo 'App Group access after re-signing must be verified on the device.'
  echo "Commit: ${GITHUB_SHA:-local}"
  echo "Run: ${GITHUB_RUN_ID:-local}"
  date -u '+Built at: %Y-%m-%dT%H:%M:%SZ'
  xcodebuild -version
  xcrun --sdk iphoneos --show-sdk-version
  shasum -a 256 "$ipa"
} > build/iphone/build-info.txt

echo 'Created build/iphone/Cuike-unsigned.ipa. Re-sign with Sideloadly before installation.'
