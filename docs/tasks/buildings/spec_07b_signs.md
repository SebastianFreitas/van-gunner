You are implementing the signage step of a procedural street-building system in a Godot 4.7 GDScript project at C:\Users\Traff\Documents\van-gunner (Windows; `py -3`). Existing: `scripts/travel/facades/` (`facade_materials.gd`, `facade_keep_out.gd`, `facade_plan.gd`, `facade_body.gd` with public `add_quad`, `facade_props_upper.gd`, `facade_props_ground.gd`, `corridor_facades.gd`, `facade_registry.gd`, `facade_district.gd` with `sign_words`/`sign_chance`), `scenes/corridor/facade_surface.gdshader`, and `scripts/stops/block_glyphs.gd` (`BlockGlyphs.make_label`, `make_vertical_label`, `text_width_px`). Read all of those first (each under 300 lines; grep -n then read ranges for anything longer).

# Project rules
- GDScript: tabs, LF, ~100 columns, two blank lines between functions, everything typed, `&"..."` StringNames, `##` docs; comments explain why. Helpers are `RefCounted`, no `class_name`, no `await`, never preload/name an autoload. Scripts <= 300 lines target, 400 cap.
- Every placed node's AABB goes through `keep_out.allows(aabb)` (build it with `FacadeKeepOut.box_aabb(center, size, yaw)`); never bypass it. Quads are emitted only through `facade_body.add_quad` (runtime winding oracle).
- Never launch Godot with a window; never open `.png`/`.import`/`.godot/`.
- No sign word may read like a stop; words come only from the district resource.

# 1. `scenes/corridor/facade_sign.gdshader` (CREATE, ~70 lines)
`shader_type spatial; render_mode diffuse_burley, specular_schlick_ggx, cull_back;`
Uniforms: `sampler2D text_tex : source_color, filter_nearest;` (label texture: `fg` text on `bg`), `vec3 color : source_color = vec3(1.0, 0.85, 0.6);`, `float energy = 2.4;`, `int mode = 0;` (0 backlit box, 1 neon, 2 poster), `float seed = 0.0;`, `float dead_ratio : hint_range(0.0, 1.0) = 0.0;`, `float flicker_amount : hint_range(0.0, 1.0) = 0.0;`, `float letter_cells = 8.0;` (how many horizontal cells the dead-letter hash uses).
Fragment: `vec4 t = texture(text_tex, UV);` `float ink = t.a > 0.5 ? step(0.5, dot(t.rgb, vec3(0.333))) : 0.0;` — treat the label as: text pixels are bright (fg), background dark (bg). Simpler and robust: the label textures are built with `fg = Color(1,1,1,1)` and `bg = Color(0,0,0,1)`, so `ink = t.r`.
- mode 0 (backlit box): `ALBEDO = mix(vec3(0.02), color * 0.15, 1.0 - ink);` `EMISSION = mix(color * energy * 0.45, vec3(0.02), ink)` (dark letters on a glowing panel); ROUGHNESS 0.4.
- mode 1 (neon): letters glow: per-cell dead hash `float cell = floor(UV.x * letter_cells); float dead = step(hash11(cell + seed), dead_ratio);` (copy `hash11` from the facade shader); `float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * 17.0 + seed) * sin(TIME * 5.3 + cell));` `EMISSION = color * energy * ink * (1.0 - dead) * clamp(flick, 0.0, 1.0)`; `ALBEDO = mix(vec3(0.03), color * 0.25, ink)`; a soft halo: `+ color * energy * 0.08 * (1.0 - ink) * (1.0 - dead)` on EMISSION when `textureLod(text_tex, UV, 2.0).r > 0.1` (cheap blur via a mip level; label textures must have mipmaps: build them with `img.generate_mipmaps()` before `create_from_image`); ROUGHNESS 0.3.
- mode 2 (poster): no emission: `ALBEDO = mix(color, vec3(0.06), ink) * (0.7 + 0.3 * fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453))` (paper with ink and a grain), ROUGHNESS 0.95.

