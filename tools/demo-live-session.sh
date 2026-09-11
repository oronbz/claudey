#!/usr/bin/env bash
# Drive Claudey with one real Claude Code session inside the current Herdr tab.
# Run from a Herdr pane while Claudey is running. Leaves the demo pane open so
# the needs-you question can be answered by hand; close it with the printed command.
set -euo pipefail

if [ "${HERDR_ENV:-}" != 1 ]; then
  echo "run this from a pane inside Herdr" >&2
  exit 1
fi

herdr="${HERDR_BIN_PATH:-herdr}"
name="${1:-claudey-demo}"

pane="${CLAUDEY_DEMO_PANE:-}"
if [ -z "$pane" ]; then
  pane="$("$herdr" pane split --current --direction down --cwd "$PWD" --no-focus \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')"
fi
echo "demo pane: $pane"

echo "starting Claude Code as '$name' (Claudey should stay idle: a fresh session has nothing to report)"
for attempt in $(seq 1 10); do
  if "$herdr" agent start "$name" --kind claude --pane "$pane" > /dev/null 2> /tmp/claudey-demo-start.err; then
    break
  fi
  if [ "$attempt" = 10 ]; then
    cat /tmp/claudey-demo-start.err >&2
    exit 1
  fi
  sleep 1
done

echo "1/3 working then finished: expect concentration, then one hop back to idle"
"$herdr" agent prompt "$name" "Reply with exactly this sentence and nothing else: Hello from the Claudey demo." \
  --wait --timeout 120000 > /dev/null

echo "2/3 needs-you: expect a wave, then the held questioning pose"
"$herdr" agent prompt "$name" "Use the AskUserQuestion tool to ask me whether I prefer red or blue. Offer only those two options and do nothing else." \
  --wait --until blocked --timeout 120000 > /dev/null

echo "3/3 answer the question in pane $pane: expect work, then a hop, then idle"
echo "when done: $herdr pane close $pane"
