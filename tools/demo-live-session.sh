#!/usr/bin/env bash
# Drive Shepherd with one real Claude Code session inside the current Herdr tab.
# Run from a Herdr pane while Shepherd is running. Leaves the demo pane open so
# the needs-you question can be answered by hand; close it with the printed command.
set -euo pipefail
source "$(dirname "$0")/lib/herdr-demo.sh"
require_herdr_env

name="${1:-shepherd-demo}"

pane="${SHEPHERD_DEMO_PANE:-}"
if [ -z "$pane" ]; then
  pane="$(split_pane)"
fi
echo "demo pane: $pane"

echo "starting Claude Code as '$name' (Shepherd should stay idle: a fresh session has nothing to report)"
start_agent "$name" "$pane"

echo "1/3 working then finished: expect concentration, then one hop back to idle"
"$herdr" agent prompt "$name" "Reply with exactly this sentence and nothing else: Hello from the Shepherd demo." \
  --wait --timeout 120000 > /dev/null

echo "2/3 needs-you: expect a wave, then the held questioning pose"
"$herdr" agent prompt "$name" "Use the AskUserQuestion tool to ask me whether I prefer red or blue. Offer only those two options and do nothing else." \
  --wait --until blocked --timeout 120000 > /dev/null

echo "3/3 answer the question in pane $pane: expect work, then a hop, then idle"
echo "when done: $herdr pane close $pane"
