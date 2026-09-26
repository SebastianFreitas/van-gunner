# Task: the van becomes a procedural scrap war rig

Owner brief (2026-09-25): fix the van, make it better. Today it has no
outside (the overhead shot sees an open tray: no roof, no body, no wheels,
no hood), the machines inside are plain boxes instead of redneck
technology, and the side doors have no windows. Keep the low-poly style.
Big changes first, then detail by detail through a set of thinking lenses,
repeated for every part. Leave each step open to research, and ask the
owner when an answer changes what gets built.

The owner's answers so far (2026-09-25):

- **Identity:** a scrap war rig (Mad-Max direction): armour plates,
  cow-catcher, spikes, exhaust stacks, spotlights, a roof mount. It must
  still be a van underneath (the side doors, windows and rear doors stay
  where they are).
- **Procedural per save:** every new run builds its own van from its seed.
  **Looks only:** paint, plates, roof junk, machine models, cable runs,
  clutter and a painted name change; doors, windows, breach points,
  machines' positions and the walk space never move, so raider pathing and
  balance stay untouched.
- **Interior tech, all of it:** PCs (for the skill tree and stats),
  moving machinery (for the health points: the vitals), cables, junk,
  smoke, steam and sparks.
- **Machines show their HP:** staged damage (running and humming → sparks,
  flicker, smoke puffs → heavy smoke, stalled motor). You read van hull
  by looking around.
- **PCs replace the boards:** a PC rig is the skill-tree terminal (E, same
  panel as the request board opens today) and a second CRT shows live
  stats.
- **Side cargo doors get a gun port:** a free port (no risk): E opens a
  slot hatch, the player shoots out through it. Raiders cannot use it.
- **Visible upgrades from schematic nodes:** later, not in this task (see
  "Later" at the bottom).

The direction is `.claude/rules/art-style.md` (the van paragraph was
rewritten in step 0). Read it before every step and copy its numbers into
the spec. The existing van shaders (`scenes/van/van_*.gdshader`) stay the
reference for the interior's grime.

## How this task runs: straight through, every phase

Owner rule (2026-09-26): **never stop between steps.** Each step still lands
as its own commit, then the session goes straight on to the next step in the
same turn, through every phase to the wrap-up. The only reasons to end a
turn early are an owner question (`AskUserQuestion` mid-turn is fine and
does not end it) or a blocker only the owner can clear. When the context
fills, follow the mode file's "Context full" rule: commit, write the handoff,
keep going and let auto-compaction continue the work; never stop to ask for
a new prompt. The normal report comes once, at the end of the task (or at
the early stop), covering every step done in the turn.

Every step:

1. Re-read this file, `.claude/rules/art-style.md` and
   `.claude/rules/van-shell-and-hud.md`, plus the area rules the step names.
2. **Questions first.** If the step lists owner questions that are not yet
   answered in the Answers log at the bottom, ask them with
   `AskUserQuestion` before designing (2 to 4 options each, a recommended
   one first). Record the answers in the log. Ask anything else that would
   change what gets built; don't ask what a sensible default settles.
3. **Research** the step's open points: narrow `Explore` prompts
   (`file:line` anchors), and for a look question a quick sketch in the
   answers log (what it is made of, which primitives, which lens it
   serves).
4. Spec, implement, verify: `py -3 tools/check.py`, `py -3 tools/smoke.py`,
   `py -3 tools/scene_dump.py` (the van's scenes; `--bless` only when the
   step means to change the built tree, and say so), and for anything
   visible `py -3 tools/smoke.py --shots <scratchpad>/shots` (plus the van
   views once step 3 adds them) and `py -3 tools/shot_stats.py`. Read
   the PNGs yourself.
5. Tick the box, write what was learnt into the log, commit (the task-file
   edit goes in the same commit), keep one or two PNGs aside for the final
   report, go on to the next step.

A step that grows past its scope splits: finish the part that is done,
write the rest as a lettered step under it (for example 6b), commit, and
carry on with 6b next.

## The lenses

Every part goes through two passes. The **big pass** (phases B and C)
builds it right in silhouette and function. The **detail pass** (phase D)
walks it through every lens below, lists what each lens finds, and fixes
the best three to five findings. The lens list is the owner's "ways of
thinking"; add a lens when a step discovers one.

