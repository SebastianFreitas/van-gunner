#!/usr/bin/env python3
"""Regenerate docs/PROJECT_MAP.md from the project itself.

Run from the project root:

    python3 tools/gen_context.py

Everything in PROJECT_MAP.md is derived from files on disk, so re-running this
after a refactor is the whole maintenance story. Hand-written context that the
generator cannot infer (design intent, invariants, gotchas) lives in AGENTS.md.
"""

from __future__ import annotations

import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "PROJECT_MAP.md")
SKIP_DIRS = {".git", ".godot", "__pycache__", ".import"}


def walk(exts):
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(files):
            if f.endswith(exts):
                p = os.path.join(base, f)
                yield os.path.relpath(p, ROOT).replace(os.sep, "/")


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf8", errors="ignore") as fh:
        return fh.read()


def section(title):
    return f"\n## {title}\n\n"


# --- project.godot -----------------------------------------------------------


def project_settings():
    src = read("project.godot")
    autoloads = re.findall(r'^(\w+)="\*?(res://[^"]+)"', src, re.M)
    actions = re.findall(r"^(\w+)=\{", src, re.M)
    name = re.search(r'config/name="([^"]+)"', src)
    main = re.search(r'run/main_scene="([^"]+)"', src)
    feats = re.search(r"config/features=PackedStringArray\(([^)]*)\)", src)
    return {
        "name": name.group(1) if name else "?",
        "main_scene": main.group(1) if main else "?",
        "features": feats.group(1).replace('"', "") if feats else "?",
        "autoloads": autoloads,
        "actions": actions,
    }


# --- scripts -----------------------------------------------------------------


def script_index():
    rows = defaultdict(list)
    for rel in walk((".gd",)):
        txt = read(rel)
        lines = txt.count("\n") + 1
        cls = re.search(r"^class_name\s+(\w+)", txt, re.M)
        # First `##` block after the class/extends header is the summary.
        doc = ""
        for line in txt.splitlines():
            s = line.strip()
            if s.startswith("##"):
                doc = s.lstrip("#").strip()
                if doc:
                    break
        folder = os.path.dirname(rel) or "."
        rows[folder].append((rel, cls.group(1) if cls else "", lines, doc))
    return rows


def signals_and_enums():
    out = []
    for rel in walk((".gd",)):
        txt = read(rel)
        sigs = re.findall(r"^signal\s+(\w+\([^)]*\)|\w+)", txt, re.M)
        enums = re.findall(r"^enum\s+(\w+)\s*\{([^}]*)\}", txt, re.M | re.S)
        if sigs or enums:
            out.append((rel, sigs, [(n, " ".join(b.split())) for n, b in enums]))
    return out


# --- groups ------------------------------------------------------------------


def groups():
    added, looked = set(), set()
    for rel in walk((".gd",)):
        txt = read(rel)
        added |= set(re.findall(r'add_to_group\(&?"([a-z_]+)"', txt))
        looked |= set(re.findall(r'_in_group\(&?"([a-z_]+)"', txt))
        looked |= set(re.findall(r'is_in_group\(&?"([a-z_]+)"', txt))
    for rel in walk((".tscn",)):
        for blob in re.findall(r"groups=\[([^\]]*)\]", read(rel)):
            added |= set(re.findall(r'"([a-z_]+)"', blob))
    return sorted(added), sorted(looked)


# --- resources ---------------------------------------------------------------


def tres_field(txt, field):
    m = re.search(rf"^{field}\s*=\s*(.+)$", txt, re.M)
    return m.group(1).strip().strip('&"') if m else ""


def resource_table(folder, fields):
    rows = []
    base = os.path.join(ROOT, folder)
    if not os.path.isdir(base):
        return rows
    for f in sorted(os.listdir(base)):
        if not f.endswith(".tres"):
            continue
        txt = read(f"{folder}/{f}")
        rows.append([f[:-5]] + [tres_field(txt, k) for k in fields])
    return rows


def balance_values():
    txt = read("resources/balance/game_balance.tres")
    body = txt.split("[resource]", 1)[-1]
    rows = []
    for line in body.strip().splitlines():
        if "=" in line and not line.startswith("script"):
            k, v = line.split("=", 1)
            rows.append((k.strip(), v.strip()))
    # Defaults that are not overridden in the .tres still matter.
    src = read("scripts/core/game_balance_data.gd")
    defaults = re.findall(r"^@export var (\w+)\s*:?=?\s*(.+)$", src, re.M)
    overridden = {k for k, _ in rows}
    inherited = [
        (k, v.strip()) for k, v in defaults if k not in overridden and ":=" not in k
    ]
    return rows, inherited


def debug_commands():
    txt = read("scripts/debug/debug_commands.gd")
    block = re.search(r"_commands\s*=\s*\{(.*?)\n\t\}", txt, re.S)
    if not block:
        return []
    return re.findall(r'"(\w+)"\s*:', block.group(1))


def trait_keys():
    txt = read("scripts/items/boon_trait_keys.gd")
    return re.findall(r"^const\s+(\w+)\s*:=\s*&\"(\w+)\"", txt, re.M)


def scene_index():
    rows = []
    for rel in walk((".tscn",)):
        txt = read(rel)
        nodes = txt.count("[node ")
        root = re.search(r'\[node name="([^"]+)" type="([^"]+)"', txt)
        rows.append((rel, nodes, root.group(2) if root else ""))
    return rows


def shaders():
    return list(walk((".gdshader",)))


# --- render ------------------------------------------------------------------


