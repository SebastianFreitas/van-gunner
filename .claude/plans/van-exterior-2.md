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
