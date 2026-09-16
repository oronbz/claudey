#!/usr/bin/env bash
# Remove what tools/install.sh put on this Mac: the running app, its login
# item, the Herdr plugin link, the app bundle, and Claudey's own preferences
# and support files. Herdr's config, other plugins and ~/.claude stay as they
# are; the build products under .build/ in this checkout are kept too.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/tools/lib/claudey-install.sh"
install_dir="${CLAUDEY_INSTALL_DIR:-$HOME/Applications}"
support_dir="$HOME/Library/Application Support/Claudey"

app="$install_dir/Claudey.app"
config_dir=""
if claudey_plugin_linked; then
  config_dir="$(herdr plugin config-dir claudey)"
  if [ -r "$config_dir/app-path" ]; then
    app="$(head -n 1 "$config_dir/app-path")"
  fi
fi
case "$app" in
  */Claudey.app) ;;
  *) echo "refusing to remove '$app': not a Claudey.app bundle" >&2; exit 1 ;;
esac

quit_claudey

if [ -d "$app" ]; then
  echo "turning launch at login off"
  open -W -g -a "$app" --args --disable-launch-at-login || echo "could not launch $app to disable launch at login; check System Settings > Login Items" >&2
fi

if claudey_plugin_linked; then
  echo "unlinking the Herdr plugin"
  herdr plugin unlink claudey > /dev/null || echo "could not unlink the plugin; run: herdr plugin unlink claudey" >&2
fi

echo "removing $app, preferences and support files"
rm -rf "$app"
rm -rf "$support_dir"
[ -n "$config_dir" ] && rm -rf "$config_dir"
defaults delete "$bundle_id" > /dev/null 2>&1 || true
tccutil reset AppleEvents "$bundle_id" > /dev/null 2>&1 || true

cat <<MSG
Claudey is gone. Left untouched: Herdr's config and other plugins, ~/.claude,
Ghostty, and this checkout (delete the folder and .build/ yourself).
MSG
