---
paths:
  - "resources/items/**"
  - "scenes/items/**"
  - "scenes/enemies/**"
  - "scenes/shop/**"
  - "scenes/mechanic/**"
  - "tools/gen_enemy_sprites.py"
  - "tools/generate_boon_icons.py"
  - "scripts/enemies/window_raider_anim.gd"
---

## Pixel art (NPCs, raiders, bosses, items, pickups, wares, icons)

Reference: the shopkeeper, `scenes/shop/vendor.png` (23 flat colours, hard
edges, shading baked in as flat tones). Its pose and palette are the
target; its grid is not (it is upscaled about 3.2x off any exact grid).

- Drawn at native size, one image pixel = one art pixel. Never upscale a
  PNG; the size on screen comes from `pixel_size`.
- One world density: every world `Sprite3D` uses `pixel_size = 0.024`
  (one art pixel = 2.4 cm). A human is a 64 x 96 canvas (2.3 m, today's
  raider height). A bigger enemy gets a bigger canvas (the boss about
  96 x 144), never a node scale or a different `pixel_size`. Items use
  the smallest canvas that holds them (a shell about 8 px, a medkit about
  16 px).
- HUD and boon icons: 32 x 32 art pixels, shown at a whole-number scale.
- Flat colour only: a limited palette (about 16 to 32 colours per sprite),
  no anti-aliasing, no soft outlines or glows, no gradients and no
  dithered ramps. Alpha is 0 or 255, nothing between.
- Hard shadows: light from the upper left, each material gets a base tone,
  one shadow tone and at most one highlight tone, split by a hard edge.
- An outline, if any, is a hard one-art-pixel line.
- Display: `texture_filter = 0` (nearest), no mipmaps, `alpha_cut = 1`
  (discard), unshaded (the art carries its own shading), billboard for
  characters and pickups. Sprites are unshaded on purpose: in a dark world
  they are what the eye finds first.

The loper's sheet (the door and window raider) is `art-loper.md`.

Off-style today, to redraw to this rule (not to copy from): the mechanic
and Wanjna PNGs (painted, 10,000+ colours, soft red outline), the other
world sprites' `pixel_size` (0.006 NPCs and Wanjna, 0.005 pickups), the
shopkeeper's linear filtering, the boss's 1.5x node scale, and the boon
icons (`tools/generate_boon_icons.py` draws anti-aliased 128 px SVG
strokes with round caps). The pixel-art pass is a later task.
