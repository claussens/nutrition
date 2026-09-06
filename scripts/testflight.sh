#!/usr/bin/env bash
#
# testflight.sh — archive Nutrition and ship it to TestFlight.
#
# Usage:
#   scripts/testflight.sh                # archive, export, upload
#   scripts/testflight.sh --no-upload    # archive + export only
#   BUILD_NUMBER=57 scripts/testflight.sh   # force a build number
#
# ---------------------------------------------------------------------------
# HealthKit
# ---------------------------------------------------------------------------
# nutrition/nutrition.entitlements requests com.apple.developer.healthkit, so
# the App ID com.claussen.nutrition must have the HealthKit capability
# ENABLED on the developer portal or signing fails. (That entitlement is also
# why this app has always had an explicit App ID: a wildcard App ID cannot
# carry entitlements.)
#
# ---------------------------------------------------------------------------
# The app icon — do not undo the 2026-07-27 move
# ---------------------------------------------------------------------------
# Assets.xcassets must NOT live under "Preview Content". That folder is named
# in DEVELOPMENT_ASSET_PATHS, and development assets survive a Release build
# but are stripped from an ARCHIVE — so the icon vanishes from exactly the
# artifact TestFlight receives, and an iconless build is auto-rejected. See
# the comment on DEVELOPMENT_ASSET_PATHS in project.yml.
#
# ---------------------------------------------------------------------------
# The build number, and why it is NOT in project.yml
# ---------------------------------------------------------------------------
# App Store Connect rejects a build number it has already seen for this
# marketing version. project.yml pins CURRENT_PROJECT_VERSION: 1 and
# `xcodegen generate` rewrites the project from it, so a number edited into
# the generated project is erased on the next regen. Passing it to xcodebuild
# overrides both without touching either file. The value is the commit count
# on HEAD: monotonic, stateless, and it ties a build back to its commit.
# Re-shipping the SAME commit is the one case it can't cover — pass
# BUILD_NUMBER for that.
#
# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------
# Needs an App Store Connect API key created at
#   App Store Connect → Users and Access → Integrations → App Store Connect API
# with the **Admin** role. NOT "App Manager" — that role can upload a build but
# is refused access to cloud-managed distribution certificates, so the ARCHIVE
# succeeds and the EXPORT dies with "Cloud signing permission error" and an
# HTTP 403 FORBIDDEN_ERROR (proven 2026-07-27, on a key created as App Manager;
# the recovery text reads "You haven't been given access to cloud-managed
# distribution certificates"). A key's role cannot be edited after creation —
# a wrong role means revoking it and generating a new one.
#
# Download the .p8 ONCE (Apple never shows it again), then:
#
#   mkdir -p ~/.appstoreconnect/private_keys
#   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
#   # values live in 1Password — do not put them in ~/.env
#   with-asc ./scripts/testflight.sh
#   # or rely on this script's automatic `op run` re-exec
#
# One key covers every app on the team — shared with swish, mivista, future.

set -euo pipefail

cd "$(dirname "$0")/.."

# xcode-select points at the Command Line Tools on this machine, so a bare
# xcodebuild fails with "tool 'xcodebuild' requires Xcode". Switching it needs
# an admin password; exporting DEVELOPER_DIR does not.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

SCHEME=nutrition
ARCHIVE=build/Nutrition.xcarchive
EXPORT_DIR=build/testflight
OPTIONS=scripts/ExportOptions.plist

UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"

