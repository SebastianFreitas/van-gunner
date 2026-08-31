#!/usr/bin/env python3
"""Generate themed SVG icons for boon items."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "scenes" / "items" / "boons"

POOL_STYLES = {
    "general": {"bg": "#1c2420", "stroke": "#5bd68f", "accent": "#8ef0b0", "inner": "#2f5a42"},
    "fire": {"bg": "#241c18", "stroke": "#ff8a3d", "accent": "#ffd166", "inner": "#6a3018"},
    "poison": {"bg": "#1a2418", "stroke": "#7ddf4a", "accent": "#b8ff6a", "inner": "#2f4a22"},
    "cold": {"bg": "#182028", "stroke": "#7ec8ff", "accent": "#c8e8ff", "inner": "#284a5a"},
    "physical": {"bg": "#201e18", "stroke": "#c8a86a", "accent": "#e7c45b", "inner": "#4a3a28"},
}

# Inner glyph markup per boon id (128x128 canvas, centered around 64,64).
GLYPHS: dict[str, str] = {
    # General / life
    "max_hp_1": '<path d="M64 34 C52 22 34 26 34 44 C34 62 64 86 64 86 C64 86 94 62 94 44 C94 26 76 22 64 34 Z" fill="{inner}"/><path d="M58 50 h12 M64 44 v12" stroke="{accent}" stroke-width="6" stroke-linecap="round"/>',
    "max_hp_2": '<path d="M64 30 C48 16 26 22 26 44 C26 66 64 94 64 94 C64 94 102 66 102 44 C102 22 80 16 64 30 Z" fill="{inner}"/><path d="M54 48 h20 M64 38 v20" stroke="{accent}" stroke-width="7" stroke-linecap="round"/>',
    "max_hp_3": '<path d="M64 26 C44 10 18 18 18 44 C18 70 64 102 64 102 C64 102 110 70 110 44 C110 18 84 10 64 26 Z" fill="{inner}"/><path d="M48 42 h32 M64 26 v32" stroke="{accent}" stroke-width="8" stroke-linecap="round"/>',
    "max_hp_heal": '<path d="M64 34 C52 22 34 26 34 44 C34 62 64 86 64 86 C64 86 94 62 94 44 C94 26 76 22 64 34 Z" fill="{inner}"/><path d="M58 50 h12 M64 44 v12" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><circle cx="88" cy="36" r="10" fill="{accent}"/>',
    "max_hp_phys": '<path d="M64 38 C54 28 40 32 40 46 C40 60 64 80 64 80 C64 80 88 60 88 46 C88 32 74 28 64 38 Z" fill="{inner}"/><rect x="46" y="54" width="36" height="22" rx="6" fill="{accent}"/>',
    "ricochet_stack": '<path d="M20 78 L52 46 L78 58 L108 28" fill="none" stroke="{accent}" stroke-width="7" stroke-linecap="round"/><circle cx="52" cy="46" r="8" fill="{accent}"/><circle cx="78" cy="58" r="8" fill="{stroke}"/><circle cx="108" cy="28" r="8" fill="{stroke}"/>',
    "shoot_speed": '<rect x="34" y="58" width="52" height="16" rx="4" fill="{inner}"/><path d="M86 66 h18" stroke="{accent}" stroke-width="8" stroke-linecap="round"/><path d="M44 40 l12 26 l-8 0 l6 18 l-16 -22 l10 0 z" fill="{accent}"/>',

    # Fire
    "fire_greed": '<path d="M64 24 C58 40 42 44 42 60 C42 76 52 88 64 92 C76 88 86 76 86 60 C86 44 70 40 64 24 Z" fill="{inner}"/><path d="M54 70 h20" stroke="{accent}" stroke-width="6" stroke-linecap="round"/>',
    "ricochet_explosive": '<path d="M24 78 L54 48 L82 60 L104 30" fill="none" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><circle cx="82" cy="60" r="16" fill="none" stroke="{stroke}" stroke-width="5"/><circle cx="82" cy="60" r="5" fill="{accent}"/>',
    "increased_fire_area": '<circle cx="64" cy="64" r="18" fill="{accent}"/><circle cx="64" cy="64" r="30" fill="none" stroke="{stroke}" stroke-width="5"/>',
    "increased_fire_area_2": '<circle cx="64" cy="64" r="16" fill="{accent}"/><circle cx="64" cy="64" r="28" fill="none" stroke="{stroke}" stroke-width="5"/><circle cx="64" cy="64" r="38" fill="none" stroke="{accent}" stroke-width="4"/>',
    "increased_fire_area_3": '<circle cx="64" cy="64" r="14" fill="{accent}"/><circle cx="64" cy="64" r="26" fill="none" stroke="{stroke}" stroke-width="4"/><circle cx="64" cy="64" r="38" fill="none" stroke="{stroke}" stroke-width="4"/><circle cx="64" cy="64" r="48" fill="none" stroke="{accent}" stroke-width="3"/>',
    "double_fire": '<path d="M64 28 C58 42 48 46 48 58 C48 70 56 78 64 80 C72 78 80 70 80 58 C80 46 70 42 64 28 Z" fill="{inner}"/><path d="M58 54 h12 M64 48 v12" stroke="{accent}" stroke-width="5" stroke-linecap="round"/><path d="M64 28 v-6 M64 86 v6" stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>',
    "delayed_fire": '<circle cx="64" cy="64" r="22" fill="{inner}"/><path d="M64 48 v18 l12 8" stroke="{accent}" stroke-width="5" stroke-linecap="round"/><circle cx="64" cy="64" r="30" fill="none" stroke="{stroke}" stroke-width="4" stroke-dasharray="8 6"/>',
    "push_force_fire": '<circle cx="64" cy="64" r="16" fill="{accent}"/><path d="M24 64 h16 M88 64 h16 M64 24 v16 M64 88 v16" stroke="{stroke}" stroke-width="6" stroke-linecap="round"/>',
    "pull_fire": '<circle cx="64" cy="64" r="16" fill="{accent}"/><path d="M40 64 h12 M76 64 h-12 M64 40 v12 M64 76 v-12" stroke="{stroke}" stroke-width="6" stroke-linecap="round"/>',
    "extra_poison_to_fire": '<path d="M64 30 C58 42 48 46 48 58 C48 72 64 86 64 86 C64 86 80 72 80 58 C80 46 70 42 64 30 Z" fill="{inner}"/><circle cx="86" cy="42" r="10" fill="{accent}"/><path d="M82 42 h8 M86 38 v8" stroke="{bg}" stroke-width="3" stroke-linecap="round"/>',
    "fire_death": '<path d="M64 34 C58 46 46 50 46 62 C46 76 64 92 64 92 C64 92 82 76 82 62 C82 50 70 46 64 34 Z" fill="{inner}"/><path d="M52 78 h24" stroke="{accent}" stroke-width="5" stroke-linecap="round"/><circle cx="64" cy="88" r="10" fill="{accent}"/>',

    # Poison
    "twice_fast_poison": '<path d="M64 30 C58 42 50 46 50 58 C50 72 64 88 64 88 C64 88 78 72 78 58 C78 46 70 42 64 30 Z" fill="{inner}"/><path d="M48 54 h32 M56 64 h16" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>',
    "poison_duration": '<ellipse cx="64" cy="58" rx="18" ry="24" fill="{inner}"/><path d="M64 34 v10 M58 30 h12" stroke="{accent}" stroke-width="5" stroke-linecap="round"/><path d="M40 78 h48" stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>',
    "poison_follow": '<path d="M24 78 L50 52 L74 64 L104 36" fill="none" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><ellipse cx="74" cy="64" rx="10" ry="14" fill="{inner}"/>',
    "weaker_poison": '<circle cx="64" cy="58" r="20" fill="{inner}"/><path d="M48 72 h32" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><path d="M54 48 h20" stroke="{stroke}" stroke-width="5" stroke-linecap="round"/>',
    "poisoned_cold": '<ellipse cx="52" cy="58" rx="12" ry="16" fill="{inner}"/><path d="M78 42 l8 10 l-8 10 l-8 -10 z" fill="{accent}"/>',
    "vampiric_poison": '<path d="M64 34 C54 24 38 30 38 46 C38 64 64 88 64 88 C64 88 90 64 90 46 C90 30 74 24 64 34 Z" fill="{inner}"/><path d="M58 52 h12 M64 46 v12" stroke="{accent}" stroke-width="4" stroke-linecap="round"/>',
    "instant_poison": '<polygon points="64,30 88,78 40,78" fill="{inner}"/><path d="M58 68 h12" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>',
    "poison_explosions": '<circle cx="64" cy="58" r="18" fill="{inner}"/><path d="M34 58 h12 M82 58 h12 M64 28 v12 M64 78 v12" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>',

    # Cold
    "chance_freeze_1": '<path d="M64 28 v72 M28 64 h72 M38 38 l52 52 M90 38 l-52 52" stroke="{stroke}" stroke-width="5" stroke-linecap="round"/><circle cx="64" cy="64" r="10" fill="{accent}"/>',
    "chance_freeze_2": '<path d="M64 24 v80 M24 64 h80 M34 34 l60 60 M94 34 l-60 60" stroke="{stroke}" stroke-width="5" stroke-linecap="round"/><circle cx="64" cy="64" r="14" fill="{accent}"/>',
    "longer_freeze": '<path d="M64 30 v68 M34 64 h60" stroke="{stroke}" stroke-width="5" stroke-linecap="round"/><rect x="52" y="52" width="24" height="24" rx="4" fill="{accent}"/>',
    "phys_to_cold_crit": '<circle cx="52" cy="58" r="14" fill="{inner}"/><path d="M72 44 l16 28 l-16 28" fill="none" stroke="{accent}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>',
    "frozen_damage": '<path d="M64 30 l10 18 h20 l-16 12 l6 20 l-20 -14 l-20 14 l6 -20 l-16 -12 h20 z" fill="{inner}"/><path d="M48 78 h32" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>',
    "more_frozen_loot": '<rect x="40" y="46" width="48" height="30" rx="4" fill="{inner}"/><path d="M48 58 h32 M48 66 h20" stroke="{accent}" stroke-width="4" stroke-linecap="round"/><path d="M64 30 l8 16 h-16 z" fill="{accent}"/>',
    "added_cold_projectile": '<circle cx="48" cy="64" r="10" fill="{inner}"/><circle cx="80" cy="64" r="10" fill="{accent}"/><path d="M58 64 h12" stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>',
    "cold_shattering_ricochet": '<path d="M24 78 L54 48 L82 60" fill="none" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><path d="M70 42 l8 8 l-8 8 l-8 -8 z M88 54 l6 6 l-6 6 l-6 -6 z" fill="{stroke}"/>',
    "cold_shatter": '<path d="M64 34 l12 18 l18 4 l-10 16 l6 20 l-26 -12 l-26 12 l6 -20 l-10 -16 l18 -4 z" fill="{inner}"/><circle cx="64" cy="64" r="28" fill="none" stroke="{accent}" stroke-width="4"/>',
    "poisoned_chill": '<ellipse cx="50" cy="60" rx="12" ry="16" fill="{inner}"/><path d="M78 42 l10 12 l-10 12 l-10 -12 z" fill="{accent}"/>',

    # Physical
    "more_phys_10": '<rect x="46" y="52" width="36" height="24" rx="6" fill="{inner}"/><path d="M82 64 h16" stroke="{accent}" stroke-width="8" stroke-linecap="round"/><text x="58" y="70" fill="{accent}" font-size="16" font-family="sans-serif">+</text>',
    "more_phys_25": '<rect x="42" y="50" width="44" height="28" rx="6" fill="{inner}"/><path d="M86 64 h18" stroke="{accent}" stroke-width="8" stroke-linecap="round"/><text x="52" y="70" fill="{accent}" font-size="14" font-family="sans-serif">++</text>',
    "more_phys_50": '<rect x="38" y="48" width="52" height="32" rx="6" fill="{inner}"/><path d="M90 64 h20" stroke="{accent}" stroke-width="8" stroke-linecap="round"/><text x="50" y="70" fill="{accent}" font-size="12" font-family="sans-serif">+++</text>',
    "double_phys_cold": '<rect x="40" y="54" width="28" height="20" rx="4" fill="{inner}"/><path d="M74 44 l14 20 l-14 20" fill="none" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><text x="46" y="68" fill="{accent}" font-size="14" font-family="sans-serif">x2</text>',
    "triple_crit_phys": '<circle cx="64" cy="58" r="22" fill="{inner}"/><circle cx="64" cy="58" r="8" fill="{accent}"/><path d="M64 30 v10 M64 76 v10 M38 58 h10 M80 58 h10" stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>',
    "fire_to_phys_50": '<path d="M50 42 C46 52 40 54 40 62 C40 72 50 78 56 78 C62 78 64 72 64 72 C64 72 66 78 72 78 C78 78 88 72 88 62 C88 54 82 52 78 42 Z" fill="{inner}"/><rect x="46" y="54" width="36" height="18" rx="4" fill="{accent}"/>',
    "fire_to_phys_100": '<path d="M48 40 C44 50 38 52 38 62 C38 74 50 80 58 80 C64 80 64 74 64 74 C64 74 64 80 70 80 C78 80 90 74 90 62 C90 52 84 50 80 40 Z" fill="{accent}"/><rect x="44" y="54" width="40" height="20" rx="4" fill="{inner}"/>',
    "reduced_speed_more_phys": '<rect x="38" y="56" width="52" height="18" rx="8" fill="{inner}"/><path d="M90 65 h14" stroke="{accent}" stroke-width="10" stroke-linecap="round"/><path d="M30 64 h10" stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>',
}


def icon_path(boon_id: str) -> str:
    return f"res://scenes/items/boons/{boon_id}.svg"


def render_icon(boon_id: str, pool: str) -> str:
    style = POOL_STYLES[pool]
    glyph = GLYPHS[boon_id].format(**style)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
        f'  <circle cx="64" cy="64" r="56" fill="{style["bg"]}" stroke="{style["stroke"]}" stroke-width="7"/>\n'
        f"  {glyph}\n"
        "</svg>\n"
    )


def generate_icons(boon_specs: list[dict]) -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    for boon in boon_specs:
        boon_id = boon["id"]
        pool = boon["pool"]
        if boon_id not in GLYPHS:
            raise KeyError(f"Missing glyph for boon: {boon_id}")
        out = ICON_DIR / f"{boon_id}.svg"
        out.write_text(render_icon(boon_id, pool), encoding="utf-8")


if __name__ == "__main__":
    from generate_boons import BOONS

    generate_icons(BOONS)
    print(f"Wrote {len(BOONS)} icons to {ICON_DIR.relative_to(ROOT)}")
