# Van exterior, round two: light it, audit it, fix it

Stage: done
Started: 2026-09-26
Procedure: `.claude/skills/plan/SKILL.md` (planning loop, then one phase
per context: "Read PLAN_STATE.md and execute the next phase.").

## Brief (owner's words, verbatim)

> we need to do another whole overview of the van just tested the reuslt of our previous test, the frotn doesnt eixst yet, its fileld with holes the windows get all fucked wiht the light there sbillions of issue son the outside, we we need to somehow mayhke it easier to see, mayeb start just by also making a command to light stuff, to have a troch or something

## Scope

- In: `scripts/debug/` (light commands), `tools/smoke/` (lit exterior shots), `scripts/van/look/` (hull, cab, front kit, wheels), `scripts/van/side_windows.gd` and the window scenes' exterior, `scripts/van/van_front_wall.gd` seams, `.claude/rules/van-shell-and-hud.md`, `.claude/rules/art-style.md` notes.
- Out (stays exactly as is): DoorSpill, RearCone, ExteriorLight and the `*-outside` budget; interior dressing, machines, cables; door and window gameplay (breach, smash HP, weld); no shipping flashlight.

## Current state (explored 2026-09-26; anchors drift, grep the names)

- `scripts/debug/debug_commands.gd` `_register_commands()`: fixed-order `_commands` table; van group `debug_van_commands.gd` (`cmd_ghost` fly, `cmd_van` seed). No light command.
- `scripts/player/fps_player.gd`: `camera = $Head/Camera3D`, `set_ghost(on)`.
- `tools/smoke/smoke_shots.gd`: `van_views()` at IDLE under `--shots` saves side-front, side-rear, low-front and interior audit spots via `_save_van_view(rig, from, label, target)`; `_rig()` finds `TravelPath/VanFollow/VanRig`.
- `scripts/van/look/`: `van_hull.gd` + `van_hull_lines.gd` (skin from `VanBodyProfile`), `van_cab.gd` (hood, windshield, header, two headlights; the deferred P5 stub), `van_front_kit.gd`, `van_wheels.gd`, `van_armour.gd`, `van_markings.gd`, `van_marker_lights.gd`.
- Side windows (`side_windows.gd`) use the interior `RearWindowGlassMaterial` from both sides; no exterior pane or frame.
- Previous plan `van-exterior.md` deferred P5 (real cab) and P6 (chassis, arches, bumper).

## Open items

- none (rounds 1 and 2 answered 2026-09-28; round 2 opened nothing new).

## Option map (from `research/van-exterior-2-00-intake.md` and the lit shots)