# ---------------------------------------------------------------------------
# Portal credentials, needed EARLIER than you would expect.
# ---------------------------------------------------------------------------
# These are not only for the upload. `-allowProvisioningUpdates` has to talk to
# the developer portal to fetch or create the App Store provisioning profile,
# and a non-interactive xcodebuild cannot see the account signed into Xcode.app
# — it fails with "No Accounts: Add a new account in Accounts settings" and
# silently falls back to the cached wildcard profile, which is not valid for
# App Store distribution and carries no entitlements. So the key is passed to
# the ARCHIVE step too. Proven 2026-07-27: without it, apps with entitlements
# fail at archive ("profile ... doesn't include the HealthKit capability") and
# apps without them fail at export ("No profiles for '<bundle id>' were found").
# ASC_KEY_ID / ASC_ISSUER_ID are not ambient in shells (on purpose). They live
# in 1Password and are injected per-process via `op run` / `with-asc`. This
# script re-execs itself under op when they are unset, so CI, hooks, and
# non-interactive agent shells work the same as a desk run.
# ASC lives in 1Password (Private / AI App Store Connect), not ~/.env.
# If unset, re-exec under `op run` so a plain ./scripts/testflight.sh still works.
# Or: with-asc ./scripts/testflight.sh
if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  ASC_ENV="${ASC_ENV:-$HOME/.config/op/env/asc.env}"
  if command -v op >/dev/null 2>&1 && [[ -r "$ASC_ENV" ]]; then
    # Resolve $0 before any cd in this script could break a relative path.
    _self="${BASH_SOURCE[0]:-$0}"
    if [[ "${_self}" != /* ]]; then
      _self="$(cd "$(dirname "${_self}")" && pwd)/$(basename "${_self}")"
    fi
    exec op run --env-file="$ASC_ENV" -- "$_self" "$@"
  fi
fi

AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  AUTH_ARGS=(
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"
  )
fi

if pgrep -fl xcodebuild | grep -q "$PWD"; then
  echo "error: an xcodebuild is already running in this checkout. Wait for it." >&2
  exit 1
fi

echo "──> Nutrition → TestFlight   build $BUILD_NUMBER   ($(git rev-parse --short HEAD))"
echo

echo "──> archiving (2–5 min)"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

# ---------------------------------------------------------------------------
# Archive guards
# ---------------------------------------------------------------------------
# Everything below fails ONLY after upload if it is not checked here: the
# build is clean, the tests pass, and the app installs and runs on the phone.
# Each of these has cost a real ship. Checking the archive itself — not the
# sources that produced it — is the point; the archive is what Apple sees.
APP_PATH="$ARCHIVE/Products/Applications/Nutrition.app"

# 1. The app icon. An archive whose icon was stripped archives cleanly and is
#    auto-rejected after upload.
if ! ls "$APP_PATH" | grep -q "Assets.car"; then
  echo "error: the archived app has no Assets.car — the app icon was stripped." >&2
  echo "       Check that Assets.xcassets is NOT under 'Preview Content'." >&2
  exit 1
fi

# 2. The theme colours — a DIFFERENT failure from the icon. Both live in the
#    same compiled catalogue, so an archive that lost every colorset still
#    has an Assets.car and sails past the check above. The colorsets sat
#    under "Preview Content" until 2026-09-06, stripped from every archive,
#    while the phone build (a Release BUILD, never an archive) looked perfect.
if [[ -x /usr/bin/assetutil ]]; then
  CAR_NAMES="$(/usr/bin/assetutil --info "$APP_PATH/Assets.car" 2>/dev/null || true)"
  for colour in BlueYellow BlackWhite Manual; do
    if ! grep -q "\"$colour\"" <<<"$CAR_NAMES"; then
      echo "error: the archived Assets.car has no '$colour' colorset." >&2
      echo "       Theme colours must live in nutrition/Assets.xcassets. Under" >&2
      echo "       'Preview Content' they are stripped from the archive only," >&2
      echo "       so the app ships colourless and nothing local shows it." >&2
      exit 1
    fi
  done
fi

# 3. The purpose strings the embedded entitlements make mandatory. Validation
#    keys off the ENTITLEMENT, not the API calls, so "the app never writes to
#    HealthKit" is not a reason for NSHealthUpdateUsageDescription to be
#    missing. Removing it on exactly that reasoning failed an upload on
#    2026-09-06, after a clean build and a green suite.
if codesign -d --entitlements - --xml "$APP_PATH" 2>/dev/null | grep -q "com.apple.developer.healthkit"; then
  for key in NSHealthShareUsageDescription NSHealthUpdateUsageDescription; do
    if ! /usr/libexec/PlistBuddy -c "Print :$key" "$APP_PATH/Info.plist" >/dev/null 2>&1; then
      echo "error: the archive carries the HealthKit entitlement but no $key." >&2
      echo "       App Store validation rejects that at upload. Add" >&2
      echo "       INFOPLIST_KEY_$key to project.yml." >&2
      exit 1
    fi
  done
fi

if [[ $UPLOAD -eq 0 ]]; then
  echo "──> exporting .ipa only (--no-upload)"
  rm -rf "$EXPORT_DIR"
  # ExportOptions.plist declares `destination: upload`, so reusing it here
  # would ship the build — the exact thing --no-upload exists to prevent.
  # Export from a copy with that one key flipped.
  TMP_OPTIONS="$(mktemp -t exportoptions)"
  cp "$OPTIONS" "$TMP_OPTIONS"
  plutil -replace destination -string export "$TMP_OPTIONS"
  trap 'rm -f "$TMP_OPTIONS"' EXIT
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$TMP_OPTIONS" \
    -allowProvisioningUpdates \
    ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}
  echo
  echo "Done — .ipa in $EXPORT_DIR (not uploaded)."
  exit 0
fi

: "${ASC_KEY_ID:?set ASC_KEY_ID — see the credentials note at the top of this script}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID — see the credentials note at the top of this script}"

echo "──> exporting + uploading to App Store Connect"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}

echo
echo "Uploaded build $BUILD_NUMBER."
echo "It lands in TestFlight after ~5–15 min of Apple-side processing."
