"""GDScript / scene lint (PostToolUse on Write, Edit, MultiEdit, main session
and subagents): the file on disk already holds the tool's result, so this
just re-reads it and reports mistakes back to the model before they land -
it never runs Godot.

Two families of rule:
- Godot 3 and Python habits (onready/export/yield/setget/.instance()/
  KinematicBody/.../len()/None/def/True/False/...) are the most common
  mistakes an LLM makes writing GDScript, since both are close cousins of
  the language. Checked on edited lines only (L1-L4), so pre-existing code
  in a touched file never nags; a line is edited if it came from Write's
  `content`, Edit's `new_string`, or a MultiEdit edit's `new_string`.
- Whole-file checks that can't be scoped to a diff: the ## class summary
  right after extends/class_name that tools/gen_context.py reads (F1), the
  400-line hard cap (F2), autoloads never getting a class_name because
  that creates a parse cycle (F3), and for .tscn/.tres the "never renumber
  ids, remove ext_resources nothing references" rule - duplicate
  ext_resource/sub_resource ids, duplicate node unique_ids, dangling
  ExtResource/SubResource references, and unused ext_resource entries
  (T1-T4).

CLI: `py -3 .claude/hooks/gd-lint.py --scan [paths...]` lints every
git-tracked .gd/.tscn/.tres (or just the given paths) with every line
treated as edited, for auditing the whole tree; always exits 0.

Never fails the hook: any error exits 0.
"""
import json
import os
import re
import subprocess
import sys

LINT_EXTS = (".gd", ".tscn", ".tres")
MAX_ISSUES = 15

# Locating

