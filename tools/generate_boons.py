#!/usr/bin/env python3
"""Generate boon ItemDefinition .tres files and pool resources."""

from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOONS_DIR = ROOT / "resources" / "items" / "boons"
POOLS_DIR = ROOT / "resources" / "items" / "pools"

POOL_ENUM = {
    "general": 0,
    "fire": 1,
    "poison": 2,
    "cold": 3,
    "physical": 4,
}

# effect dict types:
# max_health: {amount}
# full_heal: {}
# gun_stat: {stat, value, mode="add"|"multiply", id}
# trait_add: {key, value}
# trait_mult: {key, value}
# trait_flag: {key}
# composite: {effects: [...]}

BOONS = [
    # --- General / Life ---
    {"id": "max_hp_1", "pool": "general", "weight": 10, "name": "Thick Skin", "desc": "Gain 10 Max Health",
     "effects": [{"type": "max_health", "amount": 10}]},
    {"id": "max_hp_2", "pool": "general", "weight": 5, "name": "Iron Constitution", "desc": "Gain 20 Max Health",
     "effects": [{"type": "max_health", "amount": 20}]},
    {"id": "max_hp_3", "pool": "general", "weight": 1, "name": "Titan's Heart", "desc": "Gain 60 Max Health",
     "effects": [{"type": "max_health", "amount": 60}]},
    {"id": "max_hp_heal", "pool": "general", "weight": 2, "name": "Second Wind", "desc": "Gain 40 Max Health and heal fully",
     "effects": [{"type": "max_health", "amount": 40}, {"type": "full_heal"}]},
    {"id": "max_hp_phys", "pool": "general", "weight": 5, "name": "Brawler's Bulk", "desc": "Gain 10 Max Health and 10 physical damage",
     "effects": [{"type": "max_health", "amount": 10}, {"type": "trait_add", "key": "phys_damage_bonus", "value": 10.0}]},
    {"id": "ricochet_stack", "pool": "general", "weight": 1, "name": "Cascading Rounds", "desc": "Ricochets get increasingly stronger",
     "effects": [{"type": "trait_flag", "key": "ricochet_stack_power"}]},
    {"id": "shoot_speed", "pool": "general", "weight": 1, "name": "Hair Trigger", "desc": "Gain 100% shot speed",
     "effects": [{"type": "gun_stat", "stat": "fire_rate", "value": 2.0, "mode": "multiply", "id": "shoot_speed"}]},
    {"id": "chew_tobacco", "pool": "general", "weight": 1.0, "name": "Chew Tobacco", "desc": "Permanent grit. +2 physical damage for the rest of the run.",
     "effects": [{"type": "trait_add", "key": "phys_damage_bonus", "value": 2.0}]},
    {"id": "ricochet_rounds", "pool": "general", "weight": 0.8, "name": "Ricochet Rounds", "desc": "Hardened slugs that skip off steel. Bullets bounce 2 extra times.",
     "effects": [{"type": "gun_stat", "stat": "max_bounces", "value": 2.0, "id": "ricochet_rounds_bounces"}]},
    {"id": "rubber_casings", "pool": "general", "weight": 0.6, "name": "Rubber Casings", "desc": "Springy casings. One extra bounce, and ricochets keep far more speed.",
     "effects": [
         {"type": "gun_stat", "stat": "max_bounces", "value": 1.0, "id": "rubber_casings_bounces"},
         {"type": "gun_stat", "stat": "bounce_speed_retention", "value": 1.35, "mode": "multiply", "id": "rubber_casings_retention"},
     ]},

    # --- Fire ---
    {"id": "fire_greed", "pool": "fire", "weight": 10, "name": "Pyromaniac's Bargain", "desc": "Lose 20 max hp — Deal +10 fire damage",
     "effects": [{"type": "max_health", "amount": -20}, {"type": "trait_add", "key": "fire_damage_bonus", "value": 10}]},
    {"id": "ricochet_explosive", "pool": "fire", "weight": 5, "name": "Incendiary Ricochet", "desc": "Fire damage does not destroy the bullet on impact",
     "effects": [{"type": "trait_flag", "key": "ricochet_explosive"}]},
    {"id": "increased_fire_area", "pool": "fire", "weight": 10, "name": "Blast Radius I", "desc": "Fire damage explodes in a 20% larger area",
     "effects": [{"type": "trait_mult", "key": "fire_area_mult", "value": 1.2}]},
    {"id": "increased_fire_area_2", "pool": "fire", "weight": 5, "name": "Blast Radius II", "desc": "Fire damage explodes in a 50% larger area",
     "effects": [{"type": "trait_mult", "key": "fire_area_mult", "value": 1.5}]},
    {"id": "increased_fire_area_3", "pool": "fire", "weight": 1, "name": "Blast Radius III", "desc": "Fire damage explodes in a 100% larger area",
     "effects": [{"type": "trait_mult", "key": "fire_area_mult", "value": 2.0}]},
    {"id": "double_fire", "pool": "fire", "weight": 1, "name": "Focused Inferno", "desc": "Fire explodes in 90% smaller area — fire damage doubled",
     "effects": [{"type": "trait_mult", "key": "fire_area_mult", "value": 0.1}, {"type": "trait_mult", "key": "fire_damage_mult", "value": 2.0}]},
    {"id": "delayed_fire", "pool": "fire", "weight": 1, "name": "Delayed Detonation", "desc": "Delayed Explosion",
     "effects": [{"type": "trait_flag", "key": "delayed_fire"}]},
    {"id": "push_force_fire", "pool": "fire", "weight": 5, "name": "Concussive Blast", "desc": "Fire explosions gain more push back force",
     "effects": [{"type": "trait_mult", "key": "fire_push_mult", "value": 1.5}]},
    {"id": "pull_fire", "pool": "fire", "weight": 5, "name": "Vacuum Blast", "desc": "Fire explosions pull instead of pushing",
     "effects": [{"type": "trait_flag", "key": "fire_pull"}]},
    {"id": "extra_poison_to_fire", "pool": "fire", "weight": 2, "name": "Toxic Fuel", "desc": "Gain 25% of poison damage as fire damage",
     "effects": [{"type": "trait_add", "key": "extra_poison_to_fire", "value": 0.25}]},
    {"id": "fire_death", "pool": "fire", "weight": 1, "name": "Funeral Pyre", "desc": "Enemies explode on death into a fire explosion",
     "effects": [{"type": "trait_flag", "key": "fire_death"}]},

    # --- Poison ---
    {"id": "twice_fast_poison", "pool": "poison", "weight": 1, "name": "Accelerant Toxin", "desc": "Poison deals damage twice as fast",
     "effects": [{"type": "trait_mult", "key": "poison_tick_speed_mult", "value": 2.0}]},
    {"id": "poison_duration", "pool": "poison", "weight": 10, "name": "Lingering Venom", "desc": "Poison lasts 5 more seconds",
     "effects": [{"type": "trait_add", "key": "poison_duration_bonus", "value": 5.0}]},
    {"id": "poison_follow", "pool": "poison", "weight": 1, "name": "Seeking Venom", "desc": "Ricochets bounce into close poisoned enemies",
     "effects": [{"type": "trait_flag", "key": "poison_follow"}]},
    {"id": "weaker_poison", "pool": "poison", "weight": 5, "name": "Neurotoxin", "desc": "Poisoned enemies deal 25% less damage",
     "effects": [{"type": "trait_add", "key": "poisoned_enemy_damage_reduction", "value": 0.25}]},
    {"id": "poisoned_cold", "pool": "poison", "weight": 2, "name": "Cryo-Venom", "desc": "Chilled enemies take 30% more poison damage",
     "effects": [{"type": "trait_add", "key": "poisoned_cold_bonus", "value": 0.3}]},
    {"id": "vampiric_poison", "pool": "poison", "weight": 2, "name": "Leeching Toxin", "desc": "Enemies who die from poison have +5% chance to drop healing packs",
     "effects": [{"type": "trait_add", "key": "vampiric_poison_chance", "value": 0.05}]},
    {"id": "instant_poison", "pool": "poison", "weight": 1, "name": "Instant Toxin", "desc": "Deal all poison damage instantly — deal half poison damage",
     "effects": [{"type": "trait_flag", "key": "instant_poison"}]},
    {"id": "poison_explosions", "pool": "poison", "weight": 1, "name": "Toxic Shrapnel", "desc": "Fire explosions also deal poison damage",
     "effects": [{"type": "trait_flag", "key": "poison_explosions"}]},

    # --- Cold ---
    {"id": "chance_freeze_1", "pool": "cold", "weight": 10, "name": "Frost Touch", "desc": "+1% chance cold damage freezes the enemy",
     "effects": [{"type": "trait_add", "key": "freeze_chance", "value": 0.01}]},
    {"id": "chance_freeze_2", "pool": "cold", "weight": 2, "name": "Deep Freeze", "desc": "+2% chance cold damage freezes the enemy",
     "effects": [{"type": "trait_add", "key": "freeze_chance", "value": 0.02}]},
    {"id": "longer_freeze", "pool": "cold", "weight": 2, "name": "Permafrost", "desc": "Freeze condition lasts one second longer",
     "effects": [{"type": "trait_add", "key": "freeze_duration_bonus", "value": 1.0}]},
    {"id": "phys_to_cold_crit", "pool": "cold", "weight": 5, "name": "Cryo Crit", "desc": "Physical damage converted to cold on critical hits",
     "effects": [{"type": "trait_flag", "key": "phys_to_cold_on_crit"}]},
    {"id": "frozen_damage", "pool": "cold", "weight": 2, "name": "Shatter Strike", "desc": "Deal 50% more damage against frozen targets",
     "effects": [{"type": "trait_mult", "key": "frozen_damage_mult", "value": 1.5}]},
    {"id": "more_frozen_loot", "pool": "cold", "weight": 2, "name": "Frozen Fortune", "desc": "Enemies killed while chilled or frozen drop extra loot",
     "effects": [{"type": "trait_add", "key": "frozen_loot_bonus", "value": 1.0}]},
    {"id": "added_cold_projectile", "pool": "cold", "weight": 3, "name": "Twin Frost", "desc": "Shoot an additional cold projectile",
     "effects": [{"type": "trait_add", "key": "cold_projectile_count", "value": 1.0}]},
    {"id": "cold_shattering_ricochet", "pool": "cold", "weight": 1, "name": "Shattering Ricochet", "desc": "Ricochets shatter into extra cold projectiles",
     "effects": [{"type": "trait_flag", "key": "cold_shattering_ricochet"}]},
    {"id": "cold_shatter", "pool": "cold", "weight": 1, "name": "Ice Burst", "desc": "Enemies that die from cold damage shatter into cold projectiles",
     "effects": [{"type": "trait_flag", "key": "cold_shatter"}]},
    {"id": "poisoned_chill", "pool": "cold", "weight": 2, "name": "Toxic Chill", "desc": "Poisoned enemies are more affected by chill",
     "effects": [{"type": "trait_add", "key": "poisoned_chill_bonus", "value": 0.35}]},

    # --- Physical ---
    {"id": "more_phys_10", "pool": "physical", "weight": 10, "name": "Heavy Rounds I", "desc": "Gain +10 physical damage",
     "effects": [{"type": "trait_add", "key": "phys_damage_bonus", "value": 10.0}]},
    {"id": "more_phys_25", "pool": "physical", "weight": 5, "name": "Heavy Rounds II", "desc": "Gain +25 physical damage",
     "effects": [{"type": "trait_add", "key": "phys_damage_bonus", "value": 25.0}]},
    {"id": "more_phys_50", "pool": "physical", "weight": 1, "name": "Heavy Rounds III", "desc": "Gain +50 physical damage",
     "effects": [{"type": "trait_add", "key": "phys_damage_bonus", "value": 50.0}]},
    {"id": "double_phys_cold", "pool": "physical", "weight": 1, "name": "Icebreaker", "desc": "All physical damage against frozen enemies is doubled",
     "effects": [{"type": "trait_flag", "key": "double_phys_cold"}]},
    {"id": "triple_crit_phys", "pool": "physical", "weight": 1, "name": "Deadeye", "desc": "Critical hits deal 3× physical damage",
     "effects": [{"type": "trait_flag", "key": "triple_crit_phys"}]},
    {"id": "fire_to_phys_50", "pool": "physical", "weight": 5, "name": "Smoldering Brass", "desc": "Convert 50% of fire damage into physical damage",
     "effects": [{"type": "trait_add", "key": "fire_to_phys_ratio", "value": 0.5}]},
    {"id": "fire_to_phys_100", "pool": "physical", "weight": 3, "name": "Ashen Brass", "desc": "Convert 100% of fire damage into physical damage",
     "effects": [{"type": "trait_add", "key": "fire_to_phys_ratio", "value": 1.0}]},
    {"id": "reduced_speed_more_phys", "pool": "physical", "weight": 3, "name": "Slugs", "desc": "50% reduced bullet speed — gain +50 physical damage",
     "effects": [
         {"type": "gun_stat", "stat": "bullet_speed", "value": 0.5, "mode": "multiply", "id": "reduced_speed_more_phys_speed"},
         {"type": "trait_add", "key": "phys_damage_bonus", "value": 50.0},
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

_effect_counter = 0


def next_id(prefix: str) -> str:
    global _effect_counter
    _effect_counter += 1
    return f"{prefix}_{_effect_counter}"


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


def render_boon(boon: dict) -> str:
    global _effect_counter
    _effect_counter = 0
    boon_id = boon["id"]
    pool_val = POOL_ENUM[boon["pool"]]

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
    ext_id_map = {"item_definition": "item_definition", "item_effect": "item_effect", "icon": "icon"}
    counter = 1
    for key in ["gun_stat_modifier", "stat_modifier", "max_health", "full_heal", "boon_trait"]:
        if key in used_exts:
            ext_lines.append(
                f'[ext_resource type="Script" path="{SCRIPT_PATHS[key]}" id="{key}"]'
            )

    lines = [
        '[gd_resource type="Resource" script_class="ItemDefinition" format=3]',
        "",
        *ext_lines,
        "",
        *sub_blocks,
        "[resource]",
        'script = ExtResource("item_definition")',
        f'id = &"{boon_id}"',
        f'display_name = "{boon["name"]}"',
        f'description = "{boon["desc"]}"',
        'icon = ExtResource("icon")',
        "kind = 1",
        f"boon_pool = {pool_val}",
        f'effects = Array[ExtResource("item_effect")]([{", ".join(effect_refs)}])',
        "",
    ]
    return "\n".join(lines)


def render_pool(pool_name: str, boons: list[dict]) -> str:
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
        '[gd_resource type="Resource" script_class="LootPool" format=3]',
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


def main() -> None:
    from generate_boon_icons import generate_icons

    generate_icons(BOONS)
    BOONS_DIR.mkdir(parents=True, exist_ok=True)
    POOLS_DIR.mkdir(parents=True, exist_ok=True)

    for boon in BOONS:
        content = render_boon(boon)
        out = BOONS_DIR / f'{boon["id"]}.tres'
        out.write_text(content, encoding="utf-8")
        print(f"Wrote {out.relative_to(ROOT)}")

    pools: dict[str, list] = {k: [] for k in POOL_ENUM}
    for boon in BOONS:
        pools[boon["pool"]].append(boon)

    for pool_name, pool_boons in pools.items():
        content = render_pool(pool_name, pool_boons)
        out = POOLS_DIR / f"{pool_name}_boon_pool.tres"
        out.write_text(content, encoding="utf-8")
        print(f"Wrote {out.relative_to(ROOT)} ({len(pool_boons)} boons)")

    print(f"\nTotal boons: {len(BOONS)}")


if __name__ == "__main__":
    main()
