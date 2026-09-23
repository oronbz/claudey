#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/shepherd-brew.sh"
brew="$(find_brew)"

verb=install
"$brew" list --cask "$cask" > /dev/null 2>&1 && verb=upgrade
echo "running $brew $verb --cask $cask"
"$brew" "$verb" --cask "$cask"

echo 'Shepherd is ready. He starts with each Herdr session, and the "Connect Shepherd" action wakes him at any time.'
if [ "$verb" = install ]; then
  echo "macOS blocks his first launch: approve him under System Settings > Privacy & Security > Open Anyway."
fi
