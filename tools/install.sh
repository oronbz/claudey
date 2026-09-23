#!/usr/bin/env bash
# Build Shepherd and install him on this Mac: the app into ~/Applications and
# the Herdr plugin linked from this checkout. Re-running replaces only what a
# previous run installed. Herdr's own config, other plugins and everything
# under ~/.claude are never touched.
#
# Prerequisites: macOS 26.6 or newer, Xcode 27 (xcodebuild on PATH),
# Herdr 0.8 or newer (herdr on PATH), Ghostty for click-to-terminal.
#
#   SHEPHERD_INSTALL_DIR    where Shepherd.app goes (default ~/Applications)
#   SHEPHERD_CONFIGURATION  Release (default) or Debug
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/tools/lib/shepherd-install.sh"
configuration="${SHEPHERD_CONFIGURATION:-Release}"
install_dir="${SHEPHERD_INSTALL_DIR:-$HOME/Applications}"
derived_data="$repo/.build/DerivedData"
app="$install_dir/Shepherd.app"

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

echo "building Shepherd ($configuration)"
xcodebuild -project "$repo/Shepherd/Shepherd.xcodeproj" -scheme Shepherd -configuration "$configuration" \
  -derivedDataPath "$derived_data" -quiet build
built="$derived_data/Build/Products/$configuration/Shepherd.app"
[ -d "$built" ] || { echo "build produced no app at $built" >&2; exit 1; }

quit_shepherd

echo "installing $app"
mkdir -p "$install_dir"
rm -rf "$app"
ditto "$built" "$app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$lsregister" ] && "$lsregister" -f "$app" > /dev/null 2>&1 || true

echo "linking the Herdr plugin from $repo/plugin"
herdr plugin link "$repo/plugin" > /dev/null
config_dir="$(herdr plugin config-dir shepherd)"
mkdir -p "$config_dir"
printf '%s\n' "$app" > "$config_dir/app-path"

echo "starting Shepherd"
if ! herdr plugin action invoke connect --plugin shepherd > /dev/null 2>&1; then
  SHEPHERD_APP="$app" bash "$repo/plugin/shepherd-connect.sh" --connect
fi

cat <<MSG
Shepherd is installed. He starts with each Herdr session through the plugin's
startup hook, and the "Connect Shepherd" action wakes him at any time.
Right-click him to pick his avatar, connect to or disconnect from Herdr, or
quit. Remove him with tools/uninstall.sh.
MSG
