#!/usr/bin/env bash
# Build the app and publish the .ipa as a GitHub release.
#
# The ipa is unsigned: xtool signs only when installing to a device, so whoever
# installs this has to sign it themselves (iLoader, Sideloadly, or `xtool dev`).
set -euo pipefail

version="${1:-}"
if [[ -z "$version" ]]; then
    echo "usage: Tools/release.sh v1.2.3 [notes]" >&2
    exit 1
fi
notes="${2:-Build of $(git rev-parse --short HEAD).}"

cd "$(dirname "$0")/.."
xtool dev build --ipa
ipa="xtool/TVRemote.ipa"
[[ -f "$ipa" ]] || { echo "no ipa at $ipa" >&2; exit 1; }

# Name the asset after the tag so downloads are distinguishable.
asset="TVRemote-${version}.ipa"
cp "$ipa" "$asset"
trap 'rm -f "$asset"' EXIT

gh release create "$version" "$asset" --title "$version" --notes "$notes"
