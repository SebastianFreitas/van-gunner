#!/usr/bin/env python3
"""Generate boon ItemDefinition .tres files and the boon pools.

Owns every file in resources/items/boons/ and the pool files listed in POOLS.
Re-run after editing BOONS: stale boon files and their icons are removed, and a
boon or pool file whose header already carries a uid keeps it so references from
scenes stay valid across regenerations.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOONS_DIR = ROOT / "resources" / "items" / "boons"
POOLS_DIR = ROOT / "resources" / "items" / "pools"
ICON_DIR = ROOT / "scenes" / "items" / "boons"

# Pool name (the "pool" key of a boon) -> pool file. Every pool listed here is
# rewritten on each run, so a pool with no boons is written empty.
POOLS = {
    "general": "general_boon_pool.tres",
}

# effect dict types:
# max_health: {amount}
# full_heal: {}
# gun_stat: {stat, value, mode="add"|"multiply", id}
# trait_add: {key, value}
# trait_mult: {key, value}
# trait_flag: {key}
#
# Boon keys: id, name, desc, weight, effects; optional pool (default "general")
# and repeatable (default False: one per run).

BOONS = [
    # --- Life ---
    {"id": "max_hp_1", "weight": 10, "name": "Thick Skin", "desc": "Gain 10 Max Health",
     "effects": [{"type": "max_health", "amount": 10}]},
    {"id": "max_hp_2", "weight": 5, "name": "Iron Constitution", "desc": "Gain 20 Max Health",
     "effects": [{"type": "max_health", "amount": 20}]},
    {"id": "max_hp_3", "weight": 1, "name": "Titan's Heart", "desc": "Gain 60 Max Health",
     "effects": [{"type": "max_health", "amount": 60}]},
    {"id": "max_hp_heal", "weight": 2, "name": "Second Wind", "desc": "Gain 40 Max Health and heal fully",
     "effects": [{"type": "max_health", "amount": 40}, {"type": "full_heal"}]},
    {"id": "max_hp_phys", "weight": 5, "name": "Brawler's Bulk", "desc": "Gain 10 Max Health and +1 damage",
     "effects": [
         {"type": "max_health", "amount": 10},
         {"type": "gun_stat", "stat": "damage_per_shot", "value": 1.0, "id": "max_hp_phys_damage"},
     ]},

    # --- Gun ---
    {"id": "ricochet_stack", "weight": 1, "name": "Cascading Rounds", "desc": "Ricochets get increasingly stronger",
     "effects": [{"type": "trait_flag", "key": "ricochet_stack_power"}]},
    {"id": "shoot_speed", "weight": 1, "name": "Hair Trigger", "desc": "Gain 100% shot speed",
     "effects": [{"type": "gun_stat", "stat": "fire_rate", "value": 2.0, "mode": "multiply", "id": "shoot_speed"}]},
    {"id": "chew_tobacco", "weight": 1.0, "name": "Chew Tobacco", "desc": "Permanent grit. +1 damage for the rest of the run.",
     "effects": [{"type": "gun_stat", "stat": "damage_per_shot", "value": 1.0, "id": "chew_tobacco_damage"}]},
    {"id": "ricochet_rounds", "weight": 0.8, "name": "Ricochet Rounds", "desc": "Hardened slugs that skip off steel. Bullets bounce 2 extra times.",
     "effects": [{"type": "gun_stat", "stat": "max_bounces", "value": 2.0, "id": "ricochet_rounds_bounces"}]},
    {"id": "rubber_casings", "weight": 0.6, "name": "Rubber Casings", "desc": "Springy casings. One extra bounce, and ricochets keep far more speed.",
     "effects": [
         {"type": "gun_stat", "stat": "max_bounces", "value": 1.0, "id": "rubber_casings_bounces"},
         {"type": "gun_stat", "stat": "bounce_speed_retention", "value": 1.35, "mode": "multiply", "id": "rubber_casings_retention"},
     ]},
]

SCRIPT_PATHS = {
    "item_definition": "res://scripts/items/item_definition.gd",
    "item_effect": "res://scripts/items/item_effect.gd",
    "gun_stat_modifier": "res://scripts/items/effects/gun_stat_modifier_effect.gd",
    "stat_modifier": "res://scripts/combat/stat_modifier.gd",
    "max_health": "res://scripts/items/effects/max_health_effect.gd",
    "full_heal": "res://scripts/items/effects/full_heal_effect.gd",
    "boon_trait": "res://scripts/items/effects/boon_trait_effect.gd",
    "composite": "res://scripts/items/effects/composite_effect.gd",
    "loot_pool": "res://scripts/items/loot_pool.gd",
    "loot_pool_entry": "res://scripts/items/loot_pool_entry.gd",
}

_UID_RE = re.compile(r'\buid="(uid://[^"]+)"')
_effect_counter = 0


def next_id(prefix: str) -> str:
    global _effect_counter
    _effect_counter += 1
    return f"{prefix}_{_effect_counter}"


def existing_uid(path: Path) -> str | None:
    """The uid in an existing file's [gd_resource] header, if it has one."""
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as handle:
        first = handle.readline()
    if not first.startswith("[gd_resource"):
        return None
    match = _UID_RE.search(first)
    return match.group(1) if match else None