# 2. `scripts/travel/facades/facade_materials.gd` (EDIT: add)
- `static var _sign_shader: Shader` + `static func sign_shader() -> Shader` (lazy load of the new shader).
- `static var _label_cache: Dictionary = {}`; `static func label_texture(text: String, scale: int, vertical: bool) -> ImageTexture` — key `"%s|%d|%s" % [text, scale, vertical]`; builds with `BlockGlyphs.make_label` / `make_vertical_label` using fg `Color(1, 1, 1, 1)`, bg `Color(0, 0, 0, 1)`, pad 2; then (since make_label returns an ImageTexture) rebuild with mipmaps: get `tex.get_image()`, `img.generate_mipmaps()`, `ImageTexture.create_from_image(img)`; cache.
- `static func sign_material(text: String, scale: int, vertical: bool, color: Color, energy: float, mode: int, seed: float, dead_ratio: float, flicker_amount: float, letter_cells: float) -> ShaderMaterial` — new material each call (uniforms differ), sets every uniform.

# 3. `scripts/travel/facades/facade_signs.gd` (CREATE, <= 260 lines)
```
extends RefCounted
## Street signage for one building: a backlit box sign over a storefront, a neon strip, a
## perpendicular blade sign, a cloth banner, or a torn poster on a boarded front. One word per
## building from the district's list; every sign passes the keep-out gate.
```
Preloads `_FacadeKeepOut`, `_FacadePlan`, `_FacadeBody`, `_FacadeMaterials`. Constants: `MAX_SIGNS_PER_BUILDING := 1`, `FACE_GAP := 0.03`, `BOX_DEPTH := 0.25`, `BLADE_SIZE := Vector3(1.4, 6.0, 0.25)`, `BLADE_BOTTOM_Y := 6.2`, `POSTER_SIZE := Vector2(0.9, 1.2)`.
- `static func build(host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator, district: FacadeDistrict) -> void`:
  1. `if rng.randf() >= district.sign_chance: return` (roll first, always, to keep the RNG stream aligned). `if plan.get(&"mouth", false): return`. Words: `if district.sign_words.is_empty(): return`; `var word: String = district.sign_words[rng.randi() % district.sign_words.size()]`.
  2. Pick a kind: ground_kind 1 (storefront) -> `box` (70 %) or `neon` (30 %); ground_kind 2 (boarded) -> `poster`; ground_kind 5 (arcade) -> `banner`; otherwise (blank/roll-up/dock) -> `blade` when `plan.width >= 8.0` (40 %), else nothing. Commercial buildings (`plan.district_id == &"commercial"`) that got `box` upgrade to `blade` with 35 %.
  3. Geometry (tile-local; face at `x_face = _FacadePlan.face_x(plan, side_sign)`; "out" is `-side_sign`; u -> z as in `facade_body._u` inverse; y0 = `_FacadePlan.BASE_Y`):
     - box: on the first storefront unit (unit_w = width / ground_units): a box `(BOX_DEPTH, 0.7, min(unit_w - 1.2, 6.0))` centred at u = unit centre, y = y0 + 3.8 (inside the fascia band 3.4..4.2), protruding `FACE_GAP + BOX_DEPTH / 2`; its road-facing face carries the sign material (mode 0); the other five faces a dark `prop_material(&"sign_box", Color(0.05, 0.05, 0.05), 0.7, 0.3)`. Build the box as two surfaces: emit the five dark faces into one SurfaceTool and the text face into another; commit the first, `st2.commit(mesh)` to append the second surface, then `mesh.surface_set_material(0, dark)` and `(1, sign_mat)` (no `material_override`). Text face UV: u 0..1 left-to-right as seen from the road, v 0..1 bottom-to-top (the label texture's row 0 is the top: so v = 1 at the quad's bottom... `Image` row 0 is the top of the picture; Godot samples UV.y = 0 at the top of the texture; so give the quad's TOP edge v = 0 and BOTTOM edge v = 1). Label scale 4.
     - neon: a quad `(0.02 thick)` 3.6 x 0.8 m at y 4.9..5.7 (above the fascia, below 6.0 is fine: it is at the face, not over the road), 0.05 off the face, mode 1, colour from a small neon palette picked by rng (pink (1.0, 0.3, 0.6), cyan (0.4, 0.9, 1.0), amber (1.0, 0.7, 0.3), green (0.5, 1.0, 0.5), red (1.0, 0.35, 0.3)), `dead_ratio` = district.dead_lamp_chance, `flicker_amount` 0.3 in derelict else 0.1, `letter_cells` = word length. Single-surface mesh with the sign material (quad through `add_quad`).
     - blade: perpendicular box `BLADE_SIZE` (x extent 1.4 out from the face, y 6.0 tall, z 0.25) centred at u = width * 0.5 +- 1.0 (rng), bottom at y0 + BLADE_BOTTOM_Y, x centre = x_face - side_sign * (FACE_GAP + 0.7). Its two large faces (normals +-Z) carry a vertical label (mode 1, scale 4, `make_vertical_label`); the other faces dark. Same two-surface technique. AABB check: `box_aabb(center, BLADE_SIZE)` — passes the lane box (bottom 5.8 above 6.0? BLADE_BOTTOM_Y 6.2 - 0.4 base = y 5.8 in tile space is BELOW LANE_TOP_Y 6.0 and x reaches 7.37 < 7.6 → rejected!). So set `BLADE_BOTTOM_Y := 6.6` (tile y 6.2) so it clears the lane box; keep the constant and the reason as a comment.
     - banner: a cloth quad 2.4 x 0.9 between two window columns at floor 1 (y = y0 + GROUND_HEIGHT + 1.2), 0.08 off the face, mode 2 (unlit), colour a muted palette (rust, navy, bottle green); label scale 3.
     - poster: a quad 0.9 x 1.2 on the boarded front at y0 + 1.6..2.8, u = 1.0 + rng * (width - 2.0), 0.03 off the face, mode 2, colour paper (0.8, 0.72, 0.55), label scale 3; 60 % rotated by +-4 deg about X? Keep flat (no rotation) for simplicity.
  4. Every mesh: `cast_shadow` OFF, `visibility_range_end` 64.0 (the post-pass in corridor_facades also sets it; setting it here is harmless), node names `SignBox`, `SignNeon`, `SignBlade`, `SignBanner`, `SignPoster`.
  5. Before adding any sign node: build its AABB (box_aabb of the mesh's bounding box in tile space) and `if not keep_out.allows(aabb): return`.

# 4. `scripts/travel/facades/corridor_facades.gd` (EDIT)
After the ground props call for each plan, add `_FacadeSigns.build(root, plans_out[i], SIDE_SIGNS[side_idx], keep_out, rng, district_res)`. Keep the call order: body -> flank collision -> upper props -> ground props -> signs.

# Edge cases
- Words containing characters `BlockGlyphs.pattern` doesn't know draw as gaps; acceptable, but do log nothing.
- Label textures are cached by (text, scale, vertical) so the same word costs one Image.
- A blade on the LEFT side must read correctly from the road: the text face facing +Z on the right side corresponds to facing... give both large faces the label so reading direction never matters; the vertical label reads top-to-bottom on both.
- Label UV orientation is the most likely mistake: state in your report which UV you gave the top edge and why.

# Do not touch
The facade shader, `facade_body.gd`, `facade_keep_out.gd`, `facade_plan.gd`, `corridor_segment.*`, `travel_*.gd`, `van.tscn`, balance/export files, baselines.

# Verification
`py -3 tools/check.py` clean (shader compile errors surface here); `py -3 tools/smoke.py` passes with `bay mouth clear:` still logged and the fingerprint unchanged; a one-off headless sanity script outside the repo that configures a `corridor_segment.tscn` instance for each district with seeds 1..6, prints how many `Sign*` nodes were built per side and their names, and asserts no `Sign*` node exists on a side after `open_bay` on it. Report check tail, smoke tail (30 lines), sanity output, `wc -l`, `git status --short`. Do not commit.