def find_project_root(start_dir: str):
    d = os.path.abspath(start_dir)
    while True:
        if os.path.isfile(os.path.join(d, "project.godot")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def rel_posix(path: str, root: str) -> str:
    return os.path.relpath(path, root).replace("\\", "/")


# Edited lines (Write / Edit / MultiEdit)

def edited_hunks(tool_name: str, tool_input: dict) -> list:
    if tool_name == "Write":
        content = tool_input.get("content")
        return [content] if content is not None else []
    if tool_name == "Edit":
        new_string = tool_input.get("new_string")
        return [new_string] if new_string is not None else []
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        return [e.get("new_string", "") for e in edits if isinstance(e, dict)]
    return []


def numbered_lines(hunk: str, text: str) -> list:
    # locate the hunk inside the file to number its lines correctly; if it
    # can't be found (edge cases in how the tool reported it), number the
    # hunk from 1 and say so in the message
    idx = text.find(hunk)
    if idx != -1:
        start = text[:idx].count("\n") + 1
        prefix = ""
    else:
        start = 1
        prefix = "(in the edit) "
    return [(start + i, line, prefix) for i, line in enumerate(hunk.splitlines())]


# .gd line rules (L1-L4)

INDENT_RE = re.compile(r" +\S")
VAR_RE = re.compile(r"\s*(@\w+(\([^)]*\))?\s+)*(static\s+)?var\s+\w+\s*=(?!=)")
FUNC_RE = re.compile(r"\s*(static\s+)?func\s+\w+\s*\((.*)\)\s*(->\s*[^:]+)?:")
STRING_LITERAL_RE = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')

# Godot 3 and Python habits: checked on the line with string literals
# blanked out and any trailing comment dropped, so a mention inside a
# string or comment doesn't trip these.
GODOT3_RULES = [
    (re.compile(r"^\s*onready\s+var\b"), "Godot 3 onready: use @onready"),
    (re.compile(r"^\s*export(\s|\()"), "Godot 3 export: use @export"),
    (re.compile(r"\byield\s*\("), "Godot 3 yield: use await"),
    (re.compile(r"\bsetget\b"), "Godot 3 setget: use a property with set/get"),
    (re.compile(r"\.instance\(\s*\)"), "Godot 3 .instance(): use .instantiate()"),
    (re.compile(r"\b(KinematicBody2D|KinematicBody|Spatial|SpatialMaterial|"
                r"Position2D|Position3D|RigidBody|StaticBody)\b"), "Godot 3 class name"),
    (re.compile(r"\b(rand_range|stepify|deg2rad|rad2deg|str2var|var2str|to_json|"
                r"parse_json)\s*\("), "Godot 3 function"),
    (re.compile(r"\.empty\(\s*\)"), "Godot 3 .empty(): use .is_empty()"),
    (re.compile(r'\bconnect\(\s*""\s*,\s*self\s*,'),
     "Godot 3 connect: use signal.connect(callable)"),
    (re.compile(r"\bPool(Byte|Int|Real|String|Vector2|Vector3|Color)Array\b"),
     "Godot 3 pool array: use Packed*Array"),
    (re.compile(r"^\s*tool\s*$"), "Godot 3 tool: use @tool"),
    (re.compile(r"(?<![\w.])len\("), "GDScript has no len(): use .size() or .length()"),
    (re.compile(r"\bNone\b"), "Python None: GDScript uses null"),
    (re.compile(r"^\s*def\s+\w+\s*\("), "Python def: GDScript uses func"),
    (re.compile(r"\b(True|False)\b"), "Python True/False: GDScript uses true/false"),
]


def lint_gd_line(line: str) -> list:
    issues = []
    if INDENT_RE.match(line):
        issues.append("indented with spaces; this project indents with tabs")
    if VAR_RE.match(line):
        issues.append("untyped var: give it a type (var x: T = ...) or infer it (var x := ...)")
    m = FUNC_RE.match(line)
    if m:
        if "->" not in line:
            issues.append("func without a return type (-> void / -> T)")
        for param in m.group(2).split(","):
            param = param.strip()
            if not param:
                continue
            if ":" not in param:
                name = param.split("=")[0].strip()
                issues.append(f"untyped parameter {name}")
    stripped = STRING_LITERAL_RE.sub('""', line)
    stripped = stripped.split("#", 1)[0]
    for pat, msg in GODOT3_RULES:
        if pat.search(stripped):
            issues.append(msg)
    return issues


# .gd whole-file rules (F1-F3)

def check_summary(lines: list):
    n = len(lines)
    i = 0
    while i < n:
        s = lines[i].strip()
        if s == "" or s.startswith("@"):
            i += 1
            continue
        break
    consumed = False
    while i < n:
        s = lines[i].strip()
        if s == "":
            i += 1
            continue
        if s.startswith("extends") or s.startswith("class_name"):
            consumed = True
            i += 1
            continue
        break
    if not consumed:
        return None
    while i < n and lines[i].strip() == "":
        i += 1
    if i >= n or not lines[i].strip().startswith("##"):
        line_no = i + 1 if i < n else max(n, 1)
        return (line_no,
                "missing the one-line ## class summary right after extends "
                "(tools/gen_context.py reads it)")
    return None


# Line-count cap exemptions: scripts the project has already decided are
# core + helper split candidates but haven't been split yet.
EXEMPT_LINE_CAP = {"scripts/travel/travel_controller.gd", "scripts/enemies/window_raider.gd"}


def check_line_cap(rel: str, text: str):
    n = text.count("\n")
    if n > 400 and rel not in EXEMPT_LINE_CAP:
        return (1, f"{n} lines: over the 400-line hard cap; split it into a core plus "
                   "RefCounted helpers (CLAUDE.md Code rules)")
    return None


AUTOLOAD_ENTRY_RE = re.compile(r'^\w+\s*=\s*"\*?(res://[^"]+)"\s*$')


def autoload_script_paths(root: str) -> set:
    try:
        with open(os.path.join(root, "project.godot"), "r", encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return set()
    paths = set()
    in_autoload = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            in_autoload = (s == "[autoload]")
            continue
        if not in_autoload or not s:
            continue
        m = AUTOLOAD_ENTRY_RE.match(s)
        if m and m.group(1).endswith(".gd"):
            paths.add(m.group(1)[len("res://"):])
    return paths


def lint_gd_text(rel: str, text: str, hunks: list, root: str) -> list:
    issues = []
    for hunk in hunks:
        for line_no, line, prefix in numbered_lines(hunk, text):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            for msg in lint_gd_line(line):
                issues.append((line_no, prefix + msg))
    lines = text.splitlines()
    r = check_summary(lines)
    if r:
        issues.append(r)
    r = check_line_cap(rel, text)
    if r:
        issues.append(r)
    if rel in autoload_script_paths(root) and re.search(r"^class_name\s", text, re.M):
        issues.append((1, "autoloads never get a class_name (it creates a parse cycle)"))
    return issues


# .tscn / .tres rules (T1-T4), always whole-file

ID_RE = re.compile(r'\bid="([^"]+)"')  # \b so "uid=" (has "id=" inside it) never matches
UNIQUE_ID_RE = re.compile(r'unique_id=(\d+)')
PATH_ATTR_RE = re.compile(r'path="([^"]+)"')
EXT_RESOURCE_HEADER_RE = re.compile(r'^\[ext_resource\b')
SUB_RESOURCE_HEADER_RE = re.compile(r'^\[sub_resource\b')
NODE_HEADER_RE = re.compile(r'^\[node\b')
EXT_REF_RE = re.compile(r'ExtResource\("([^"]+)"\)')
SUB_REF_RE = re.compile(r'SubResource\("([^"]+)"\)')


def duplicate_id_issues(lines: list, header_re, kind: str) -> list:
    seen = set()
    issues = []
    for i, line in enumerate(lines):
        if not header_re.match(line):
            continue
        m = ID_RE.search(line)
        if not m:
            continue
        rid = m.group(1)
        if rid in seen:
            issues.append((i + 1, f'duplicate {kind} id="{rid}"'))
        else:
            seen.add(rid)
    return issues


def duplicate_unique_id_issues(lines: list) -> list:
    seen = set()
    issues = []
    for i, line in enumerate(lines):
        if not NODE_HEADER_RE.match(line):
            continue
        m = UNIQUE_ID_RE.search(line)
        if not m:
            continue
        v = m.group(1)
        if v in seen:
            issues.append((i + 1, f"duplicate unique_id={v}"))
        else:
            seen.add(v)
    return issues


def collect_ids(lines: list, header_re) -> set:
    ids = set()
    for line in lines:
        if not header_re.match(line):
            continue
        m = ID_RE.search(line)
        if m:
            ids.add(m.group(1))
    return ids


def dangling_ref_issues(lines: list, ref_re, declared_ids: set, label: str, section: str) -> list:
    issues = []
    for i, line in enumerate(lines):
        for m in ref_re.finditer(line):
            rid = m.group(1)
            if rid not in declared_ids:
                issues.append((i + 1, f'{label}("{rid}") has no [{section}] with that id'))
    return issues


def unused_ext_resource_issues(lines: list) -> list:
    declared = []
    for i, line in enumerate(lines):
        if not EXT_RESOURCE_HEADER_RE.match(line):
            continue
        m = ID_RE.search(line)
        if not m:
            continue
        pm = PATH_ATTR_RE.search(line)
        declared.append((m.group(1), pm.group(1) if pm else "?", i + 1))
    used = set()
    for line in lines:
        used.update(m.group(1) for m in EXT_REF_RE.finditer(line))
    issues = []
    for rid, path, line_no in declared:
        if rid not in used:
            issues.append((line_no, f'ext_resource id="{rid}" ({path}) is referenced nowhere: '
                                     "remove it"))
    return issues


def lint_scene_text(text: str) -> list:
    lines = text.splitlines()
    issues = []
    issues += duplicate_id_issues(lines, EXT_RESOURCE_HEADER_RE, "ext_resource")
    issues += duplicate_id_issues(lines, SUB_RESOURCE_HEADER_RE, "sub_resource")
    issues += duplicate_unique_id_issues(lines)
    ext_ids = collect_ids(lines, EXT_RESOURCE_HEADER_RE)
    sub_ids = collect_ids(lines, SUB_RESOURCE_HEADER_RE)
    issues += dangling_ref_issues(lines, EXT_REF_RE, ext_ids, "ExtResource", "ext_resource")
    issues += dangling_ref_issues(lines, SUB_REF_RE, sub_ids, "SubResource", "sub_resource")
    issues += unused_ext_resource_issues(lines)
    return issues


# Reporting

def build_report(rel: str, issues: list) -> str:
    out = [f"gd-lint: {rel}"]
    shown = issues[:MAX_ISSUES]
    for line_no, msg in shown:
        out.append(f"  line {line_no}: {msg}")
    remaining = len(issues) - len(shown)
    if remaining > 0:
        out.append(f"  ... and {remaining} more")
    out.append("")
    out.append("Fix these in your change (CLAUDE.md Code rules). If the spec explicitly "
                "asked for one of them, say so in your report.")
    return "\n".join(out) + "\n"


def lint_file(rel: str, text: str, ext: str, hunks: list, root: str) -> list:
    if ext == ".gd":
        return lint_gd_text(rel, text, hunks, root)
    return lint_scene_text(text)


# Hook mode

def hook_main():
    data = json.load(sys.stdin)
    tool_name = data.get("tool_name")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return
    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path")
    if not path:
        return
    cwd = data.get("cwd") or os.getcwd()
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    ext = os.path.splitext(path)[1]
    if ext not in LINT_EXTS:
        return
    root = find_project_root(os.path.dirname(path))
    if root is None:
        return
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    rel = rel_posix(path, root)
    issues = lint_file(rel, text, ext, edited_hunks(tool_name, tool_input), root)
    if not issues:
        return
    sys.stderr.write(build_report(rel, issues))
    sys.exit(2)


# CLI mode: --scan [paths...]

def scan_main(paths: list):
    cwd = os.getcwd()
    root = find_project_root(cwd)
    if root is None:
        print("no project.godot found")
        return
    if paths:
        candidates = [p if os.path.isabs(p) else os.path.join(cwd, p) for p in paths]
    else:
        result = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True)
        candidates = [os.path.join(root, p) for p in result.stdout.splitlines() if p]
    files_with_issues = 0
    for path in candidates:
        ext = os.path.splitext(path)[1]
        if ext not in LINT_EXTS or not os.path.isfile(path):
            continue
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        rel = rel_posix(path, root)
        issues = lint_file(rel, text, ext, [text], root)
        if issues:
            files_with_issues += 1
            sys.stdout.write(build_report(rel, issues))
    print(f"{files_with_issues} file(s) with issues")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--scan":
        scan_main(sys.argv[2:])
    else:
        hook_main()


try:
    main()
except SystemExit:
    raise
except Exception:
    pass