**A · The cab and front** (today: `van_cab.gd` stub, a flat box with two lamp discs)
- A1 Cab-over flat face: one front plane on the body profile, windshield high with a framed reveal, grille low, bumper bar, headlights in housings at the corners, A-pillars and cab doors with their own windows. Precedent: Tatra T815 (the War Rig's cab), Isuzu NPR box trucks. Fits the van-local -Z front and the one-piece front wall.
- A2 Bonneted hood: hood ahead of the windshield, fenders, the current stub's direction. Precedent: Ford E-series, Mad Max 2015 Magnum Opus. Longer van, more geometry ahead of the profile.
- A3 Armoured snout: A1 plus cage bars over the windshield and a plough/cowcatcher on the bumper. Precedent: War Rig, Crossout cabins.
- A4 Patch the stub only: close its holes, keep its shape.

**B · Holes and seams** (today: hull skin, roof, front wall, cab back, rear face built separately)
- B1 Profile-sampled patches: corner caps, skirts and sills that take their outline from `VanBodyProfile`, closing each audited gap where it is.
- B2 One closed shell: rebuild hull + roof + cab back + rear face as a single mesh from `section_points`, seams as dark lines and bevels. Precedent: low-poly armoured SUV packs. Changes the scene dump (`--bless`).
- B3 Armour over the seams: bolt-on plates from `van_armour.gd` placed over every joint so gaps read as overlap. Precedent: War Rig plating.

**C · Side windows from outside** (today: the interior pane is the only pane, seen from both sides)
- C1 Exterior pane + frame: a second pane on layer 1 a few cm outside the interior one, dark tint, strong fresnel, no interior rim recipe, an outer frame ring and reveal. Precedent: GTA inner/outer vehicle glass. The interior stays untouched.
- C2 Bars over glass: C1 plus welded bars or mesh outside, so the glass is mostly hidden. Precedent: War Rig, prison vans.
- C3 Plated slit: the window boarded from outside with a slit; the interior view unchanged, the outside reads as armour.

**D · Underside and wheels** (today: the passenger rear wheel floats clear of the sill, no frame or bumper)
- D1 Chassis kit: arches cut into the sill with a lip, wheels tucked to the arch, frame rails, fuel tank, rear bumper with underride bar, side steps. Precedent: any box truck.
- D2 Skirts: side armour skirts down to the hubs hiding the underside, arches only. Precedent: War Rig side plating.
- D3 Leave for a later plan.

**E · The exterior read at night** (today: the unlit shots are near black by budget)
- E1 Keep the budget; let real sources do the work: headlights lighting the road ahead, tail and marker lamps glowing, a wet sheen on the skin inside the roughness bounds.
- E2 Raise the `*-outside` budget a step so the skin reads.
- E3 Inspection only: the exterior stays dark in play; `floodlight` is how it gets audited.

**F · Order** (forced): audit first then fix per area (D2), or fix the cab first since it is the largest visible gap, audit the rest after.

## Decisions

- **D1 · Debug light.** Both: `torch` (SpotLight3D on the player camera, rides along in `ghost`) and `floodlight` (four work lights around the van, whole exterior lit).
- **D2 · Scope.** Tooling, then an audit with pictures, then one fix phase per area.
- **D3 · Cab shape (A1).** Cab-over flat face: one front plane on the body profile, windshield high with a framed reveal, grille low, bumper bar, headlight housings, A-pillars and cab doors with their own windows.
- **D4 · Windows from outside (C1).** Exterior pane + frame: a second dark-tinted pane on layer 1 outside the interior one, strong fresnel, no interior rim recipe, an outer frame ring and reveal. The interior pane stays untouched.
- **D5 · Seams (B1).** Profile-sampled patches: corner caps, skirts and sills from `VanBodyProfile`, closing each audited gap where it is.
- **D6 · Underside (D1).** Chassis kit: arches cut into the sill with a lip, wheels tucked to the arch, frame rails, fuel tank, rear bumper with underride bar, side steps.
- **D7 · Night read (E1).** Keep the `*-outside` brightness budget. Real sources do the work: the new headlights light the road ahead, tail and marker lamps glow, the skin gets a faint wet sheen inside the roughness bounds that catches street lamps.
- **D8 · Order (F).** Audit first: phase 2 lists every exterior issue with a picture, and the fix phases run in the order the audit sets.
- **D9 · Through the windshield.** A dark cab with a dash glow: dashboard, seat backs and the driver's silhouette, lit only by a faint dash glow.
- **D10 · Cab length (phase 5).** Keep 3.5 m: the grille stays at `NOSE_Z` -8.2, the front axle (-7.25) under the cab floor, the headlight pools where they are.
- **D11 · Rams (phase 5).** Keep all four seeded variants, refit so every beam bolts to the bumper or the face.
- **D12 · Windshield cages (phase 5).** Keep bars, grid and slit plate seeded, welded to the new windshield frame a few cm in front of the glass.
- **D13 · Driver (phase 5).** A low-poly dark shape (head, torso, arms on the wheel), lit only by the dash glow.
- **D14 · Arches (phase 6).** Bolt-on flares: wheels stay outboard (the floor is at road level and the hold runs to the walls, so a real cut would put the wheels in the hold); each wheel gets a curved flare with a lip, a dark well plate on the skin behind the tyre, so the sill reads as stopping at the wheel.
- **D15 · Spares (phase 6).** Off the cab doors: chained upright to the body side just behind the side cargo door, below the windows, ahead of the rear wheels.
- **D16 · Exhaust (phase 6).** A short pipe under the body side between the side door and the rear wheels, ending in a turned-down tip ahead of the rear axle.
- **D17 · Window tint (phase 4).** Dim silhouettes: the outer pane about 75% opaque head-on, near-opaque at glancing angles; lamps show as small dull glows, never white streaks.
- **D18 · Side door face (phase 4).** Same paint as the hull: the leaf's outer skin wears the seeded exterior shader.
- **D19 · Pillar rebar (phase 4).** Bend it onto the body: bars follow the wall's lean a few cm off the skin, with welded standoffs.
- **D20 · Roof spot (phase 7, N5).** Hood it: keep the light and its road pool, weld a visor over the lens so from above it reads as a dark hood, dim the lens to a warm glow (emission 1.2), tilt the beam up a little so less lands on the cab roof.

## Constraints (every phase)

- Art style: procedural grime, no bitmap textures on 3D, metallic ≤ 0.3, always night, light from pointable sources. Debug lights are off by default, `DebugConfig.ENABLED` only, never on in a budgeted shot; lit shots carry a `-lit` suffix and are outside the `*-outside` budget.
- Light pairing crash: set `layers`/`light_cull_mask` before `add_child`, never change them in the tree; toggle with `visible`.
- `VanBodyProfile` is the one outline for anything meeting the wall or vault.
- `DEFAULT_VAN_SEED` 1337; new views are `--shots` only, fingerprint and scene dump unchanged unless a phase says `--bless`.
- Shared mode: commit by path to `main`, never push.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| 1 | Tooling: torch, floodlight, lit shots | code | D1 | done 74f8364 |
| 2 | Audit with pictures | research, doc | D2, D8 | done c4711c6 |
| 3 | Holes and seams | code | D5, audit | done f8d8339 |
| 4 | Side windows from outside | code | D4, D17-D19, audit | done d93335e |
| 5 | A real cab and what the windshield shows | code | D3, D9, audit | done b662a42 |
| 6 | Underside and wheels | code | D6, D14-D16, audit | done c2bf8bf |
| 7 | The night read | code | D7, D20, audit | done c970044 |

Phases 3 to 7 run in the order phase 2's audit sets (D8): **5 → 6 → 3 → 4 → 7**; the numbers are labels. Next phase = the first `todo` in that order.

## Phases

### 1 · Tooling (done)
`cmd_torch` / `cmd_floodlight` in `debug_van_commands.gd`; `van_views_lit()` in `smoke_shots.gd` (v08..v16 `van-lit-*`); rules paragraph; map regenerated.

### 2 · Audit with pictures (D2, D8)
Research: the lit shots v08..v16, extra `ghost` + `floodlight` angles if the shots miss an area.
Deliverables: `.claude/plans/research/van-exterior-2-01-audit.md`, one entry per issue (shot, builder or node, severity), grouped cab/front, holes and seams, windows, underside/wheels, night read; the run order for phases 3 to 7 written into Progress; annotated PNGs sent to the owner.
Verification: every issue in Carry forward appears in the audit; every entry names a builder.

### 3 · Holes and seams (D5)
Deliverables: every audited gap between hull skin, roof, front wall, cab back, rear face and sills closed by patches that sample `VanBodyProfile`.
Verification: check, smoke, scene dump (bless only if the phase says the tree changes), lit shots re-read against the audit entries.
Notes: done in f8d8339. `van_hull_patches.gd` (RefCounted helper of `VanHull`): `RearCornerL/R` (side strip z 4.64..4.80 + return at z 4.80, inner x ≥ 2.40), `SillL/R` (chamfered extrusion from `wall_x_at(0)+0.06`, z -4.72..4.80, replaces the boxes), `SideDoorCasingL/R` (curved shell ring 0.07 wide round the side door opening, liner +0.04..+0.19); roof lip 0.10. S5 was the road in the shade under the rear: phase 6's `RearBumper` closes it, no plate exists. Check, smoke, scene dump clean; lit v09/v14/v15 read by eye. Reviewer skipped (context line).

### 4 · Side windows from outside (D4)
Deliverables: per side window an outer frame ring and a dark-tinted pane on layer 1 from the `VanSideWall` builders, a reveal with depth, an exterior glass material with strong fresnel and no interior rim recipe. Interior pane, iron cross, breakable glass unchanged.
Verification: check, smoke, lit and unlit window close-ups, interior front/back shots unchanged by eye, `*-outside` budget.
Notes: done in d93335e. `side_window_exterior.gd` + `van_window_exterior.gdshader`: `ExteriorPane` child of each `WindowGlass` (liner +0.055, layer 1, group `van_exterior_layer` which `VanLighting.mark_interior_geometry` skips), fresnel alpha 0.75..0.97, dust from fbm; the pane mesh is double-wound so the shader discards when the camera is on the cabin side (`instance uniform outward_sign`). `van_hull_window_casings.gd`: `SideWindowCasingL0/L1/R0/R1` rings 0.07 wide, liner +0.04..+0.13. `side_doors.gd` `set_exterior_material` / `side_door_leaf.gd` `apply_exterior_material`: CurvedOuter wears the hull shader (model-space, `sill_y_m`/`accent_band` shifted by the door mid y). `van_armour.gd` pillar rebar follows `_skin_x(y)` with standoffs. Check, smoke, scene dump clean; `*-outside`/`*-back` stats unchanged within noise; lit v15 read by eye. Reviewer skipped (context line).

### 5 · A real cab and what the windshield shows (D3, D9)
Deliverables: `van_cab.gd` rebuilt as a cab-over face on the body profile (helper split past 300 lines): A-pillars, cab doors with windows, windshield with a framed reveal, grille and bumper refit from `van_front_kit.gd`, headlight housings; behind the windshield a dark cab with dashboard, seat backs, a driver silhouette and a faint dash glow.
Verification: check, smoke, scene dump, front and quarter lit shots, unlit front inside the budget.
Notes: done in b662a42. `van_cab.gd` core + `van_cab_shell.gd` (skin, liner, back lip at -4.72, back wall, floor, face with windshield hole, reveal, all from `section_points(12, true)`) + `van_cab_face.gd` (split windshield, frame, A-pillars, grille, headlight housings, cab doors) + `van_cab_parts.gd` (dash, 0.25 dash glow, seats, driver) + `van_front_kit.gd` (bumper against the face, rams bolted via `_mount_z`, cages welded to the windshield frame). Closes C1–C5 and S2; headlight spots kept (N2). Check, smoke clean, scene dump identical (built at runtime); `03-idle-outside` mean 0.0083, p95 0.0227.

### 6 · Underside and wheels (D6)
Deliverables: arches cut into the sill with a lip, wheels tucked to the arch (the floating passenger rear wheel), frame rails, fuel tank, rear bumper with underride bar, side steps.
Verification: check, smoke, scene dump, low lit side and rear shots.
Notes: done in c2bf8bf. `van_chassis.gd` (RefCounted helper of `VanWheels`): flares with lips + dark wells per wheel, side and cab steps, saddle tank (-exhaust side), toolbox + 2.3 m exhaust (exhaust side), spares at z -1.55, frame rails + rear bumper (top y 0). Tread 24 blocks. Check, smoke, scene dump clean; lit side shots read by eye. Reviewer skipped (context line).

### 7 · The night read (D7)
Deliverables: headlights that light the road ahead, tail and marker lamps glowing, a faint wet sheen on the skin inside roughness 0.78 to 0.95; all inside the `*-outside` budget.
Verification: check, smoke, unlit `--shots` through `tools/shot_stats.py` against `art-style.md`, the owner's view by eye.
Notes: done in c970044. `van_exterior.gdshader`: `wetness` 0.7 / `wet_specular` 0.65 / `wet_normal_strength` 0.25; wet from rain streaks, fbm patches and upward faces, dried over rust and the sill band, pulls roughness to `roughness_min` (clamp kept) and adds an fwidth-faded fbm NORMAL_MAP. N5 was the roof-rack spot lens (`van_roof.gd` `_build_spotlight`): `SpotVisor` + cheeks, lens glow 1.2, `SPOT_PITCH` -8. Tail glow 0.55 / 3.2 m (N3). Window dust 0.35, albedo 0.045. Headlights unchanged (N2). Check, smoke, scene dump clean; every budgeted shot at or below its before value (`03-idle-outside` 0.0080 / 0.0227). Reviewer skipped (small diff, context line).

## Carry forward

- Phase 1: `py -3 tools/smoke.py --shots DIR` writes `v08..v16-idle-van-lit-*.png` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof) with the floodlight on. First look at them: the side door leaf renders as a glossy black slab, interior lamps blow out through the rear side window, the cab is a flat box with two bare lamp discs, the passenger-side rear wheel floats clear of the sill. Phase 2 audits from these.
- Phase 2: the audit is `research/van-exterior-2-01-audit.md` (IDs C1–C5, S1–S6, W1–W5, U1–U6, N1–N5); each fix phase takes its section and re-reads its shots against those IDs. The "floating rear wheel" is really the front axle (z -7.25, x ±2.8) standing under the sideless cab (U1). The headlights already light the road (N2): phase 5 keeps those SpotLights. W1 (glossy black side door leaf, `side_door_leaf.gd` `door_body_material()`) belongs to phase 4. Not located yet: the rear step plate (S5), the floating window bars (W4), the diagonal rod (U6), the roof white disc (N5).

