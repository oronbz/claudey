#!/usr/bin/env bash
# Drive Claudey with two real Claude Code sessions inside the current Herdr tab.
# Run from a Herdr pane while Claudey is running. Closes both demo panes at the
# end unless KEEP_PANES=1.
set -euo pipefail
source "$(dirname "$0")/lib/herdr-demo.sh"
require_herdr_env

a="${1:-claudey-demo-a}"
b="${2:-claudey-demo-b}"
timeout_ms=180000
long_task="Without using any tools, write 40 numbered lines, each a different short haiku about the sea."
question="Use the AskUserQuestion tool to ask me whether I prefer red or blue. Offer only those two options and do nothing else."

say() { printf '%s %s\n' "$(date +%T)" "$*"; }
wait_for() { "$herdr" agent wait "$1" --until "$2" --timeout "${3:-$timeout_ms}" > /dev/null; }
prompt() { "$herdr" agent prompt "$1" "$2" > /dev/null; }
prompt_until() { "$herdr" agent prompt "$1" "$2" --wait --until "$3" --timeout "$timeout_ms" > /dev/null; }
answer() { "$herdr" agent send-keys "$1" enter > /dev/null; }

pane_a="$(split_pane)"
pane_b="$(split_pane)"
say "demo panes: $a=$pane_a $b=$pane_b"
start_agent "$a" "$pane_a"
start_agent "$b" "$pane_b"
sleep 3
say "both sessions idle: Claudey should show the aggregate of everything else Herdr runs"

say "1/4 completion while another works: expect concentration, one hop when $b answers, then concentration again"
prompt "$a" "$long_task"
wait_for "$a" working 30000
sleep 2
prompt_until "$b" "Reply with exactly this sentence and nothing else: Hello from demo B." idle
say "    $b finished while $a is $(agent_status "$a")"
wait_for "$a" idle
say "    $a finished: one more hop, then idle"
sleep 4

say "2/4 needs-you over working: expect a wave, then the held pose while $a keeps working; $a finishing stays hidden"
prompt "$a" "$long_task"
wait_for "$a" working 30000
sleep 2
prompt_until "$b" "$question" blocked
say "    $b is blocked while $a is $(agent_status "$a")"
wait_for "$a" idle
say "    $a finished behind the pose: no hop expected; a click now goes to $b"
sleep 4
answer "$b"
wait_for "$b" idle
say "    $b answered: concentration, one hop, then idle"
sleep 4

say "3/4 overlapping questions: expect one wave and a pose that stays; a click goes to $a until it is answered, then to $b"
prompt_until "$a" "$question" blocked
sleep 2
prompt_until "$b" "$question" blocked
say "    both blocked; the pose points at $a"
sleep 4
answer "$a"
wait_for "$a" idle
say "    $a answered: pose stays for $b, no hop"
sleep 4
answer "$b"
wait_for "$b" idle
say "    $b answered: one hop, then idle"
sleep 4

say "4/4 removal: closing both panes returns him to the aggregate of the remaining sessions, without a hop"
if [ "${KEEP_PANES:-}" = 1 ]; then
  say "    KEEP_PANES=1: close them with: $herdr pane close $pane_a; $herdr pane close $pane_b"
else
  "$herdr" pane close "$pane_a" > /dev/null
  "$herdr" pane close "$pane_b" > /dev/null
  say "    panes closed"
fi
