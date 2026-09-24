#!/usr/bin/env python3
"""Generate themed SVG icons for boon items. Every boon uses the one general style."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "scenes" / "items" / "boons"

STYLE = {"bg": "#1c2420", "stroke": "#5bd68f", "accent": "#8ef0b0", "inner": "#2f5a42"}

# Inner glyph markup per boon id (128x128 canvas, centered around 64,64).
GLYPHS: dict[str, str] = {
    # Life
    "max_hp_1": '<path d="M64 34 C52 22 34 26 34 44 C34 62 64 86 64 86 C64 86 94 62 94 44 C94 26 76 22 64 34 Z" fill="{inner}"/><path d="M58 50 h12 M64 44 v12" stroke="{accent}" stroke-width="6" stroke-linecap="round"/>',
    "max_hp_2": '<path d="M64 30 C48 16 26 22 26 44 C26 66 64 94 64 94 C64 94 102 66 102 44 C102 22 80 16 64 30 Z" fill="{inner}"/><path d="M54 48 h20 M64 38 v20" stroke="{accent}" stroke-width="7" stroke-linecap="round"/>',
    "max_hp_3": '<path d="M64 26 C44 10 18 18 18 44 C18 70 64 102 64 102 C64 102 110 70 110 44 C110 18 84 10 64 26 Z" fill="{inner}"/><path d="M48 42 h32 M64 26 v32" stroke="{accent}" stroke-width="8" stroke-linecap="round"/>',
    "max_hp_heal": '<path d="M64 34 C52 22 34 26 34 44 C34 62 64 86 64 86 C64 86 94 62 94 44 C94 26 76 22 64 34 Z" fill="{inner}"/><path d="M58 50 h12 M64 44 v12" stroke="{accent}" stroke-width="6" stroke-linecap="round"/><circle cx="88" cy="36" r="10" fill="{accent}"/>',
    "max_hp_phys": '<path d="M64 38 C54 28 40 32 40 46 C40 60 64 80 64 80 C64 80 88 60 88 46 C88 32 74 28 64 38 Z" fill="{inner}"/><rect x="46" y="54" width="36" height="22" rx="6" fill="{accent}"/>',

    # Gun
    "ricochet_stack": '<path d="M20 78 L52 46 L78 58 L108 28" fill="none" stroke="{accent}" stroke-width="7" stroke-linecap="round"/><circle cx="52" cy="46" r="8" fill="{accent}"/><circle cx="78" cy="58" r="8" fill="{stroke}"/><circle cx="108" cy="28" r="8" fill="{stroke}"/>',
    "shoot_speed": '<rect x="34" y="58" width="52" height="16" rx="4" fill="{inner}"/><path d="M86 66 h18" stroke="{accent}" stroke-width="8" stroke-linecap="round"/><path d="M44 40 l12 26 l-8 0 l6 18 l-16 -22 l10 0 z" fill="{accent}"/>',
    "chew_tobacco": '<ellipse cx="64" cy="70" rx="22" ry="14" fill="{inner}"/><path d="M52 58 q12 -18 24 0" stroke="{accent}" stroke-width="8" fill="none" stroke-linecap="round"/>',
    "ricochet_rounds": '<path d="M22 34 L68 76 L106 40" fill="none" stroke="{accent}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><path d="M24 96 L104 96" fill="none" stroke="{inner}" stroke-width="8" stroke-linecap="round"/><circle cx="68" cy="76" r="11" fill="{stroke}"/><circle cx="22" cy="34" r="7" fill="{accent}"/><circle cx="106" cy="40" r="7" fill="{accent}"/>',
    "rubber_casings": '<path d="M24 92 Q42 36 64 80 Q86 34 104 92" fill="none" stroke="{accent}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><rect x="26" y="94" width="76" height="10" rx="5" fill="{inner}"/><circle cx="64" cy="80" r="10" fill="{inner}" stroke="{stroke}" stroke-width="5"/>',
}


def icon_path(boon_id: str) -> str:
    return f"res://scenes/items/boons/{boon_id}.svg"


def render_icon(boon_id: str) -> str:
    glyph = GLYPHS[boon_id].format(**STYLE)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
        f'  <circle cx="64" cy="64" r="56" fill="{STYLE["bg"]}" stroke="{STYLE["stroke"]}" stroke-width="7"/>\n'
        f"  {glyph}\n"
        "</svg>\n"
    )


def generate_icons(boon_specs: list[dict]) -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    for boon in boon_specs:
        boon_id = boon["id"]
        if boon_id not in GLYPHS:
            raise KeyError(f"Missing glyph for boon: {boon_id}")
        out = ICON_DIR / f"{boon_id}.svg"
        out.write_text(render_icon(boon_id), encoding="utf-8")


if __name__ == "__main__":
    from generate_boons import BOONS

    generate_icons(BOONS)
    print(f"Wrote {len(BOONS)} icons to {ICON_DIR.relative_to(ROOT)}")
