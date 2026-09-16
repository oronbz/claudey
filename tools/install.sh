#!/usr/bin/env bash
# Build Claudey and install him on this Mac: the app into ~/Applications and
# the Herdr plugin linked from this checkout. Re-running replaces only what a
# previous run installed. Herdr's own config, other plugins and everything
# under ~/.claude are never touched.
#
# Prerequisites: macOS 26.6 or newer, Xcode 27 (xcodebuild on PATH),
# Herdr 0.8 or newer (herdr on PATH), Ghostty for click-to-terminal.
#
#   CLAUDEY_INSTALL_DIR    where Claudey.app goes (default ~/Applications)
#   CLAUDEY_CONFIGURATION  Release (default) or Debug
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/tools/lib/claudey-install.sh"
configuration="${CLAUDEY_CONFIGURATION:-Release}"
install_dir="${CLAUDEY_INSTALL_DIR:-$HOME/Applications}"
derived_data="$repo/.build/DerivedData"
app="$install_dir/Claudey.app"

need() {
  command -v "$1" > /dev/null 2>&1 || { echo "missing $1: $2" >&2; exit 1; }
}

version_at_least() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

need xcodebuild "install Xcode 27 or newer and run xcode-select -s /Applications/Xcode.app"
need herdr "install Herdr 0.8 or newer from https://herdr.dev"
os_version="$(sw_vers -productVersion)"
version_at_least "$os_version" 26.6 || { echo "macOS 26.6 or newer required, found $os_version" >&2; exit 1; }
herdr_version="$(herdr --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
[ -n "$herdr_version" ] || { echo "could not read the Herdr version from 'herdr --version'" >&2; exit 1; }
version_at_least "$herdr_version" 0.8.0 || { echo "Herdr 0.8.0 or newer required, found $herdr_version" >&2; exit 1; }

echo "building Claudey ($configuration)"
xcodebuild -project "$repo/Claudey/Claudey.xcodeproj" -scheme Claudey -configuration "$configuration" \
  -derivedDataPath "$derived_data" -quiet build
built="$derived_data/Build/Products/$configuration/Claudey.app"
[ -d "$built" ] || { echo "build produced no app at $built" >&2; exit 1; }

quit_claudey

echo "installing $app"
mkdir -p "$install_dir"
rm -rf "$app"
ditto "$built" "$app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$lsregister" ] && "$lsregister" -f "$app" > /dev/null 2>&1 || true

echo "linking the Herdr plugin from $repo/plugin"
herdr plugin link "$repo/plugin" > /dev/null
config_dir="$(herdr plugin config-dir claudey)"
mkdir -p "$config_dir"
printf '%s\n' "$app" > "$config_dir/app-path"

echo "starting Claudey"
if ! herdr plugin action invoke connect --plugin claudey > /dev/null 2>&1; then
  CLAUDEY_APP="$app" bash "$repo/plugin/claudey-connect.sh" --connect
fi

cat <<MSG
Claudey is installed. He starts with each Herdr session through the plugin's
startup hook, and the "Connect Claudey" action wakes him at any time.
Right-click him for Connect/Disconnect from Herdr, Launch at Login (off until
you turn it on) and Quit. Remove him with tools/uninstall.sh.
MSG
