#!/usr/bin/env bash
# Runs a hook script with whichever Python this machine has.
# Windows (Git Bash): the `py` launcher. `python3` there is often the
# Microsoft Store stub, which prints nothing and exits 9009, so every hook
# would silently not run. Cloud / Linux: python3.
# exec keeps stdin (the hook's JSON) and the exit code (2 = block) intact.
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/$1"
shift
if command -v py >/dev/null 2>&1; then
  exec py -3 "$script" "$@"
elif command -v python3 >/dev/null 2>&1 && python3 -c "" >/dev/null 2>&1; then
  exec python3 "$script" "$@"
else
  exec python "$script" "$@"
fi
