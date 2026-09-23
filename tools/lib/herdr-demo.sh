#!/usr/bin/env bash
# Shared helpers for the Shepherd live demos. Source from a script run inside Herdr.

herdr="${HERDR_BIN_PATH:-herdr}"

require_herdr_env() {
  if [ "${HERDR_ENV:-}" != 1 ]; then
    echo "run this from a pane inside Herdr" >&2
    exit 1
  fi
}

json_field() {
  python3 -c 'import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1:]:
    value = value[int(key)] if isinstance(value, list) else value[key]
print(value)' "$@"
}

split_pane() {
  "$herdr" pane split --current --direction down --cwd "$PWD" --no-focus | json_field result pane pane_id
}

start_agent() {
  local name="$1" pane="$2" attempt errors
  errors="$(mktemp)"
  for attempt in $(seq 1 10); do
    if "$herdr" agent start "$name" --kind claude --pane "$pane" > /dev/null 2> "$errors"; then
      rm -f "$errors"
      return
    fi
    if [ "$attempt" = 10 ]; then
      cat "$errors" >&2
      rm -f "$errors"
      exit 1
    fi
    sleep 1
  done
}

agent_status() { "$herdr" agent get "$1" | json_field result agent agent_status; }
