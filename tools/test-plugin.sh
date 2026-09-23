#!/usr/bin/env bash
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$repo/plugin"
manifest_sum="$(shasum -a 256 "$plugin/herdr-plugin.toml")"
failures=0
work=""

cleanup() { [ -z "$work" ] || rm -rf "$work"; }
trap cleanup EXIT

new_case() {
  cleanup
  work="$(mktemp -d)"
  mkdir -p "$work/home" "$work/bin" "$work/prefix/bin"
  fallbacks="$work/prefix/bin/brew"
  cat > "$work/bin/open" <<FAKE
#!/bin/bash
printf '%s\n' "\$*" >> "$work/open.log"
[ ! -e "$work/open-fails" ]
FAKE
  chmod +x "$work/bin/open"
}

fake_brew() {
  local path="$1"
  cat > "$path" <<FAKE
#!/bin/bash
printf '%s\n' "\$*" >> "$work/brew.log"
case "\$1" in
  list) [ -e "$work/installed" ] ;;
  *)
    if [ -e "$work/fail" ]; then
      echo "Error: Download failed on Cask 'shepherd'" >&2
      exit 1
    fi
    ;;
esac
FAKE
  chmod +x "$path"
}

run_plugin() {
  (cd "$plugin" && env -i HOME="$work/home" PATH="$work/bin:/usr/bin:/bin" \
    SHEPHERD_BREW_FALLBACKS="$fallbacks" bash "$@") > "$work/out" 2>&1
  status=$?
}

brew_issued() { [ -e "$work/brew.log" ] && grep -qxF -- "$1" "$work/brew.log"; }
brew_not_issued() { ! brew_issued "$1"; }
started() {
  [ -e "$work/open.log" ] && grep -qxF -- "-g -b com.oronbz.Shepherd" "$work/open.log" &&
    grep -qF "$work/home/.config/herdr/herdr.sock" "$work/home/Library/Application Support/Shepherd/herdr-connection.json"
}
not_started() { [ ! -e "$work/open.log" ]; }

check() {
  local name="$1" ok=1
  shift
  "$@" || ok=0
  if [ "$ok" = 1 ]; then
    echo "  ok: $name"
  else
    echo "  FAIL: $name"
    sed 's/^/    | /' "$work/out"
    [ ! -e "$work/brew.log" ] || sed 's/^/    brew /' "$work/brew.log"
    failures=$((failures + 1))
  fi
}

manifest_unchanged() { [ "$(shasum -a 256 "$plugin/herdr-plugin.toml")" = "$manifest_sum" ]; }

echo "build: no Homebrew"
new_case
run_plugin shepherd-install-app.sh
check "exits non-zero" [ "$status" -ne 0 ]
check "points to Homebrew" grep -q "https://brew.sh" "$work/out"
check "issues no brew commands" [ ! -e "$work/brew.log" ]
check "does not start him" not_started

echo "build: cask not installed"
new_case
fake_brew "$work/bin/brew"
run_plugin shepherd-install-app.sh
check "succeeds" [ "$status" -eq 0 ]
check "installs the cask from the tap" brew_issued "install --cask oronbz/tap/shepherd"
check "does not upgrade" brew_not_issued "upgrade --cask oronbz/tap/shepherd"
check "starts him on the default Herdr socket" started

echo "build: cask already installed"
new_case
fake_brew "$work/bin/brew"
touch "$work/installed"
run_plugin shepherd-install-app.sh
check "succeeds" [ "$status" -eq 0 ]
check "upgrades the cask" brew_issued "upgrade --cask oronbz/tap/shepherd"
check "does not install" brew_not_issued "install --cask oronbz/tap/shepherd"
check "starts him again" started

echo "build: brew only in a standard prefix"
new_case
fake_brew "$work/prefix/bin/brew"
run_plugin shepherd-install-app.sh
check "succeeds" [ "$status" -eq 0 ]
check "installs the cask from the tap" brew_issued "install --cask oronbz/tap/shepherd"

echo "build: brew install fails"
new_case
fake_brew "$work/bin/brew"
touch "$work/fail"
run_plugin shepherd-install-app.sh
check "exits non-zero" [ "$status" -ne 0 ]
check "shows Homebrew's error" grep -q "Download failed" "$work/out"
check "does not start him" not_started

echo "build: brew upgrade fails"
new_case
fake_brew "$work/bin/brew"
touch "$work/installed" "$work/fail"
run_plugin shepherd-install-app.sh
check "exits non-zero" [ "$status" -ne 0 ]
check "shows Homebrew's error" grep -q "Download failed" "$work/out"

echo "build: starting him fails"
new_case
fake_brew "$work/bin/brew"
touch "$work/open-fails"
run_plugin shepherd-install-app.sh
check "still succeeds" [ "$status" -eq 0 ]
check "says how to start him" grep -q "did not start; run the \"Connect Shepherd\" action" "$work/out"

check "the manifest is unchanged" manifest_unchanged

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
