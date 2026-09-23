#!/usr/bin/env bash
# Herdr startup hook and action: record this session's socket for the
# companion, then start him or nudge the running copy to re-read it.
# One-shot by design; the app owns its own lifecycle and reconnects itself.
# `--connect` (the Connect Shepherd action) also overrides a disconnect the
# owner chose from his menu; the startup hook leaves that choice alone.
set -euo pipefail

socket_path="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
support_dir="$HOME/Library/Application Support/Shepherd"
context_file="$support_dir/herdr-connection.json"

json_string() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

mkdir -p "$support_dir"
tmp_file="$(mktemp "$support_dir/.herdr-connection.XXXXXX")"
printf '{"socket_path":%s}\n' "$(json_string "$socket_path")" > "$tmp_file"
mv -f "$tmp_file" "$context_file"
if [ "${1:-}" = "--connect" ]; then
  : > "$support_dir/connect-request"
fi

app_path="${SHEPHERD_APP:-}"
if [ -z "$app_path" ] && [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ] && [ -r "$HERDR_PLUGIN_CONFIG_DIR/app-path" ]; then
  app_path="$(head -n 1 "$HERDR_PLUGIN_CONFIG_DIR/app-path")"
fi

# `open -g` launches without bringing the app forward; for a running copy it
# only delivers a reopen, so a second activation never spawns a second Shepherd.
if [ -n "$app_path" ]; then
  open -g -a "$app_path" && exit 0
else
  open -g -b com.oronbz.Shepherd && exit 0
fi
rm -f "$support_dir/connect-request"
exit 1
