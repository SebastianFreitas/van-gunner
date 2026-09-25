---
paths:
  - "scenes/**/*.tscn"
  - "scenes/**/*.gdshader"
  - "resources/facades/**"
  - "resources/items/**"
  - "scripts/travel/facades/**"
  - "tools/generate_boon_icons.py"
---

# Art style

Owner's direction (2026-09-25): two styles, one look. The 3D world is
low-poly and stylised; everything that is a character or a thing you pick
up is pixel art. Nothing realistic, no gradients, hard shadows. None of the
current art is final, but every new or changed asset follows this file, so
the game converges instead of drifting.

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
  characters and pickups.

Off-style today, to redraw to this rule (not to copy from): the mechanic,
door raider, agile raider and Wanjna PNGs (painted, 10,000+ colours,
soft red outline), every world sprite's `pixel_size` (0.006 NPCs, 0.005
pickups), the shopkeeper's linear filtering, the boss's 1.5x node scale,
and the boon icons (`tools/generate_boon_icons.py` draws anti-aliased
128 px SVG strokes with round caps).

## Low-poly 3D (van, street, facades, stops, props)

- Built from primitives or simple meshes with hard edges (flat normals).
  No imported realistic models, photo textures, normal maps or subdivided
  surfaces.
- Materials: a flat albedo colour per surface, `diffuse_mode` toon,
  `specular_mode` toon or disabled, `metallic = 0`, high roughness. No
  reflective sheen.
- Surface detail is flat-colour shapes (panels, stripes, boards, window
  frames, a stain as one flat blob), not noise. In shaders, colour changes
  with `step` or `floor` bands, never `smoothstep` blends, fbm noise or
  hash grime.
- Lights cast crisp shadows: shadow blur and light angular distance kept
  at 0 or near it. No SSAO.
- The only soft things: distance fog (the street fading into the dark) and
  glow on things that emit light (lamps, muzzle flash, lit windows).

Off-style today, to migrate (don't extend): `industrial_surface.gdshader`,
`facade_surface.gdshader` and `asphalt_surface.gdshader` all build their
look from fbm noise, hash grime and `smoothstep` gradients, and the bay
materials use `metallic` 0.5 to 0.72. A change to one of them moves it
toward this file; nobody adds more noise or grime.

## Checking it

- Anything visible gets `tools/smoke.py --shots`; compare the PNGs with
  the shopkeeper and with this file before reporting.
- A new sprite: check it with `py -3 -c` and PIL before wiring it in
  (colour count, alpha levels only 0 and 255, size matches its canvas).
- The implementer never sees this file: copy the rules that apply into
  the spec's Rules section, including the exact `pixel_size`,
  `texture_filter` and `alpha_cut` values.