- Phase 5: the cab now runs from the hull's -4.72 (back lip, S2 closed) to the face at `NOSE_Z` -8.2; its side skin sits at `profile.outer_x_at(y)` (about 2.54 at the sill). Phase 6: the front wheels (`FRONT_AXLE_Z` -7.25, `WHEEL_X` 2.8) stand outside the cab side and need arches cut into the cab skin in `van_cab_shell.gd` (CabSkin) as well as the hull sill; the cab floor is `CAB_FLOOR_Y` 0.9 and the skin runs down to `BASE_Y` -0.25. Phase 3: C1/S2 no longer apply at the front; what is left is S1, S3, S4, S5, S6. The plow posts use the V-bars' side stance (about ±2.4); they read fine in the lit front shot.
- Phase 3: the side door leaf still stands about 11 cm proud of the skin inside its new casing (body 0.14 + outer skin 0.035 from the liner) and is glossy black (W1): phase 4 owns the leaf's material; the casing (liner +0.19) now frames it.
- Phase 6: the body sits at road level (floor y 0, road -0.2), so there is no visible underside: rails show only under the rear doors. U6 was the spare chains on the cab doors (spares moved). Phase 3: S5 (rear step plate) now sits just above the new `RearBumper` (z 4.92, y -0.19..-0.01): check they don't overlap.
- Phase 4: open for the owner's eye or phase 7: the lit side panes read milky tan under the floodlight (dust layer albedo 0.07 may be strong); unverified whether the casing ring closes its inner reveal face and whether the open sash clips the casing top; the rebar grid was not visible in lit v15 (check `ghost` + `torch`); `CurvedOuter`'s end caps also wear the hull paint when the door is open.
