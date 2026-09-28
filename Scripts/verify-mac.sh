#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodebuild -version | tee build/xcode-version.txt
swift test 2>&1 | tee build/core-tests.log
xcodebuild -project Cuike.xcodeproj -scheme Cuike -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/simulator-build.log
if [[ -z "${CUIKE_SIMULATOR_ID:-}" ]]; then
  CUIKE_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((v["udid"] for k,vs in d["devices"].items() if "iOS" in k for v in vs if "iPhone" in v["name"]), ""))')"
fi
if [[ -z "$CUIKE_SIMULATOR_ID" ]]; then
  echo 'No iPhone simulator runtime found. Install one in Xcode Settings > Platforms.' >&2
  exit 1
fi
xcodebuild -project Cuike.xcodeproj -scheme Cuike -configuration Debug \
  -destination "platform=iOS Simulator,id=$CUIKE_SIMULATOR_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/ios-tests.log
