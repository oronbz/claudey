#!/usr/bin/env bash

cask="oronbz/tap/shepherd"

find_brew() {
  command -v brew && return 0
  local candidate
  while IFS= read -r -d : candidate; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <<< "${SHEPHERD_BREW_FALLBACKS-/opt/homebrew/bin/brew:/usr/local/bin/brew}:"
  cat >&2 <<MSG
Shepherd installs through Homebrew, which was not found on PATH or in its
standard locations. Install Homebrew from https://brew.sh, then run this again.
MSG
  return 1
}
