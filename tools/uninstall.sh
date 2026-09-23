#!/usr/bin/env bash
# Remove what tools/install.sh put on this Mac: the running app, the Herdr
# plugin link, the app bundle, and Shepherd's own preferences and support
# files. Herdr's config, other plugins and ~/.claude stay as they
# are; the build products under .build/ in this checkout are kept too.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/tools/lib/shepherd-install.sh"
install_dir="${SHEPHERD_INSTALL_DIR:-$HOME/Applications}"
support_dir="$HOME/Library/Application Support/Shepherd"

app="$install_dir/Shepherd.app"
config_dir=""
if shepherd_plugin_linked; then
  config_dir="$(herdr plugin config-dir shepherd)"
  if [ -r "$config_dir/app-path" ]; then
    app="$(head -n 1 "$config_dir/app-path")"
  fi
fi
case "$app" in
  */Shepherd.app) ;;
  *) echo "refusing to remove '$app': not a Shepherd.app bundle" >&2; exit 1 ;;
esac

quit_shepherd

if shepherd_plugin_linked; then
  echo "unlinking the Herdr plugin"
  herdr plugin unlink shepherd > /dev/null || echo "could not unlink the plugin; run: herdr plugin unlink shepherd" >&2
fi

echo "removing $app, preferences and support files"
rm -rf "$app"
rm -rf "$support_dir"
[ -n "$config_dir" ] && rm -rf "$config_dir"
defaults delete "$bundle_id" > /dev/null 2>&1 || true
tccutil reset AppleEvents "$bundle_id" > /dev/null 2>&1 || true

cat <<MSG
Shepherd is gone. Left untouched: Herdr's config and other plugins, ~/.claude,
Ghostty, and this checkout (delete the folder and .build/ yourself).
MSG