def resource_header(script_class: str, uid: str | None) -> str:
    header = f'[gd_resource type="Resource" script_class="{script_class}" format=3'
    if uid:
        header += f' uid="{uid}"'
    return header + "]"


def render_effect(effect: dict, boon_id: str) -> tuple[str, str, str]:
    """Return (sub_resource_block, ext_key, effect_resource_id)."""
    etype = effect["type"]
    rid = next_id(f"eff_{boon_id}")

    if etype == "max_health":
        return (
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("max_health")\n'
            f'bonus_health = {effect["amount"]}\n',
            "max_health",
            rid,
        )
    if etype == "full_heal":
        return (
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("full_heal")\n',
            "full_heal",
            rid,
        )
    if etype == "gun_stat":
        mode = 1 if effect.get("mode") == "multiply" else 0
        mod_id = next_id(f"mod_{boon_id}")
        stat = effect["stat"]
        value = effect["value"]
        eid = effect.get("id", boon_id)
        block = (
            f'[sub_resource type="Resource" id="{mod_id}"]\n'
            f'script = ExtResource("stat_modifier")\n'
            f'stat_name = &"{stat}"\n'
            f'mode = {mode}\n'
            f'value = {value}\n'
            f'id = &"{eid}"\n\n'
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("gun_stat_modifier")\n'
            f'modifier = SubResource("{mod_id}")\n'
        )
        return block, "gun_stat_modifier", rid
    if etype == "trait_add":
        return (
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("boon_trait")\n'
            f'trait_key = &"{effect["key"]}"\n'
            f'add_value = {effect["value"]}\n',
            "boon_trait",
            rid,
        )
    if etype == "trait_mult":
        return (
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("boon_trait")\n'
            f'trait_key = &"{effect["key"]}"\n'
            f'multiply_value = {effect["value"]}\n',
            "boon_trait",
            rid,
        )
    if etype == "trait_flag":
        return (
            f'[sub_resource type="Resource" id="{rid}"]\n'
            f'script = ExtResource("boon_trait")\n'
            f'trait_key = &"{effect["key"]}"\n'
            f'set_flag = true\n',
            "boon_trait",
            rid,
        )
    raise ValueError(f"Unknown effect type: {etype}")


def icon_for(boon_id: str) -> str:
    return f"res://scenes/items/boons/{boon_id}.svg"


