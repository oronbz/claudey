#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
project="$repo/Shepherd/Shepherd.xcodeproj"
manifest="$repo/plugin/herdr-plugin.toml"
out="$repo/.build/release"
derived_data="$out/DerivedData"
zip="$out/Shepherd.zip"

command -v xcodebuild > /dev/null 2>&1 || { echo "missing xcodebuild: install Xcode 27 or newer and run xcode-select -s /Applications/Xcode.app" >&2; exit 1; }

app_version="$(sed -nE 's/^[[:space:]]*MARKETING_VERSION = ([^;]+);$/\1/p' "$project/project.pbxproj" | sort -u)"
plugin_version="$(sed -nE 's/^version = "([^"]+)"$/\1/p' "$manifest")"
[ -n "$app_version" ] || { echo "could not read MARKETING_VERSION from the Xcode project" >&2; exit 1; }
[ "$(printf '%s\n' "$app_version" | wc -l)" -eq 1 ] || { echo "the Xcode project's targets disagree on MARKETING_VERSION:" $app_version >&2; exit 1; }
[ -n "$plugin_version" ] || { echo "could not read the version from $manifest" >&2; exit 1; }
if [ "$app_version" != "$plugin_version" ]; then
  echo "version mismatch: the app is $app_version but the plugin manifest is $plugin_version; make them match first" >&2
  exit 1
fi

echo "building Shepherd $app_version (Release)"
rm -rf "$out"
mkdir -p "$out"
xcodebuild -project "$project" -scheme Shepherd -configuration Release \
  -derivedDataPath "$derived_data" -quiet build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
built="$derived_data/Build/Products/Release/Shepherd.app"
[ -d "$built" ] || { echo "build produced no app at $built" >&2; exit 1; }
codesign --verify --deep --strict "$built"

ditto -c -k --sequesterRsrc --keepParent "$built" "$zip"
sha256="$(shasum -a 256 "$zip" | awk '{ print $1 }')"

cat <<MSG
version: $app_version
zip:     $zip
sha256:  $sha256

Next: tag v$app_version, publish a GitHub Release with the zip, then bump the
cask's version and sha256 in oronbz/tap (see docs/releasing.md).
MSG
