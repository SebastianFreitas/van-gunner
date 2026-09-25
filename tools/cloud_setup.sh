#!/usr/bin/env bash
# Installs Godot 4.7 stable for a van-gunner cloud session (Ubuntu x86_64), so that
# `python3 tools/check.py`, `smoke.py` and `scene_dump.py` can run headless there.
#
# Point the cloud environment's "Setup script" field at:  bash tools/cloud_setup.sh
# The three tools look for `godot` on PATH (then ~/.local/bin/godot) when GODOT is
# unset, so no environment variable is needed. Safe to re-run: it exits early when a
# matching Godot is already installed. Set GODOT_INSTALL_DIR to install elsewhere.
set -euo pipefail

VERSION="4.7-stable"
ZIP="Godot_v${VERSION}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ZIP}"
# From SHA512-SUMS.txt on the same release page. Bump it together with VERSION.
SHA512="b639ca9c1ddea39bb3df89bd5283a51ca6047467abe6b25e9436566f2b2082ede633025073989ecf39c7d5d3c2493d80ea13e3af6dd5e261bbf89e462d6d2214"

if [ "$(uname -m)" != "x86_64" ]; then
	echo "cloud_setup: this script downloads the x86_64 Linux build; $(uname -m) needs another URL" >&2
	exit 1
fi

if command -v godot >/dev/null 2>&1 && godot --headless --version 2>/dev/null | grep -q "^4\.7\.stable"; then
	echo "cloud_setup: $(command -v godot) is already Godot $(godot --headless --version)"
	exit 0
fi

if [ -n "${GODOT_INSTALL_DIR:-}" ]; then
	install_dir="$GODOT_INSTALL_DIR"
elif [ -w /usr/local/bin ]; then
	install_dir="/usr/local/bin"
else
	install_dir="$HOME/.local/bin"
fi
mkdir -p "$install_dir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "cloud_setup: downloading $URL"
curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/$ZIP" "$URL"

echo "$SHA512  $tmp/$ZIP" | sha512sum -c --quiet -
echo "cloud_setup: checksum ok"

# python3 is always present in the container; unzip is not guaranteed.
python3 - "$tmp/$ZIP" "$tmp/out" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
binary="$(find "$tmp/out" -maxdepth 1 -type f -name 'Godot_v*' | head -n 1)"
if [ -z "$binary" ]; then
	echo "cloud_setup: no Godot binary inside $ZIP" >&2
	exit 1
fi
install -m 0755 "$binary" "$install_dir/godot"

echo "cloud_setup: installed $install_dir/godot"
"$install_dir/godot" --headless --version
case ":$PATH:" in
	*":$install_dir:"*) ;;
	*) echo "cloud_setup: note: $install_dir is not on PATH; the tools still find ~/.local/bin/godot, or set GODOT=$install_dir/godot" ;;
esac