1. **Silhouette:** does it read at a glance, in the dark, from where the
   player actually sees it (inside at 1 to 4 m, the overhead camera, a stop)?
   Squint test on the PNG.
2. **Story:** who built it and out of what. Every part is scavenged from
   something recognizable (a washing-machine drum, a lawnmower engine, a
   beige office PC, a road sign, a car door) and fixed with welds, bolts,
   duct tape, zip ties or wire.
3. **Function:** does it look like it does its job? Cables go from a source
   to a load, belts drive a pulley, exhaust leaves the van, a fan sits on
   something hot, armour covers what raiders hit.
4. **Motion:** what moves, how fast, idle versus combat versus travelling
   (wheels follow van speed, flywheels hum, fans spin, needles wobble).
5. **Light:** every glow has a source you can point at (a screen, an LED,
   a bulb, a spark, a flame); inside the dark budget; the mask and layer
   rules in `van-shell-and-hud.md`.
6. **Damage:** healthy, hurt and dying states for anything with HP; wear
   and battle scars for everything else.
7. **Sound:** what it would sound like (hum, clank, hiss, crackle); a
   cue hook, even if the sound comes later (phase E).
8. **Variation:** what the seed changes on this part and what it must never
   change; three seeds side by side must look like three different vans
   by the same builder.
9. **Readability:** interactables, raiders and breach openings read first;
   dressing never blocks a firing line, a breach opening, a walk path or
   the gun port; nothing flickers where the player needs to aim.
10. **Performance:** merge static dressing into few meshes per material,
    no per-frame allocation, lights under the caps, shadows only where
    they matter, particles small.
11. **Art budget:** albedo, roughness, metallic, emission and no-shimmer
    rules from `art-style.md`, grime in the road's recipe.

## Guard rails (never touch in this task)

- Gameplay geometry: breach point positions and their Outside markers,
  `CabinNav` and its slots, the player containment, collision layers, the
  van's collision envelope, door and window openings, vital `vital_id`s and
  AttackMarker positions. Dressing is placed around them, never over them.
- Invariant 5 (projectile-only), invariant 10 (hull is the sum of vitals;
  staged damage only reads `VanVital` HP, it never changes it) and
  invariant 7 (no van-speed changes).
- The owner's mask-1 lights (`DoorSpill`, `RearCone`, `ExteriorLight`):
  energies unchanged (art-style exception).
- Render layers: interior meshes on layer 2 set before `add_child`; changing
  layers in the tree only via `VanLighting.retarget_layers` (the Forward+
  light-pairing crash).
- `SAVE_VERSION` and saves: the van seed derives from `run_seed`, which is
  already saved; no new save field unless a step proves it needs one (then
  bump `SAVE_VERSION`, invariant 8).
