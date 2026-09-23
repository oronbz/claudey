#!/usr/bin/env bash
# Shared helpers for tools/install.sh and tools/uninstall.sh.

bundle_id="com.oronbz.Shepherd"

quit_shepherd() {
  pgrep -xq Shepherd || return 0
  echo "quitting the running Shepherd"
  osascript -e "tell application id \"$bundle_id\" to quit" > /dev/null 2>&1 || pkill -x Shepherd || true
  for _ in $(seq 1 50); do
    pgrep -xq Shepherd || return 0
    sleep 0.2
  done
  echo "Shepherd is still running; quit him and try again" >&2
  return 1
}

shepherd_plugin_linked() {
  command -v herdr > /dev/null 2>&1 && herdr plugin list 2> /dev/null | grep -q '^- shepherd '
}