def render_boon(boon: dict, uid: str | None) -> str:
    global _effect_counter
    _effect_counter = 0
    boon_id = boon["id"]

    used_exts = {"item_definition", "item_effect", "icon"}
    sub_blocks: list[str] = []
    effect_refs: list[str] = []

    for effect in boon["effects"]:
        block, ext_key, rid = render_effect(effect, boon_id)
        sub_blocks.append(block)
        effect_refs.append(f'SubResource("{rid}")')
        used_exts.add(ext_key)
        if effect["type"] == "gun_stat":
            used_exts.add("stat_modifier")

    icon_path = icon_for(boon_id)
    ext_lines = [
        f'[ext_resource type="Script" path="{SCRIPT_PATHS["item_definition"]}" id="item_definition"]',
        f'[ext_resource type="Script" path="{SCRIPT_PATHS["item_effect"]}" id="item_effect"]',
        f'[ext_resource type="Texture2D" path="{icon_path}" id="icon"]',
    ]
    for key in ["gun_stat_modifier", "stat_modifier", "max_health", "full_heal", "boon_trait"]:
        if key in used_exts:
            ext_lines.append(
                f'[ext_resource type="Script" path="{SCRIPT_PATHS[key]}" id="{key}"]'
            )

    resource_lines = [
        "[resource]",
        'script = ExtResource("item_definition")',
        f'id = &"{boon_id}"',
        f'display_name = "{boon["name"]}"',
        f'description = "{boon["desc"]}"',
        'icon = ExtResource("icon")',
        "kind = 1",
    ]
    if boon.get("repeatable", False):
        resource_lines.append("repeatable = true")
    resource_lines.append(
        f'effects = Array[ExtResource("item_effect")]([{", ".join(effect_refs)}])'
    )

    lines = [
        resource_header("ItemDefinition", uid),
        "",
        *ext_lines,
        "",
        *sub_blocks,
        *resource_lines,
        "",
    ]
    return "\n".join(lines)


def render_pool(boons: list[dict], uid: str | None) -> str:
    ext_lines = [
        f'[ext_resource type="Script" path="{SCRIPT_PATHS["loot_pool"]}" id="loot_pool"]',
        f'[ext_resource type="Script" path="{SCRIPT_PATHS["loot_pool_entry"]}" id="loot_pool_entry"]',
    ]
    sub_blocks = []
    entry_refs = []
    for i, boon in enumerate(boons):
        path = f'res://resources/items/boons/{boon["id"]}.tres'
        ext_lines.append(f'[ext_resource type="Resource" path="{path}" id="item_{i}"]')
        sub_id = f"entry_{i}"
        sub_blocks.append(
            f'[sub_resource type="Resource" id="{sub_id}"]\n'
            f'script = ExtResource("loot_pool_entry")\n'
            f'item = ExtResource("item_{i}")\n'
            f'weight = {boon["weight"]}\n'
        )
        entry_refs.append(f'SubResource("{sub_id}")')

    lines = [
        resource_header("LootPool", uid),
        "",
        *ext_lines,
        "",
        *sub_blocks,
        "[resource]",
        'script = ExtResource("loot_pool")',
        f'entries = Array[ExtResource("loot_pool_entry")]([{", ".join(entry_refs)}])',
        "",
    ]
    return "\n".join(lines)


def prune_stale(keep_ids: set[str]) -> None:
    """Remove boon files and icons for ids the generator no longer lists."""
    for tres in sorted(BOONS_DIR.glob("*.tres")):
        if tres.stem in keep_ids:
            continue
        tres.unlink()
        print(f"Removed {tres.relative_to(ROOT)}")
    for icon in sorted(ICON_DIR.glob("*.svg")):
        if icon.stem in keep_ids:
            continue
        for stale in (icon, icon.with_name(icon.name + ".import")):
            if stale.exists():
                stale.unlink()
                print(f"Removed {stale.relative_to(ROOT)}")


def main() -> None:
    from generate_boon_icons import generate_icons

    ids = [boon["id"] for boon in BOONS]
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate boon id in BOONS")
    for boon in BOONS:
        pool = boon.get("pool", "general")
        if pool not in POOLS:
            raise ValueError(f"Boon {boon['id']} names unknown pool {pool!r}")

    generate_icons(BOONS)
    BOONS_DIR.mkdir(parents=True, exist_ok=True)
    POOLS_DIR.mkdir(parents=True, exist_ok=True)

    for boon in BOONS:
        out = BOONS_DIR / f'{boon["id"]}.tres'
        out.write_text(render_boon(boon, existing_uid(out)), encoding="utf-8", newline="\n")
        print(f"Wrote {out.relative_to(ROOT)}")

    for pool_name, file_name in POOLS.items():
        pool_boons = [boon for boon in BOONS if boon.get("pool", "general") == pool_name]
        out = POOLS_DIR / file_name
        out.write_text(render_pool(pool_boons, existing_uid(out)), encoding="utf-8", newline="\n")
        print(f"Wrote {out.relative_to(ROOT)} ({len(pool_boons)} boons)")

    prune_stale(set(ids))
    print(f"\nTotal boons: {len(BOONS)}")


if __name__ == "__main__":
    main()