- The smoke fingerprint and `game_balance.tres` (the owner's).
- Sprites: pixel-art is its own later task. A step that wants a sprite (the
  driver, a smoke puff) asks the owner first and follows the pixel-art rules
  in `art-style.md`.

## Seed design (decided in step 0, built in step 1)

- `van_seed = hash([run_seed, "van"])`; no run (menu, IDLE before NEW, the
  scene dump, the smoke sandbox) uses a fixed default so every baseline
  stays stable.
- **One RNG stream per part:** each generator module makes its own
  `RandomNumberGenerator` seeded from `hash([van_seed, "<part id>"])`, so
  adding or reordering a part never reshuffles the others (the facade
  system learnt this the hard way: its RNG call order is frozen).
- Every generator draws from **kits**: a small list of hand-made
  variants per part plus seeded jitter (sizes, rotations, which slots are
  filled, colours from a palette). Kits stay hand-authored so every roll
  looks built, never random noise.
- `van reroll [seed]` debug command rebuilds the look live, so the owner can
  flip through vans in the game (H console).

## Steps (one commit each; tick when the commit lands)

### Phase A: foundation

- [x] 0. **Plan.** This file; the art-style van paragraph rewritten (the
  van is now a war rig built from a seed, the interior shaders stay the
  reference). Answers from the first two question rounds recorded above.

- [x] 1. **Van seed and reroll.** A `VanLook` node under the van root
  (`scripts/van/look/van_look.gd`) that computes `van_seed` as above, owns
  `rng_for(part_id: StringName) -> RandomNumberGenerator`, emits
  `look_rebuilt`, and rebuilds its child generators on `rebuild(seed)`.
  Debug command `van reroll [seed]` and `van seed` (prints it). Nothing
  visible yet. Verify the dump and smoke stay unchanged apart from the new
  node (`--bless` the dump for that one node, say so).
  Research: where `run_seed` is set on NEW versus load (`game_session.gd`,
  `session_save.gd`), and whether the van scene is loaded before the run
  seed exists (then `VanLook` rebuilds on the first `phase_changed`).

- [x] 2. **Van views for the shots.** `tools/smoke/smoke_shots.gd` gains
  three exterior cameras (side three-quarter front, side three-quarter
  rear, low front), saved as `*-van-*` shots at IDLE only, UI hidden, plus
  a `--van-seeds N` option in `tools/smoke.py` that rerolls N seeds at IDLE
  and shoots the side view of each (the variation lens). Add the new shot
  kinds to `tools/shot_stats.py`. No game change.
  Research: the exterior shots at IDLE need light: which existing light
  reaches the van's outside (the street lamps, `ExteriorLight`); if the
  van is black from outside, say so, and step 4 or 7 answers it with a real
  source (headlights, a roof spotlight), never an ambient bump.

- [x] 3. **Exterior grime shader.** `scenes/van/van_exterior.gdshader` on
  `grime.gdshaderinc`: a painted base from a `paint_color` uniform, primer
  and bare-metal patches, rust blooms at seams and sills, rain streaks,
  scratches, a dirt band at the sills, chipped paint at edges, a `plate`
  mode for welded armour (weld beads at the plate edge, heat tint, bolt
  heads). Metre-scale in model space (`surface_size_m`), roughness 0.78 to
  0.95, metallic up to 0.3, no shimmer. Plus `van_paint_palette.gd`: 6 to 10
  seeded paint schemes (base, accent, primer) inside the albedo budget.
  Test it on a temporary cube only; nothing ships on the van yet.
  **Owner questions:** how loud may the war paint be (desaturated
  military and rust tones only, or one saturated accent like a red stripe
  or a hand-painted skull, since war paint reads as danger)? Hand-painted
  name or number on the side (seeded from a word list), yes or no?

### Phase B: big changes, the outside

- [x] 3b. **Render check of the exterior shader.** Step 3's cube test
  timed out on the hidden desktop with no output (the temp scene never
  quit); headless `check.py` does not compile shaders. Folded into step 4:
  its `--shots` run is the first render of `van_exterior.gdshader`, so any
  shader compile error or off-budget look shows there. Tick with step 4.

- [x] 4. **Outer hull.** An outer skin following `VanSideWall`'s bow profile
  and `VanCeiling`'s vault, a few cm outside the liners: roof, both sides,
  rear face and sills, with the same openings cut (reuse the wall's cut
  queries so doors, windows and the future gun port line up), on layer 1
  on the exterior shader. No collision.
  Research, before the spec: **the DoorSpill trap.** `DoorSpill` sits
  inside the van and casts shadows on mask 1. The liners are layer 2, so
  today they neither receive nor shadow it; a layer-1 skin would shadow
  it everywhere except the openings, which changes the street's lighting
  (maybe for the better, maybe making raiders at the doors unreadable).
  **Decided (owner left it to the session, 2026-09-25): the skin casts
  shadows** (`cast_shadow = ON`), so the spill leaves the van only through
  its real openings: light from a source you can point at, a darker street
  around the van, and `06-combat-outside`'s excess wall wash likely drops.
  Raiders at a breach stand in an opening, so they stay lit. The check that
  can overturn it: a before/after `04-combat-*` / `06` pair plus a
  `summon enemy` shot of a raider at a side door and at a rear door; if
  either raider goes unreadable, set the skin's `cast_shadow = OFF`
  instead, and record which way it went in the log. Energies stay as they
  are either way (the owner's exception). Also check
  the overhead shot: the roof now hides the interior from the `*-outside`
  view; the shot targets may need a new row (say so, don't hide it).

- [x] 5. **Cab and front.** Hood with the engine bulge, grille behind a
  cow-catcher or ram, bumper, taped or caged headlights, windshield behind
  a welded grille, cab doors, mirrors, the cab roof. Seeded from a
  front kit (3 to 4 ram shapes, 2 to 3 grille cages).
  **Owner questions:** real headlights (two mask-1 spotlights lighting the
  road ahead, subject to the light-pairing rule and the dark budget), or
  dead lamps? Can the player see into the cab through the front cage, and
  if yes, what is there (seats, dash, steering wheel, the driver as a later
  pixel sprite, or just a headrest silhouette)?
  Research: `front_partition.gd`, `cab_door.gd`, what the player sees
  through the cage today (`01-idle-front`).

- [x] 6. **Wheels and underside.** Four (or six, seeded?) low-poly wheels
  with chunky tread blocks, spinning with the live van speed, arches,
  mud flaps, chassis rails and a sump visible under the sills, side exhaust
  pipes. Motion lens: speed comes from `travel_controller.gd` (grep its
  live-speed getter, don't add state there). The van rides a
  `PathFollow3D`: wheels are visual only.
  **Owner question:** chained spare tyres on the sides and oversized
  back wheels (war-rig stance), or a plain van stance?

  *Step 6 notes:* `VanWheels` (VanLook/Wheels) spins wheels from the van's measured motion (no travel_controller read). Chassis rails and sump skipped: the sills already reach y -0.25, below the road at -0.2, so nothing under them is visible. Rear wheels are capped at radius 0.58 so arches stay under the side-window sills (y 1.068); no axle sits in the side-door span. The wheels read as dark mass in the street shots: owed to the lighting review in step 20.

- [x] 7. **Armour kit.** Seeded welded plates, rebar cages, spikes, chained
  tyres, road-sign plates, a car door bolted on as a shield, window grilles
  on the outside of the side windows and rear-door panes. Kit rules: every
  piece is placed from a slot list around the openings (never over a
  breach opening, a window or the gun port), plates overlap with visible
  weld seams, one or two plates per side hang crooked. Merge per material.
  Research: how raiders' Outside markers and climb paths sit against the
  hull (`scenes/van/van_breach_points.tscn`), so no plate sits in a raider's
  way or clips a raider sprite.

  *Step 7 notes:* `VanArmour` (VanLook/Armour) fills five slots per side (low_front, low_mid, pillar, top, tail) that clear every window, the side door and the rear arches, merged into four meshes (plates on the hull shader in plate_mode, rebar, signs, glass). Outside window grilles were skipped: the side windows and rear panes already carry gameplay bars that raiders break and the weld kit repairs, so cosmetic bars would read as that. Chained tyres live on the cab sides from step 6. The van's flank sits in deep shadow in the street shots (the armour only shows brightened): owed to the lighting review in step 20.

- [x] 8. **Roof.** Roof rack of seeded junk: spare tyres, jerry cans, crates,
  tarp bundles, antennas, a satellite dish, a scrap wind turbine that spins
  with speed, exhaust stacks that puff smoke, a roof spotlight (a real
  light source, or dead), a mounted-gun silhouette (decoration only).
  **Owner questions:** which of these, and is there one signature roof
  piece every van gets (so every roll is recognisably "the van")? Anything
  alive up there (the redneck chickens-in-a-cage idea), or no?

  *Step 8 answers (owner, 2026-09-26):* seeded roof junk is spare tyres, jerry cans, crates, tarp bundles, antennas and a satellite dish (no wind turbine, no smoke stacks, no gun silhouette). Signature piece on every van: a live roof spotlight. Nothing alive up there.

- [ ] 9. **Paint and identity.** The seeded paint scheme across hull, cab
  and plates; the side name or number; primer patches; kill tallies or
  hand-painted marks. Then the first variation check: `--van-seeds 3` side
  by side.

### Phase C: big changes, the inside

- [ ] 10. **Interior layout sheet.** Research only, plus the answers.
  Draw a top-down map of the interior (in this file, as a text grid or a
  table): every vital and its AttackMarker, the loot hopper, the bench, the
  request and class boards, breach openings and their approach, the walk
  paths and firing lines, where the PC rig, the stats CRT, the generator,
  the cable trunks and the smoke vents go. No code.
  **Owner questions:** where does the PC rig go (replacing the request
  board in its spot, or elsewhere)? Which stats go on the stats CRT (gun
  damage, fire rate, reload, van speed, hull, gold, rare parts, act and
  street)? What does each vital become (proposal to confirm: fuse box →
  the generator with a flywheel and belts; cab relay → a relay rack of
  car batteries and a knife switch by the cab; bench → a welding bench with
  vice, grinder and pegboard; loot hopper → a scrap hopper with a crusher
  drum)?

- [ ] 11. **Machine kit framework.** `scripts/van/look/machine_parts.gd` (a
  library of low-poly part builders: motor, flywheel, belt and pulley, fan,
  car battery, jerry can, gauge, knife switch, CRT, tower PC, keyboard,
  pipe, vent, cable bundle) and `machine_motion.gd` (spin, pump, wobble,
  flicker helpers driven by `_process` on one node, not one per part), and
  `machine_damage.gd` (reads a `VanVital`'s `health_changed`, maps HP to
  healthy, hurt or dying, drives motion speed, flicker and effects).
  Research: the smoke, steam and spark look. Options to put to the owner
  with a test shot: low-poly cube or octahedron puffs (`GPUParticles3D`
  with a mesh), or pixel-art puff sprites (pixel-art rules, a later
  sprite task). Must stay inside the dark budget (sparks may bloom; smoke
  is lit, not glowing).

- [ ] 12. **The generator** (today's fuse-box vital): big pass on the kit,
  staged damage wired. Keep node name, `vital_id` and AttackMarker.

- [ ] 13. **The relay rack** (today's cab-relay vital). Same rules.

- [ ] 14. **The welding bench** (today's bench vital and `CraftingTable`
  interaction). Same rules; the bench panel still opens.

- [ ] 15. **The scrap hopper** (today's `LootMachine`): crusher drum,
  chute, a dispense animation when loot drops. Research whether it is a
  vital (the rules file says hopper; the inventory found only three
  `van_vital` instances) and fix whichever is wrong.

- [ ] 16. **PC rig, part 1: the skill-tree terminal.** Beige towers, CRTs,
  keyboard, tangled cables, a boot flicker; E opens the skill tree (the
  same `open_skill_tree()` the request board calls today), the request
  board goes. Screen look: emissive, under the glow threshold, sick green
  or amber phosphor.
  Research: how the screen shows content without a bitmap texture on a 3D
  surface (shader scanlines and blocky glyph noise, a `Label3D` in a pixel
  font, or a `SubViewport`): put the options to the owner with a test shot.

- [ ] 17. **PC rig, part 2: the stats CRT.** Live stats the owner picked in
  step 10, refreshed on the signals that change them (never per frame).
  Research: where each stat lives (grep `docs/PROJECT_MAP.md` signals).

- [ ] 18. **Cables, pipes and junk.** Seeded cable trunks along the ceiling
  ribs and walls that visibly connect the generator to the relay rack, the
  PCs, the bench and the lights (Function lens); duct-taped splices,
  zip-tied bundles, a pegboard, hanging tools, jerry cans, gas bottles,
  a car-battery bank. Nothing in the walk space or a firing line.

- [ ] 19. **Shell, inside.** Welded ribs, bolted plates and patched bullet
  holes inside the walls and ceiling; the cage bulkhead rebuilt in the kit
  style; the rear doors' inside dressed (lock bar, chains, bars). The
  existing van shaders stay; add geometry, not a new wall shader.

- [ ] 20. **Gun port, part 1: the look.** A slot hatch in each side cargo
  door leaf (`side_door_leaf.gd`): frame, sliding or hinged hatch, handle,
  seen from both sides; closed by default.
  **Owner questions:** one port per door or per leaf; sliding or hinged;
  its height (standing shot or crouch)?

- [ ] 21. **Gun port, part 2: the mechanic.** E opens and closes the hatch
  (a layer-2 interact target like `side_door_interact.gd`); open, the
  player's projectiles pass through the slot (collision gap or an
  exception on the leaf); raiders never target or use it (free port). Save
  state is not needed (ports start closed each load) unless the owner wants
  it. Rules file `enemies-and-breaching.md`: don't touch breach points.

### Phase D: detail passes (the lenses, part by part)

Each step below walks one part through all eleven lenses: shots from every
view that shows it, one line per lens in the log ("finds: …"), then the
best three to five fixes, a before/after pair in the report. **Owner
question at the start of each:** "anything you noticed on <part> while
playing?" Repeat a part (D-n b) if the owner wants another round.

- [ ] D1. Outer hull and paint.
- [ ] D2. Cab and front.
- [ ] D3. Wheels and underside.
- [ ] D4. Armour kit.
- [ ] D5. Roof.
- [ ] D6. The generator.
- [ ] D7. The relay rack.
- [ ] D8. The welding bench.
- [ ] D9. The scrap hopper.
- [ ] D10. The PC rig and stats CRT.
- [ ] D11. Cables, pipes and junk.
- [ ] D12. Shell inside, doors and the gun ports.
- [ ] D13. **Whole-van variation pass:** `--van-seeds 6`; every roll must read
  as the same builder's van and none may look broken; tune kit weights.
- [ ] D14. **Whole-van performance pass:** draw calls and frame time before
  and after the task (research how to measure headless: `Performance`
  monitors printed by a smoke hook), merge what is left unmerged.

### Phase E: sound

- [ ] E1. **Van sounds.** Hum per running machine, stuttering when hurt,
  hiss and crackle on smoke and sparks, the hatch's clank, wheel and
  engine drone with speed. Rules: `.claude/rules/audio.md`.
  **Owner question:** sounds from the existing bank only, or new ones
  (where do they come from)?

### Wrap-up

- [ ] Z. Update `art-style.md` (the van section, anything learnt) and
  `van-shell-and-hud.md` (the `VanLook` split, seed rules, the DoorSpill
  decision), add `VanLook` rows to CLAUDE.md's table, regenerate
  `docs/PROJECT_MAP.md`, delete this file in the final commit.

## Later (not this task)

- Visible upgrades: allocated schematic nodes bolt a visible part on (an
  extra plate, a bigger exhaust stack, a second fan). Leave `VanLook`'s kit
  slots able to take an "upgrade" variant; don't build it.
- The driver as a pixel sprite in the cab (the pixel-art task).

## Answers log

2026-09-25, before step 0:

- Identity: scrap war rig. Variation: looks only. Interior: PCs, machinery,
  cables, junk, smoke, all of it; PCs for skill tree and stats, machinery for
  the HP vitals. Damage: staged. PCs replace the boards. Gun port: free
  port. Visible upgrades: later.
- The run seed already exists and is saved (`GameSession.run_seed`,
  `session_save.gd`), so the van seed needs no save change.

2026-09-26, step 1:

- `VanLook` sits at `TravelPath/VanFollow/VanRig/VanLook` (a Node3D, so the
  hull parts later ride the rig). Children that implement
  `rebuild_look(look: VanLook)` are rebuilt on every `rebuild(seed)`; they
  draw from `look.rng_for(&"<part id>")`.
- The run seed is set before the van scene loads on NEW (`start_new`) and on
  load (`session_save.load_from_data`), but `VanLook` also re-derives on
  `phase_changed` and `session_loaded` whenever `run_seed` changed, so the
  order never matters. A `van reroll` sticks until the run seed changes.
- Fixed default `DEFAULT_VAN_SEED = 1337` when `run_seed == 0` (scene dump,
  no run) or `SaveSandbox.enabled` (smoke), so shots and baselines stay put.
- Scene dump blessed for the one new node; smoke fingerprint unchanged.

2026-09-26, step 2:

- The van views number themselves `v01-`… (`v01-idle-van-side-front`,
  `v02-…-side-rear`, `v03-…-low-front`, then `vNN-idle-van-seed-<n>` for
  `--van-seeds N`, seeds 1..N via `VanLook.rebuild`, the original restored),
  so the main `01`..`12` numbering the art notes cite never shifts.
  Cameras are rig-local: side views at (7, 3, ∓10), low front at (0, 1, -13),
  all aimed at (0, 1.5, 0). `shot_stats.py` reports them as kind `van`.
- **Light on the outside at IDLE:** the van is on the street, and its body
  reads as a dark silhouette lit by the `ExteriorLight` moon (it casts the
  van's shadow on the road) and the facade lamps; the rear windows glow from
  the interior. The front face is black: nothing lights it. Step 5 answers
  that with real headlights (a source you can point at), never ambient.
- Van shots are dark enough already (mean 0.013..0.017); no target yet.
  Owner rule the same day: the task now runs straight through (see "How
  this task runs").

2026-09-26, step 3 questions:

- **War paint: desaturated only.** Military drab, primer and rust tones; no
  saturated accent anywhere on the van's paint (danger colour stays on the
  raiders, fire and usables).
- **Painted name: yes.** A crude stencilled or brushed name per van, picked
  from a word list by the seed (step 9 paints it; step 3's palette may hold
  the lettering colour, off-white or faded, inside the albedo budget).

2026-09-26, step 3:

- `van_exterior.gdshader` projects model-space metres (`surface_size_m`)
  on the dominant normal axis, so any hull mesh works without UVs; plate
  mode uses UV times `plate_size_m` for weld beads, heat tint and bolts.
  `seed_offset` shifts the noise per van. `VanPaintPalette` holds 8
  desaturated schemes (base, accent, primer, lettering) with `pick(rng)`
  and `apply(material, scheme, rng)` (wear 0.35..0.8, seed offset).
- A throwaway windowed scene on the hidden desktop hung until the timeout,
  and `run_hidden` returns no output on a timeout: give any such test
  `--quit-after` and `--log-file`, or test through the smoke shots.

### Steps 5 and 6 questions (owner, 2026-09-26)

- **Headlights: real.** Two mask-1 spotlights lighting the road ahead,
  inside the dark budget, under the light-pairing rule.
- **Cab interior: seats, dash, steering wheel**, dim, with a seat kept free
  for a later pixel-sprite driver.
- **Stance: war-rig.** Oversized back wheels, chained spare tyres on the
  sides, 4 to 6 wheels seeded.

### Step 4 notes (hull)

- `VanHull` (`scripts/van/look/van_hull.gd`, node `VanLook/Hull`) builds
  `SideSkinL/R` (the liner's own panel mesh, holes included, through the new
  public `VanSideWall.build_side_panel_mesh(wall_sign)`, shifted 0.06 m
  outward; `_add_side` uses the panel helper, not `build_curved_shell_mesh`),
  `RoofSkin` (vault +0.38 with edge lips), `RearSkin` (posts and header
  round the door opening), `SillL/R`. `material` is the shared exterior
  material later parts reuse. The meshes carry no UVs, so no tangents.
- First GPU render of `van_exterior.gdshader`: compiles, seams and panel
  breaks read, windows stay open. Vans are very dark at IDLE (moon only).
- **DoorSpill: skin casts shadows, kept.** Raiders in `06` stay readable;
  the smoke has no raider standing at a door, so the door-raider shot is
  still owed (step 20's review). `03-idle-outside` now sees the roof, not
  the interior: mean 0.0090 → 0.0074; `06` 0.0237 → 0.0235 (p95 0.1534 →
  0.1719); `09` 0.0053 → 0.0027; `12` 0.0048 → 0.0038. Van views `v01`
  0.0169 / 0.0901 / 0.241. No new target row needed yet.

## Baseline (2026-09-25, before any change)

The shots: `01-idle-front` shows the cage bulkhead, a flat brown box for
the bench, a box with the red button, a row of dark boxes on the right;
`02-idle-back` shows the rear doors as flat panels with two small panes;
`03-idle-outside` and `12-rear-park-stop-outside` see straight into the
van from above (no roof or outer body), with the ceiling lamp visible as a
white dome.

`shot_stats` after step 2 (mean / p95 / clip%): `01` 0.0271 / 0.0896 /
0.131, `02` 0.0091 / 0.0217 / 0, `03` 0.0090 / 0.0227 / 0.237, `06`
0.0237 / 0.1534 / 0.765, `09` 0.0053 / 0.0125 / 0.042, `12` 0.0048 /
0.0225 / 0.018; van views `v01` 0.0174 / 0.0923 / 0.239, `v02` 0.0129 /
0.0359 / 0.357, `v03` 0.0145 / 0.0716 / 0.146, seeds 1..3 about 0.016 /
0.08 / 0.3..0.5 (identical vans today; the spread is noise).
