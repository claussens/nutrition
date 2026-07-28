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
#   export ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=aaaaaaaa-....
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
# ~/.env is sourced from ~/.config/zsh/conf.d/90-secrets.zsh, which .zshrc
# loads for INTERACTIVE shells only — deliberately, so App Store credentials
# aren't ambient in every cron job on the machine. This script therefore cannot
# assume they are set: run from CI, a hook, or an agent's non-interactive
# shell, they won't be. Pick them up directly in that case.
if [[ -z "${ASC_KEY_ID:-}" && -r "$HOME/.env" ]]; then
  source "$HOME/.env"
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

# Guard the failure this app is specifically prone to: an archive whose icon
# was stripped still archives cleanly and is only rejected after upload.
if ! ls "$ARCHIVE/Products/Applications/Nutrition.app" | grep -q "Assets.car"; then
  echo "error: the archived app has no Assets.car — the app icon was stripped." >&2
  echo "       Check that Assets.xcassets is NOT under 'Preview Content'." >&2
  exit 1
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
