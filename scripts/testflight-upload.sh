#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing required command: $name" >&2
    exit 1
  fi
}

decode_env_base64() {
  local env_name="$1"
  local output_path="$2"
  python3 - "$env_name" "$output_path" <<'PY'
import base64
import binascii
import os
import sys

env_name = sys.argv[1]
output_path = sys.argv[2]
value = "".join(os.environ[env_name].split())
padding = "=" * (-len(value) % 4)
try:
    decoded = base64.b64decode(value + padding, validate=True)
except (binascii.Error, ValueError):
    print(f"Invalid base64 in environment variable: {env_name}", file=sys.stderr)
    sys.exit(1)

with open(output_path, "wb") as output:
    output.write(decoded)
PY
}

validate_build_path() {
  local name="$1"
  local path="$2"
  python3 - "$ROOT_DIR" "$name" "$path" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
name = sys.argv[2]
raw = Path(sys.argv[3])
build = (root / "build").resolve(strict=False)
path = (raw if raw.is_absolute() else root / raw).resolve(strict=False)

try:
    path.relative_to(build)
except ValueError:
    print(f"{name} must be inside {build}: {path}", file=sys.stderr)
    sys.exit(1)

if path == build:
    print(f"{name} must point inside {build}, not to build itself", file=sys.stderr)
    sys.exit(1)
PY
}

for env_name in \
  APP_STORE_CONNECT_API_KEY_ID \
  APP_STORE_CONNECT_API_ISSUER_ID \
  APP_STORE_CONNECT_API_KEY_BASE64 \
  WHATSINTHIS_BACKEND_BASE_URL
do
  require_env "$env_name"
done

require_command basename
require_command date
require_command find
require_command mktemp
require_command python3
require_command xcodebuild
require_command xcrun

xcrun --find altool >/dev/null 2>&1 || {
  echo "Missing required Xcode utility: altool" >&2
  exit 1
}

SCHEME="${SCHEME:-whatsinthis}"
PROJECT="${PROJECT:-whatsinthis.xcodeproj}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-533428ZQTT}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/DerivedData-iOS-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/whatsinthis.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/testflight-export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-build/testflight-export-options.plist}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_ID:-${GITHUB_RUN_NUMBER:-$(date -u +%Y%m%d%H%M)}}}"
MARKETING_VERSION="${MARKETING_VERSION:-}"
TESTFLIGHT_ENVIRONMENT="${TESTFLIGHT_ENVIRONMENT:-canary}"
WAIT_FOR_PROCESSING="${WAIT_FOR_PROCESSING:-false}"

case "$TESTFLIGHT_ENVIRONMENT" in
  canary|production|prod) ;;
  *)
    echo "TESTFLIGHT_ENVIRONMENT must be canary or production: $TESTFLIGHT_ENVIRONMENT" >&2
    exit 1
    ;;
esac

if [[ ! "$APP_STORE_CONNECT_API_KEY_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APP_STORE_CONNECT_API_KEY_ID must be exactly 10 uppercase alphanumeric characters" >&2
  exit 1
fi

if [[ ! "$APP_STORE_CONNECT_API_ISSUER_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  echo "APP_STORE_CONNECT_API_ISSUER_ID must be a UUID" >&2
  exit 1
fi

if [[ -n "$MARKETING_VERSION" && ! "$MARKETING_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "MARKETING_VERSION must look like 1, 1.2, or 1.2.3: $MARKETING_VERSION" >&2
  exit 1
fi

if [[ -L build ]]; then
  echo "Refusing to use build because it is a symbolic link" >&2
  exit 1
fi
mkdir -p build

validate_build_path DERIVED_DATA_PATH "$DERIVED_DATA_PATH"
validate_build_path ARCHIVE_PATH "$ARCHIVE_PATH"
validate_build_path EXPORT_PATH "$EXPORT_PATH"
validate_build_path EXPORT_OPTIONS_PLIST "$EXPORT_OPTIONS_PLIST"

rm -rf "$DERIVED_DATA_PATH" "$ARCHIVE_PATH" "$EXPORT_PATH" "$EXPORT_OPTIONS_PLIST"

umask 077
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatsinthis-testflight.XXXXXX")"
TEMP_PRIVATE_KEYS_DIR="$TEMP_DIR/private_keys"
ASC_KEY_PATH="$TEMP_PRIVATE_KEYS_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TEMP_PRIVATE_KEYS_DIR"
decode_env_base64 APP_STORE_CONNECT_API_KEY_BASE64 "$ASC_KEY_PATH"
chmod 600 "$ASC_KEY_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

ARCHIVE_BUILD_SETTINGS=(
  WHATSINTHIS_BACKEND_BASE_URL="$WHATSINTHIS_BACKEND_BASE_URL"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ -n "$MARKETING_VERSION" ]]; then
  ARCHIVE_BUILD_SETTINGS+=(MARKETING_VERSION="$MARKETING_VERSION")
fi

echo "Archiving ${SCHEME} ${TESTFLIGHT_ENVIRONMENT} build with backend ${WHATSINTHIS_BACKEND_BASE_URL}"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID" \
  -allowProvisioningUpdates \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  "${ARCHIVE_BUILD_SETTINGS[@]}"

echo "Exporting archive"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID" \
  -allowProvisioningUpdates

IPA_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "$IPA_PATH" ]]; then
  echo "No IPA found in $EXPORT_PATH" >&2
  exit 1
fi

UPLOAD_ARGS=(
  --upload-app
  -t ios
  -f "$IPA_PATH"
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID"
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
  --output-format json
  --show-progress
)

if [[ "$WAIT_FOR_PROCESSING" == "true" ]]; then
  UPLOAD_ARGS+=(--wait)
fi

echo "Uploading $(basename "$IPA_PATH") to TestFlight"
(
  cd "$TEMP_DIR"
  API_PRIVATE_KEYS_DIR="$TEMP_PRIVATE_KEYS_DIR" xcrun altool "${UPLOAD_ARGS[@]}"
)