def md_table(header, rows):
    if not rows:
        return "_none_\n"
    out = ["| " + " | ".join(header) + " |"]
    out.append("|" + "|".join("---" for _ in header) + "|")
    for r in rows:
        cells = [str(c).replace("|", "\\|") for c in r]
        out.append("| " + " | ".join(cells) + " |")
    return "\n".join(out) + "\n"


def build():
    ps = project_settings()
    doc = []
    doc.append("# PROJECT_MAP — van-gunner\n")
    doc.append(
        "> **Generated file. Do not hand-edit.** Regenerate with "
        "`python3 tools/gen_context.py`.\n"
        "> Design intent, invariants and gotchas live in `AGENTS.md`, which *is* "
        "hand-written.\n"
    )

    doc.append(section("Project settings"))
    doc.append(
        f"- Name: `{ps['name']}`\n"
        f"- Main scene: `{ps['main_scene']}`\n"
        f"- Engine features: `{ps['features']}`\n"
        f"- Physics: Jolt · Renderer: Forward+ (d3d12 on Windows)\n"
    )

    doc.append(section("Autoloads (singletons, always available)"))
    doc.append(md_table(["Name", "Script"], [(n, f"`{p}`") for n, p in ps["autoloads"]]))

    doc.append(section("Input actions"))
    doc.append("`" + "`, `".join(ps["actions"]) + "`\n")

    doc.append(section("Node groups"))
    added, looked = groups()
    doc.append("Registered: `" + "`, `".join(added) + "`\n\n")
    doc.append("Looked up: `" + "`, `".join(looked) + "`\n")

    doc.append(section("Signals and enums"))
    for rel, sigs, enums in signals_and_enums():
        doc.append(f"**`{rel}`**\n\n")
        for s in sigs:
            doc.append(f"- `signal {s}`\n")
        for n, b in enums:
            doc.append(f"- `enum {n} {{ {b} }}`\n")
        doc.append("\n")

    doc.append(section("Script index"))
    idx = script_index()
    total = sum(len(v) for v in idx.values())
    loc = sum(r[2] for v in idx.values() for r in v)
    doc.append(f"{total} GDScript files, {loc} lines.\n")
    for folder in sorted(idx):
        doc.append(f"\n### `{folder}/`\n\n")
        rows = [
            (f"`{os.path.basename(p)}`", f"`{c}`" if c else "—", n, d)
            for p, c, n, d in sorted(idx[folder])
        ]
        doc.append(md_table(["File", "class_name", "LOC", "Summary"], rows))

    doc.append(section("Scenes"))
    doc.append(
        md_table(
            ["Scene", "Nodes", "Root type"],
            [(f"`{r}`", n, t) for r, n, t in scene_index()],
        )
    )

    doc.append(section("Shaders"))
    doc.append("`" + "`, `".join(shaders()) + "`\n")

    doc.append(section("Balance sheet (`resources/balance/game_balance.tres`)"))
    over, inherited = balance_values()
    doc.append("**Overridden in the .tres:**\n\n")
    doc.append(md_table(["Field", "Value"], [(f"`{k}`", f"`{v}`") for k, v in over]))
    doc.append("\n**Still on script defaults (`game_balance_data.gd`):**\n\n")
    doc.append(
        md_table(["Field", "Default"], [(f"`{k}`", f"`{v}`") for k, v in inherited])
    )

    doc.append(section("Weapon definitions"))
    doc.append(
        md_table(
            ["id", "name", "fire_rate_mult", "pellets", "mag", "reload_s", "tickets"],
            resource_table(
                "resources/weapons/definitions",
                [
                    "display_name",
                    "fire_rate_mult",
                    "pellets_per_shot",
                    "base_mag_size",
                    "base_reload_seconds",
                    "drop_tickets",
                ],
            ),
        )
    )

    doc.append(section("Act street cards"))
    doc.append(
        md_table(
            ["id", "name", "polarity", "description"],
            resource_table(
                "resources/acts/cards", ["display_name", "polarity", "description"]
            ),
        )
    )

    doc.append(section("Side stops"))
    doc.append(
        md_table(
            ["id", "name", "short_label"],
            resource_table(
                "resources/side_stops", ["display_name", "short_label"]
            ),
        )
    )

    doc.append(section("Enemies"))
    doc.append(
        md_table(
            ["id", "name", "agile"],
            resource_table("resources/enemies", ["display_name", "is_agile"]),
        )
    )

    doc.append(section("Boons"))
    doc.append(
        md_table(
            ["id", "name", "pool", "description"],
            resource_table(
                "resources/items/boons", ["display_name", "boon_pool", "description"]
            ),
        )
    )

    doc.append(section("Items (non-boon)"))
    doc.append(
        md_table(
            ["id", "name", "kind", "shop_price"],
            resource_table("resources/items", ["display_name", "kind", "shop_price"]),
        )
    )

    doc.append(section("Loot pools"))
    pools = sorted(
        f[:-5] for f in os.listdir(os.path.join(ROOT, "resources/items/pools"))
    )
    doc.append("`" + "`, `".join(pools) + "`\n")

    doc.append(section("Boon trait keys"))
    doc.append(
        md_table(
            ["Constant", "StringName"],
            [(f"`{c}`", f"`{v}`") for c, v in trait_keys()],
        )
    )

    doc.append(section("Debug console commands"))
    doc.append("`" + "`, `".join(debug_commands()) + "`\n")

    return "".join(doc)


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf8") as fh:
        fh.write(build())
    print(f"wrote {os.path.relpath(OUT, ROOT)}")
