"""The project's .claude/project/file-guard.json, shared by the hooks that
read it (file-guard, session-start, git-guard, review-guard). Not a hook
itself: hooks.py never runs it. Keys are documented in file-guard.py;
this file only loads them and matches globs.

Globs are fnmatch (case-sensitive) on the forward-slash root-relative
path, where `*` also crosses `/`.
"""
import fnmatch
import json
import os

CONFIG_PATH = ".claude/project/file-guard.json"


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
