"""The project's .claude/project/file-guard.json, shared by the hooks that
read it (file-guard, session-start, git-guard, review-guard). Not a hook
itself: hooks.py never runs it. Keys are documented in file-guard.py;
this file only loads them and matches globs. It also holds the raw-mode
flag check (raw-mode.py sets the flag).

Globs are fnmatch (case-sensitive) on the forward-slash root-relative
path, where `*` also crosses `/`.
"""
import fnmatch
import json
import os

CONFIG_PATH = ".claude/project/file-guard.json"


def raw_flag(transcript_path: str) -> str:
    """Path of this window's raw-mode flag. A new transcript (/clear, a new
    chat) has no flag, so raw mode ends with the window."""
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        p = os.path.dirname(os.path.dirname(p))
    else:
        p = os.path.splitext(p)[0]
    return os.path.join(p, "raw-mode")


def raw_mode(transcript_path: str | None) -> bool:
    return bool(transcript_path) and os.path.exists(raw_flag(transcript_path))


def load_config(root: str) -> dict:
    # Missing or bad JSON means no config.
    try:
        with open(os.path.join(root, CONFIG_PATH), encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}
    return cfg if isinstance(cfg, dict) else {}


def generated_globs(cfg: dict) -> list[str]:
    return [str(e.get("glob", "")) for e in cfg.get("generated") or []
            if isinstance(e, dict) and e.get("glob")]


def quiet_globs(cfg: dict) -> list[str]:
    return [str(g) for g in cfg.get("quiet_dirty") or [] if g]


def matches_any(rel: str, globs: list[str]) -> bool:
    rel = rel.replace("\\", "/")
    return any(fnmatch.fnmatchcase(rel, g) for g in globs)


def quiet_line(n: int, globs: list[str]) -> str:
    return f"{n} files matching {', '.join(globs)} changed (not listed)"


SOURCE_SUFFIXES = {
    ".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".css", ".scss",
    ".html", ".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".cs",
    ".cfg", ".sh",
}


def source_rule(cfg: dict) -> tuple[set[str], list[str]]:
    """(suffixes, exact paths) that count as source: `source_suffixes`
    replaces the default set, `source_files` adds paths."""
    suffixes = SOURCE_SUFFIXES
    if "source_suffixes" in cfg:
        suffixes = {s.lower() for s in cfg["source_suffixes"] or []}
    return suffixes, list(cfg.get("source_files") or [])


def map_rule(root: str, cfg: dict) -> tuple[str, bool] | None:
    """(map path, generated) from the `map` key, default .claude/MAP.md
    hand-written; None when the map file does not exist."""
    m = cfg.get("map") if isinstance(cfg.get("map"), dict) else {}
    path = str(m.get("path") or ".claude/MAP.md")
    if not os.path.isfile(os.path.join(root, path)):
        return None
    return path, bool(m.get("generated"))
