#!/bin/zsh
# mac-install.sh — build the Mac Catalyst app and install it to /Applications.
#
#   scripts/mac-install.sh
#
# The Mac counterpart of the install-to-phone skill: after it runs, Nutrition
# is in /Applications and launches from Spotlight or the Dock with Xcode quit.
#
# Every line here is a fact that cost something, so none of them are optional:
#
#   * DEVELOPER_DIR — xcode-select on this machine points at the Command Line
#     Tools, so a bare xcodebuild fails outright (AGENTS.md).
#   * -configuration Release, because the scheme's Run config is Debug/-Onone
#     and this app is meant to be used, not demoed.
#   * build/DDcat, never build/DD: that path is the phone build's, and two
#     xcodebuilds on one build database deadlock with "database is locked".
#   * NO -allowProvisioningUpdates. The Mac entitlements file is empty on
#     purpose (Signing/nutrition-macCatalyst.entitlements), so nothing here is
#     profile-backed and the bare "Apple Development" certificate signs it.
#     If this ever starts demanding a profile, something re-added HealthKit to
#     the Mac side — fix that, don't paper over it with CODE_SIGNING_ALLOWED=NO,
#     which yields a build receipt rather than an installable app.
#   * The product path is read back from -showBuildSettings rather than
#     hardcoded — the Release-maccatalyst suffix is Xcode's business, and a
#     wrong guess silently installs a stale bundle.
#   * ditto, never cp -R: it preserves the xattrs and signature metadata that
#     decide whether the copy in /Applications still validates.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DD="$REPO/build/DDcat"
DEST='platform=macOS,variant=Mac Catalyst'
APP=/Applications/Nutrition.app

cd "$REPO"

echo "==> xcodegen generate"
xcodegen generate

echo "==> build (Release, Mac Catalyst) -> $DD"
xcodebuild -project "$REPO/nutrition.xcodeproj" -scheme nutrition \
  -configuration Release -destination "$DEST" \
  -derivedDataPath "$DD" build

echo "==> resolve BUILT_PRODUCTS_DIR"
# No `exit` inside the awk: BUILT_PRODUCTS_DIR sorts near the top of a long
# dump, so closing the pipe early kills xcodebuild with SIGPIPE, the command
# substitution inherits 141, and `set -e` aborts at the assignment — before
# the :? guard below can ever print. Read the whole dump, keep the last match.
BUILT_PRODUCTS_DIR="$(xcodebuild -project "$REPO/nutrition.xcodeproj" -scheme nutrition \
  -configuration Release -destination "$DEST" \
  -derivedDataPath "$DD" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *BUILT_PRODUCTS_DIR = /{v=$2} END{if (v != "") print v}')"
: "${BUILT_PRODUCTS_DIR:?could not read BUILT_PRODUCTS_DIR from -showBuildSettings}"

PRODUCT="$BUILT_PRODUCTS_DIR/Nutrition.app"
[[ -d "$PRODUCT" ]] || { echo "no product at $PRODUCT" >&2; exit 1; }
echo "    $PRODUCT"

echo "==> install -> $APP"
rm -rf "$APP"
ditto "$PRODUCT" "$APP"

echo
echo "==> receipts"
codesign --verify --strict --verbose=2 "$APP"
echo "--- entitlements (empty dict + get-task-allow is the expected answer)"
codesign -d --entitlements - "$APP" 2>&1 | tail -n +2
echo "--- bundle id (must be com.claussen.nutrition, NOT maccatalyst.*, or the"
echo "    Mac gets its own empty UserDefaults store)"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"

echo
echo "Installed. Launch it with Xcode quit:  open -a Nutrition"
