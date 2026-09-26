# Van exterior, round two: light it, audit it, fix it

Stage: planning
Started: 2026-09-26
Procedure: `.claude/skills/plan/SKILL.md` (running phases, one commit each).

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

- Owner (2026-09-26): do the real planning rounds before any fix phase; phase 1 (tooling) stays committed as `74f8364`. Planning loop resumes at step 2 (research wide) for these areas: the cab and front, the body holes and seams, the side windows from outside, the underside and wheels, the exterior look under light. Then the option map, then question rounds. Phases 2–6 below are a draft to rewrite from the decisions.

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

## Constraints (every phase)

- Art style: procedural grime, no bitmap textures on 3D, metallic ≤ 0.3, always night, light from pointable sources. Debug lights are off by default, `DebugConfig.ENABLED` only, never on in a budgeted shot; lit shots carry a `-lit` suffix and are outside the `*-outside` budget.
- Light pairing crash: set `layers`/`light_cull_mask` before `add_child`, never change them in the tree; toggle with `visible`.
- `VanBodyProfile` is the one outline for anything meeting the wall or vault.
- `DEFAULT_VAN_SEED` 1337; new views are `--shots` only, fingerprint and scene dump unchanged unless a phase says `--bless`.
- Shared mode: commit by path to `main`, never push.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| 1 | Tooling: torch, floodlight, lit shots | code | D1 | done |
| 2 | Audit with pictures | research, doc | D2 | todo |
| 3 | Holes and seams | code | D2, audit | todo |
| 4 | Side windows from outside | code | D2, audit | todo |
| 5 | The front: a real cab | code | D2, audit | todo |
| 6 | Underside and wheels (if the audit lists it) | code | D2, audit | todo |

## Phases

### 1 · Tooling
Deliverable: `cmd_torch` / `cmd_floodlight` in `debug_van_commands.gd`, registered after `ghost`; `van_views_lit()` in `smoke_shots.gd` with new exterior spots (front three-quarters both sides, straight front, straight rear, side window close-up, roof top-down), called from `smoke_driver.gd` after `van_views`; rules paragraph; map regenerated.
Verification: check, smoke (fingerprint same), scene dump (same), `--shots` and Read the `-lit` PNGs.

### 2 · Audit
Deliverable: `.claude/plans/research/van-exterior-2-01-audit.md`, one entry per issue (shot, builder, severity), grouped front/cab, holes and seams, windows under light, other. PNGs sent to the owner. Phase question at the start of 3: order and "leave it" entries.

### 3 · Holes and seams
Close every audited gap between hull, roof, front wall, cab back, rear face, sills; patches sample `VanBodyProfile`.

### 4 · Side windows from outside
Outer frame ring and pane on layer 1 from the `VanSideWall` builders, reveal depth, exterior glass material without the interior rim recipe; interior pane, iron cross, breakable glass untouched.

### 5 · A real cab
Rebuild `van_cab.gd` (helper split if over 300 lines): A-pillars, cab doors on the profile, windshield with depth, grille and bumper refit from `van_front_kit.gd`, headlight housings, mirrors.

### 6 · Underside and wheels
Arches, frame rails, rear bumper, steps, only if the audit lists them.

## Carry forward

- Phase 1: `py -3 tools/smoke.py --shots DIR` writes `v08..v16-idle-van-lit-*.png` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof) with the floodlight on. First look at them: the side door leaf renders as a glossy black slab, interior lamps blow out through the rear side window, the cab is a flat box with two bare lamp discs, the passenger-side rear wheel floats clear of the sill. Phase 2 audits from these.
