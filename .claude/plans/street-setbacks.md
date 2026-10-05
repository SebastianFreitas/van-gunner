# Plan: street-setbacks

Stage: done
Started: 2026-10-05
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/street-setbacks.state.md` while running).
Path: full
Size: at most 38 KB (20 KB + 3 KB per phase past six), each phase at most 2.5 KB
Interview: A done · 3 asked. B done (pieces approved in plan mode, 2026-10-05). C done · 1 asked (review pass one round). Ready gate: round 1 run (build 2 findings fixed from the plan's own text, design fit 2 findings asked as D17-D18 · 2 asked, art style none). Round 1 applied; round 2 run (build 3 findings, fixed from the code; no third review). Passed. missed: phase 1, the stress force keyed on `seed_value % 3` while the smoke runs only seed 0 (D20); phase 8, the gap furniture and gap weeds at the old face line (D24); phase 9, forced outside views did not change as Verification expected (D25); phase 10, the weed lean exceeding the planned 0.35 m allowance (D26) and stress tiles carrying no lamps (D27); phase 11, bridges always unrecessed and no view showing an overhead (D28); phase 12, no art-style paving line (D30) and interior-labelled views seeing the street (D31).
Questions: auto
Research: `.claude/plans/research/street-setbacks-00-intake.md` (the earlier session's `file:line` anchors).

## Brief (owner's words, verbatim)

Owner, 2026-10-05 (earlier session): "our exterior is purely on a line, the sidewalks never grow larger with buildings pushed behind, the road is always the same size. I want to push buildings back, randomly ... making the surroundings adjust ... bars over the road would float in the air if we don't update them ... include the current destruction system ... sidewalks are a lot of objects so be careful."

Owner, 2026-10-05 (this plan's start): "buildings step back from the street line by random depths and the street adjusts (the road widens for ordinary buildings, a flagstone plaza for big ones, overheads stretch to the walls, destruction follows)."

## Scope

- In: `scripts/travel/facades/` (plan, district, bodies, infill, props, overgrowth, overheads, audit, the two bridge set pieces), `scripts/travel/road_floor*.gd`, `scenes/corridor/corridor_segment.gd` and `.tscn`, `scripts/debug/debug_facade_commands.gd`, `tools/smoke.py` and `tools/smoke/` (one argument), the five `resources/facades/districts/*.tres`, the rules and glossary.
- Out (stays exactly as is): curves, slopes and new street shapes; junctions, side-street branches and `FacadeSpans` walls (recess 0); stop bays and their content; the other set pieces (their side stays on the line); raiders, the lane, the van; `corridor_facades.gd:141` (`wreck_at` stays on `FACE_X`: it samples the wreck map before the plan exists); the ruin-span loop at `corridor_segment.gd:208` (see Open items).

## Current state (explored 2026-10-05; anchors drift, grep the names)

- `facade_plan.gd`: `FACE_X` 8.8 :12, `SETBACKS` 0-0.3 forward :20, `PLAIN_DEPTH` 3.5 :24, `plan_side` :51 (side street: no plans; bay: one `mouth` plan; else `plan_length(..., with_gaps=true)`), `plan_length` :88 (`gap_rng` :94-95, joined copy :127-130), `_pick_height` :167, `face_x` :246.
- `road_floor.gd` `_build` :212: `half_x` 9.0, kerb line `road_half` 7.25, `gutter_inner` 6.97, `sidewalk_top` -0.06, `slab_bottom` -0.4 (:223-227); bed box :259-280, gutters :282-300, wreck call :327-342.
- `corridor_segment.tscn:7-31`: wall boxes 0.4 x 20 x 20 at x ±9, y 9.6 and 29.59.

## Open items

Nothing to ask the owner.
- review leftover: `corridor_segment.gd:208` skips every plan (`plan.has(&"mouth")`, and every plan carries the key, `facade_plan.gd:73,145`), so the floor gets no ruin spans today. Not fixed here (it changes today's paving); a separate task for the owner.
- review leftover: with the whole-side chance 0.12 the lots on the line are 0.88 x 0.5 = 44%, not 50%; taken as "about 5 in 10".

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- none left: D1-D11 (owner and Recommended, plan mode 2026-10-05) and D13-D15 (from the code) are folded below. D16 (owner, 2026-10-05: "Right", phase 1 also forces a recess in the stress run and adds `--pre` to `tools/smoke.py`, staying one phase) is folded into phase 1. D17 (owner, 2026-10-05: "Only from 3 m deep") is folded into piece 3 and phases 1, 6, 12; D18 (owner, 2026-10-05: "Measure and self-fix") into phases 6 and 12. D19 (from the code, gate round 2: `facade district` only sets a meta new tiles read, `debug_facade_commands.gd:107`, `travel_world.gd:171`, and no district has `plaza` before phase 12) adds the force `facade plaza <on|off>` to phase 1 and splits D18's two fixes by the case each can help.
- D20 (auto, phase 1): the stress run's recess force keys on the build's flat case index % 3, not `seed_value % 3`: the smoke runs `facade stress 1`, whose only seed is 0, so no build would be forced. 5 shards and 3 are coprime, so every shard sees all three forces.
- D21 (owner, 2026-10-05, run blocker): headless sessions could start no subagent (their Agent tool has no `run_in_background` field); `.claude/hooks/agent-guard.py` now passes a call with no such key when `AUTOPLAN=1`. missed: the runner was never tried with the guard.
- D22 (auto, phase 6): Floor timing uniform 35.94 ms vs today's 18.90 (limit 28.35); D18's fix (drop the soil grid) was not built, because recess 6 with plaza off, where no plaza code runs, already measures 32.12 ms: the overage is phases 2-5's per-run walk, and the plaza adds 3.8 ms. Over budget, kept, soil grid kept.
- D23 (auto, phase 7): the collision's pier boxes come from the ground runs (low end when `runs[0].z > 0`, high end when `runs[-1].z > 0`), not from the built `Pier*` meshes, which may not exist yet when `_push_sidewalk_wreck` runs; same condition as `facade_pier.gd` minus its keep-out gate.
- D24 (auto, phase 8): the gap furniture (utility box 8.4, pole 8.0) and the gap weed clumps (`facade_overgrowth.gd` `GrowthGap`) also shift by g, or they stand in the widened road; the audit (`facade_audit_infill.gd`) holds `InfillUtility*` / `InfillPole*` to `7.25 + g` (the walk's inner edge), every other `Infill*` mesh to `8.8 + g - 0.35`. Phase 10 must not shift `GrowthGap` again.
- D25 (auto, phase 9): forced `recess 3` shots changed only the van-side views (v02 0.072, v09 0.109), not the `*-outside` views the Verification expected (03 0.016, under tolerance): the moved furniture and rubble barely reach those frames. The audit is the proof (302 forced lots over 5 stress shards, 0 violations); no picture read.
- D26 (auto, phase 10): gap weed blades lean up to 0.85 m in front of the face and are merged into one `GrowthGap<i>` mesh per gap (no clump roots), so the weed audit is AABB min |x| >= 8.8 + g - 0.9, not - 0.35; it catches only an error larger than one 0.25 m recess step.
- D27 (auto, phase 10): stress tiles build no lamp lights, so the lamp audit (0 to 1.0 m in front of the lot face) checked none in smoke; placement code reads `face_x` for every lit case and was left unchanged. Phase 12's turned-on districts exercise it.
- D28 (auto, phase 11): the bridges' Span roots zero recess (D8), so every stress bridge had r 0 and the bridge code path only proves r-0 identity; the bridge audit expects 9.4 + recess (0.4 thick portals centred on 9.2 + recess), rib beams 9.0 + recess, and catwalks look up recess over z -1..1 (the builder's), not their rail-widened AABB. No forced view showed an overhead; phase 11 rests on the audit (21 `Overhead*` meshes checked across the stress shards).
- D29 (auto, phase 12): Floor timing uniform 35.92 ms (limit 28.35), the same as phase 6's 35.94; D22 already showed the soil-grid fix cannot reach the limit (recess 6 alone 32.12), so over budget, kept. Mixed 24.62 and 27.09 on two runs, under.
- D30 (auto, phase 12): art-style.md has no street paving line; the plaza flagstone line went to street-paving.md, and the setback entry to facades.md (facade rules moved off travel-and-stops.md).
- D31 (auto, phase 12): unforced shots changed 40 of 117 views, including van views (c, g, v series) that see the street through windows and openings; the recess rolls move what they see, not the van. Unforced recess share 0.657 (302 of 460), inside 0.40-0.70.

## Initial idea (the pieces, approved)

1. **Recess.** About 5 in 10 lots stay on the line, 4 in 10 step back 1-3 m, 1 in 10 step back 4-6 m. Terraced lots move together; now and then a whole tile side moves together. Forward stays today's 0-0.3 m.
2. **Road widens** in front of an ordinary stepped-back building: kerb, gutter and the 1.75 m sidewalk move back with the wall, asphalt fills.
3. **Plaza** in front of a big one (a step of 3 m or more in a commercial or civic district, or a tall roll anywhere at any depth; D17); a shallower step in those districts widens the road as in piece 2. The kerb and today's sidewalk stay, 1 m worn flagstones fill from the back of the sidewalk to the wall, broken by the same wreck map.
4. **Tile ends.** A widened road returns to the old kerb line 0.75 m before a tile end (a kerb build-out, 1.5 m where both tiles step back), with a party-wall pier on it closing the view behind the neighbour.
5. **Followers.** Gap fillers, street furniture, rubble, weeds, lamps, utility boxes, bollards and drains sit on the real wall or kerb line.
6. **Overheads** (pipe bridge, catwalk, truss, ribs, the two bridge set pieces) stretch each end to the real wall at their z.
7. **Walkable.** Wall and ground collision follow, so a halted player can walk the new ground and not into a building.

## Walk-through

- Pieces 1-7 · approved in plan mode, 2026-10-05 · D1-D11

## Constraints (every phase)

- **Off means identical.** With every district chance 0 and no force, the game is today's: an unrecessed side is one ground run and takes today's code path and rng seeds, and `tools/shots.py compare` prints `SHOTS SAME`. District exports default 0 until phase 12.
- **Words.** `r` = a lot's `plan[&"recess"]` (0 to 6 m, D8); `plaza` = `plan[&"plaza"]`. A side's ground is `FacadePlan.ground_runs(plans)`: `Array[Vector4]` of `(z0, z1, r, kind)` covering z -10..10 in order; kind 0 walk (kerb moves back by r), 1 plaza (kerb stays), 2 build-out (kerb stays, walk is 1.75 + r deep). `kerb_r` = r for kind 0, else 0.
- **Lines (abs x, tile-local, from `road_floor.gd:223-227`, `facade_plan.gd:12`):** face 8.8 - setback + r; kerb 7.25 + kerb_r; gutter 6.97 + kerb_r to the kerb; walk kerb to kerb + 1.75; plaza 9.0 to 9.0 + r; asphalt fill 6.97 to 6.97 + r; walk top -0.06, road top -0.2, bed top -0.18.
- The recess roll has its own rng and never draws from the plan rng. New rng streams are salted; an existing stream keeps its seed and draw order.
- Invariant 14: recess is 0 on a bay (mouth) side, side-street side and every `FacadeSpans` wall (D8); every new placement passes `FacadeKeepOut.allows`; smoke still prints `bay mouth clear:`.
- No node per stone: new paving and kerb go into the side's merged meshes (one more per side for the plaza).
- No `--bless`: the fingerprint holds no facade data.
- Art (`.claude/rules/art-style.md:239-241`, copy into visible specs): tiles 0.5 m albedo 0.33, setts 0.25 m albedo 0.25, kerb blocks 1 m, joints 3 cm, chamfers 1.2 cm, glare fades 18-45 m; hand-built meshes wind clockwise from outside; always night, no new light.
- **Stress (phases 1, 12).** `_stress_build` forces 3 m when `seed_value % 3 == 1`, 6 m when `== 2`, then restores -1 and `forced_plaza` false. Stress prints two counts of lots with r > 0: `recess lots forced: <n> of <m>` (those builds) and `recess lots unforced: <n> of <m>` (builds with `seed_value % 3 == 0`, which no force touches).
- **Floor timing (D18; phases 6, 12).** `py -3 tools/probe.py --cmd "perf full" --cmd "perf reset" --cmd "facade reseed 7" --cmd "perf spans"`, and read the `road_floor` row's avg ms (the span at `road_floor.gd:75-77`, no new one needed: a console rebuild is not sliced, so the wreck sides run inside it; `road_wreck` :84-86 times only sliced sides). That is today's while the plaza code does not exist. Two cases, each at most 1.5 x today's, the forces going before `perf reset` (`facade reseed 7` after it is the measured rebuild): **uniform** adds `--cmd "facade recess 6"` and `--cmd "facade plaza on"` (every lot a 6 m plaza); **mixed** adds only `--cmd "facade plaza on"` (phase 12 only: it needs the chances on). Uniform over (phase 6, or 12 if 6 did not): drop the soil grid under the flagstones and measure again. Mixed over: the walk loop builds neighbouring runs of equal `_inner` and `_width` as one (plaza runs of different r side by side; it cannot help uniform, already one run), and measure again. Each is a `D<n> (auto)`. Still over after the fix that applies: write both numbers to Carry forward as `D<n> (auto): over budget, kept` and name it in the report; never a question, never a block. Row count 0: → phase decides: find the console line that rebuilds the live floors and use it in both runs.
- Every phase: `py -3 tools/check.py`, then `py -3 tools/smoke.py`. Forcing: console `facade recess <m|off>` and `facade plaza <on|off>` (phase 1; each rebuilds the live tiles at once); shots with a force use the command in Carry forward, one `--pre` per line. Scripts stay under 400 lines: a helper `RefCounted` beside the file when one would pass it.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Plan data | code | - | Brief | done e053a79 |
| 2 | Bodies and tile-end pier | code | 1 | Brief | done 71e8655 |
| 3 | Runs into the floor | code | 1 | Brief | done 67f2230 |
| 4 | Wreck per run | code | 3 | Brief | done fe5cf5a |
| 5 | Kerb returns and details | code | 4 | Brief | done 5237b66 |
| 6 | Plaza | code | 4 | Brief | done 4c921c4 |
| 7 | Wall collision | code | 1, 2 | Brief | done 4812681 |
| 8 | Gap fillers | code | 1 | Brief | done 194e1ff |
| 9 | Ground followers | code | 3 | Brief | done 022c8e0 |
| 10 | Weeds and lamps | code | 8 | Brief | done 6c55660 |
| 11 | Overheads and bridges | code | 1 | Brief | done 5b8c6da |
| 12 | Turn on and docs | code | 1-11 | Brief | done 7cc6890 |

Needs: earlier phases whose output it builds on. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · Plan data
Pieces 1, 4. Reads: `facade_plan.gd` :88-175, `debug_facade_commands.gd` :131-153, :308-337.
Spec A (`facade_district.gd`, `facade_plan.gd`, `corridor_facades.gd`):
- `FacadeDistrict` exports, default 0 / false (D11): `recess_mild_chance`, `recess_deep_chance`, `recess_mild_range := Vector2(1, 3)`, `recess_deep_range := Vector2(4, 6)`, `recess_side_chance`, `plaza`.
- `plan_length`, only when `with_gaps`: `recess_rng.seed = hash([rng.state, &"recess"])` (as `gap_rng` :94-95). Side draw first: under `recess_side_chance` all lots get one whole-metre depth (mild or deep by the chances' ratio). Else per lot draws u, t: u < deep chance: deep range; u < deep + mild: mild range; else 0. `r = snappedf(lerp(lo, hi, t), 0.25)`. `FacadePlan.forced_recess := -1.0`: when >= 0 it is every such lot's r. `plaza` = height >= `tall_min` snapped as :173-174 (tenement 28 gives 27.6; D4), or `district.plaza` and r >= 3 (D17), or `forced_plaza` and r > 0; a plaza lot rounds r to whole metres (D10). Joined lots copy `recess` and `plaza` from `prev` (:127-130).
- `face_x` (:246) adds `recess`; callers follow.
- `ground_runs(plans)`: no plans, a mouth plan or all r 0: `[Vector4(-10, 10, 0, 0)]`. Else one run per lot, kind 1 when plaza and r > 0, else 0; neighbours of equal r and kind merge; a gap (tile end too) joins the deeper lot; a first or last kind-0 run with r > 0 gives its outer 0.75 m to a kind-2 run of the same r (D6, D13).
- `rebuild_side` (:149-156): a set piece that claims a lot (`can_apply` true) zeroes every plan's recess and plaza before bodies (D7); `pedestrian_bridge`, `pipe_bridge`, `power_outage` keep it.
Spec B (`debug_facade_commands.gd`, `facade_audit.gd`, `tools/smoke.py` + its driver): `facade recess <m|off>` sets `forced_recess`, `facade plaza <on|off>` sets `FacadePlan.forced_plaza := false`; both rebuild as `facade reseed` does; `_stress_build` as Constraints (Stress); `tile_recess_violations(tile, counts)` beside :328: runs cover -10..10 without gap or overlap, a bay side is one zero run, r in 0..6 on the 0.25 grid, plaza r whole, joined lots equal. → phase decides: if `tools/smoke.py` cannot run console lines before the first street, add repeatable `--pre "<line>"` (as `tools/anim_series.py:86`).
Verification: check, smoke: `recess lots forced:` above 0 (unforced: 0 until phase 12), 0 violations. Shots against a before captured first: `SHOTS SAME`; with `--pre "facade recess 3"`: `*-outside` views differ.
Reviewed: Right (D16).

### 2 · Bodies and tile-end pier
Pieces 1, 4. Reads to design: `facade_body.gd` :14-30 and :149-175, `facade_ruin_body.gd` :40-50 and :189-205.
First step, before the specs: grep `scripts/stops/` and `resources/side_stops/` for any stop content placed past |z| 10 of its bay tile at |x| 9 to 18.8 (the warehouse is 12 m; the vestibule is |x| 9-14.6, |z| < 4.5). None: go on. Found: raise a phase question, Recommended "the stop spawner zeroes recess on the two tiles beside a bay before they build".
Deliverable, spec A (`facade_body.gd` `_add_ends` :151-162 and the same code at `facade_ruin_body.gd:189-200`): a deep body at a tile edge draws face to 9.6, then 9.6 to back 5 cm inside; once the face passes 9.6 the first piece is a fin in front of the face. `x_wall = signf(x_back) * maxf(9.6, absf(x_face))`, and skip the first return when its width is under 1 mm. With r 0 the face is at most 8.8, so `x_wall` is 9.6 as today.
Spec B (new `facade_pier.gd`, called from `rebuild_side` after the bodies): for the first and the last lot of a plain side with r > 0, one box 0.3 thick at |z| 9.65 to 9.95 (5 cm inside the edge, like the body), x 8.8 to 12.8 + r (`PARTY_X` 12.8, `facade_infill.gd:17`; length 4 + r, 10 m at most), y -0.4 to -0.4 + lot height, mesh `Pier<index>` in the party wall's material (`facade_infill.gd:163` `_wall_quad`), gated by `keep_out`. Two stepped-back lots meeting across a tile end get both piers: accepted (D9).
Audit, added to `tile_recess_violations`: every `Body*` and ruin-body mesh of a lot has AABB min |x| >= 8.8 - setback + r - 0.05; a recessed end lot has exactly one `Pier`.
Verification: check, smoke (stress forces 3 and 6 m): 0 violations. Shots with `--pre "facade recess 6"`: `*-outside` views differ; without: `SHOTS SAME`. Read one `*-outside` picture once for see-through or inside-out faces beside a stepped-back wall.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 3 · Runs into the floor
Pieces 2, 4, 7. Reads to design: `corridor_segment.gd` :185-219, `road_floor.gd` :100-126 and :212-342.
Deliverable, spec A (`corridor_segment.gd` `_push_sidewalk_wreck` :201-218): compute `FacadePlan.ground_runs(_facades.plans(side_idx))` per side and pass both in the same `set_sidewalk_wreck` call (a second setter would rebuild twice). The ruin-span loop at :208 stays byte for byte. A bay opened at runtime re-pushes through `_sync_road_openings`, and its mouth plan gives one zero run.
Spec B (`road_floor.gd`): `set_sidewalk_wreck(tile_seed, left, right, runs_left := [], runs_right := [])` stores `ground_runs` and includes it in the identical-data skip (:111). `run_at(side_idx, z) -> Vector4` for later phases. Empty or one zero run: today's code, untouched. Otherwise, per run of length len (clipped to `_sidewalk_span_z()`), replacing that side's single bed and gutter boxes:
- kind 0: bed 1.75 x 0.22 x len at x 8.125 + r, y -0.29 (collision only, as today: thickness 0.34 - `PIT_DEPTH` 0.12); gutter 0.28 x 0.16 x len at x 7.11 + r, y -0.32; fill `RoadFill` r x 0.2 x len at x 6.97 + r/2, y -0.3, the road material, with collision, in whatever `set_carriageway_visible` toggles.
- kind 1 (always r > 0: an r 0 lot is kind 0, phase 1): bed and gutter as today (r 0), plus a plaza bed r x 0.22 x len at x 9.0 + r/2, y -0.29, collision only.
- kind 2: bed (1.75 + r) x 0.22 x len at x 7.25 + (1.75 + r)/2; gutter as today.
The gutter is never covered by fill: fill ends at 6.97 + r where the moved gutter starts.
Check: forced 3 m, the fill's AABB max |x| = 9.97. The paving meshes still sit on the old line until phase 4: expected.
Verification: check, smoke. Shots with `--pre "facade recess 3"`: `*-outside` views differ from phase 2's; without: `SHOTS SAME`. No picture read (phase 4 finishes the look).
Reviewed: approved by the owner in plan mode, 2026-10-05

### 4 · Wreck per run
Pieces 2, 4. Reads to design: `road_floor_wreck.gd` :24-125, `road_floor_wreck_ground.gd` (grid :30-43, ramp :57).
Deliverable (`road_floor_wreck.gd` `build` :53-100, `road_floor_wreck_ground.gd` only if it holds a width or x literal): `build` loops the side's `road.ground_runs`. Per run it sets `_inner` = 7.25 + kerb_r, `_width` = 1.75 (kinds 0, 1) or 1.75 + r (kind 2), `_z_start` / `_z_end` = the run clipped to the walk span, then runs `_layout`, `_build_tiles`, `_build_setts`, the ground and the kerb into the same five `_PavingMesh` objects, and commits the five merged meshes once after the loop (:82-91). `_layout` already takes any width (two 0.5 m tile columns by the kerb, 0.25 m setts for the rest: 27 sett rows at 1.75 + 6).
Seeds: the first run keeps `road._seed_value(497 + side_idx * 1000)` and `297 + ...` (:76, :79); run i > 0 adds `i * 7919` to the salt. Any other per-build rng in the helpers is salted the same way.
`walk_gone_<side>` meta (:92-100): sum the samples of every run, each sampled at its own `_inner + _width * 0.5`.
The soil ramp and skirt read `_inner`, so they follow; a kind-2 run ramps over its whole 1.75 + r (the 0.8-2.5 m clamp holds).
Check: smoke `walk destroyed share` inside [0.12, 0.50] in the game run; with one zero run the five meshes are vertex-identical to today (shots `SHOTS SAME`). Fallback when the share leaves the range under force only: the sampling line is wrong (it must follow `_inner`), fix that, never the range.
Verification: check, smoke. Shots with `--pre "facade recess 3"`: `*-outside` views differ from phase 3's; without: `SHOTS SAME`. Read one forced `*-outside` picture once: the walk sits against the stepped-back wall, asphalt in front, no hole at the tile-end build-out.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 5 · Kerb returns and details
Pieces 2, 4, 5. Reads to design: `road_floor_wreck_curb.gd` (120 lines), `road_floor_details.gd` :16-65 and :117-180.
Deliverable, spec A (`road_floor_wreck_curb.gd`): at every boundary between two runs whose kerb x differs (7.25 + kerb_r each; this covers a plaza beside a widening, at any depth), a kerb return running in x from the smaller to the larger kerb x, lying inside the shallower run (z from the boundary to 0.12 into it, `curb_face_depth`), with the z-kerb's own section, `CURB_LEN` 1.0 blocks, `JOINT` 0.03, 4 cm burial, a last block under `MIN_PIECE` 0.12 merged into the one before, and the same zone states (missing, knocked, none where GONE), into the same `WalkCurb` mesh. Rng: its own stream, `road._seed_value(397 + side_idx * 1000 + boundary * 7919)`. The floor stores meta `kerb_returns_<side>` (count).
Spec B (`road_floor_details.gd`): drains take x `gutter_inner + kerb_r` of `road.run_at(side, z)`; utility boxes (:145) `half_x - 0.35 + r` (the wall line, all kinds); bollards (:172) `walk_inner + 0.28 + kerb_r`. No draw is added, removed or reordered, so a zero run is today's dressing.
Audit, in `tile_recess_violations`: `kerb_returns_<side>` equals the number of run boundaries with a kerb jump over 1 cm; every `UtilityBox_*` and `Bollard_*` AABB lies within 0.6 m of its line.
Verification: check, smoke: 0 violations. Shots with `--pre "facade recess 3"`: `*-outside` views differ from phase 4's; without: `SHOTS SAME`. No picture read unless a number disagrees.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 6 · Plaza
Piece 3. Reads to design: `road_floor_wreck.gd` (`_build_tiles`, `_emit` :275), `road_floor_wreck_ground.gd` `add_grid`.
First step, before the spec (D18): run the Floor timing command (Constraints) with no force and write today's `road_floor` avg ms to Carry forward.
Deliverable (`road_floor_wreck.gd`, or a helper `road_floor_wreck_plaza.gd` beside it if the file would pass 400 lines; `road_floor_paving_mesh.gd` only if `_emit` needs a size it lacks): for each kind-1 run, flagstones over x 9.0 to 9.0 + r: r columns of 1.0 m (r is whole metres, so no sliver, D10), rows of 1.0 m in z from the run start, a last row under 0.5 m merged into the one before; joint 3 cm, chamfer 1.2 cm; top level with the walk (-0.06). They go into a sixth merged mesh `WalkFlags<Left|Right>` with `paving_mat(PAVING_TILE)` (D10), committed with the other five. At most 20 x 6 = 120 stones a side.
State per stone from the same wreck zones through the tile tables `MISSING`, `TILT`, `SINK` (:16-20); tilt angles are `TILT_DEG` halved, [1.5, 3, 5, 7]: a 1 m stone at 7 degrees lifts its edge 6.1 cm, a 0.5 m tile at 14 lifts 6.0 cm. FRAGMENT stones use `add_prism` as tiles do.
Under them a flat soil grid (`add_grid`, the walk's cell size) at top - `DIRT_DROP` 0.02, no ramp and no skirt, into the existing soil mesh. Rng: `road._seed_value(697 + side_idx * 1000 + i * 7919)`.
It runs inside `RoadFloorWreck.build`, so inside the side's existing step of the sliced build (`corridor_segment.gd:109`: still six floor steps). The paving mesh writes no UVs (D15: no `uv` in `road_floor_paving_mesh.gd`), so 1 m stones do not stretch the grain.
The flagstones run 0.2 to 0.5 m under the building front; the plaza bed from phase 3 carries the player.
Check (D18), after the build: Floor timing's uniform case at most 1.5 x today's; over, as it says.
Verification: check, smoke. Shots with `--pre "facade recess 4"` and `--pre "facade plaza on"` (no district has `plaza` yet): `*-outside` views differ from phase 5's same command; without: `SHOTS SAME`. Read one of those pictures once: flagstones reach the wall, broken where the walk is broken, no bright grid.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 7 · Wall collision
Piece 7. Reads to design: `corridor_segment.gd` :49-64 and :158-196, `corridor_segment.tscn` :7-31.
First step, before the specs: grep `WallCollision` and `_wall_collision` in `scripts/`, `scenes/` and `tools/`. A reader of `.disabled` meaning "open" moves to the new flag; a reader of the box position: raise a phase question, Recommended "leave it on the tscn box". Grep `scripts/enemies/` and `scripts/combat/` for a literal wall x (9.0, 8.8): leave any found alone (raiders stay inside the lane, |x| < 7.6; bullets hit layer 1 bodies, which follow).
Deliverable (`corridor_segment.gd`; the `.tscn` nodes stay): `_side_open: Array[bool]`, written in `_set_side_street` (:166) and read by `end_build` (:57-58) and `_sync_road_openings` (:190-191) in place of "disabled wall box means open". The two tscn boxes of a side are enabled only when it is not open and its runs are one zero run (today). Otherwise they are disabled and a `StaticBody3D` `RunWalls<Left|Right>` (layer 1) is rebuilt in `_push_sidewalk_wreck` with:
- per run: a box 0.4 x 40 x len at x 9.0 + r, y 19.6 (the two tscn boxes cover y -0.4 to 39.6);
- per boundary where r differs: a box |r_a - r_b| x 40 x 0.4 at x 9.0 + (r_a + r_b)/2, its centre z 0.2 m into the shallower run (it fills the boundary to 0.4 m inside that run);
- per pier (phase 2): a box (r + 0.4) x 40 x 0.3 at x 8.8 + (r + 0.4)/2, |z| 9.8.
A kind-2 run uses its r (the wall is the building's). `build_flank_collision` is untouched. An open side has no `RunWalls`.
Audit, in `tile_recess_violations`: box count = runs + boundaries with differing r + piers; an open side has none.
Verification: check, smoke: 0 violations and `bay mouth clear:` printed. Nothing visible: no shots beyond `SHOTS SAME` without force.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 8 · Gap fillers
Piece 5. Reads to design: `facade_infill.gd` :120-185, `facade_infill_extra.gd` :25-95.
Deliverable: one gap recess `g` per gap = the larger r of its in-tile neighbour lots (a tile-end gap has one), from a new `FacadePlan.gap_recess(plans, z)`.
Spec A (`facade_infill.gd`): the yard box (:138) centre x becomes `FACE_X + g + YARD_DEPTH * 0.5` (8.8 + g + 1.75); the party wall (:163) stands at `PARTY_X + g` (12.8 + g); the face-line fillers (:176) use `FACE_X + g`.
Spec B (`facade_infill_wall.gd` :19, :87; `facade_infill_extra.gd` :33, :92): `xf = FACE_X + g`; the hoarding's pseudo plan (:76, `setback: 0.0`) gets `&"recess": g` so what it hands to `face_x` users follows.
With g 0 every value is today's. No rng changes.
Audit, in `tile_recess_violations`: every `Infill*` mesh of a gap has AABB min |x| >= 8.8 + g - 0.35 (0.3 forward setback + 5 cm).
Verification: check, smoke: 0 violations. Shots with `--pre "facade recess 3"`: `*-outside` views differ from the phase before; without: `SHOTS SAME`. Read one forced `*-outside` picture once: no filler standing in the road in front of a stepped-back gap, no see-through behind one.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 9 · Ground followers
Piece 5. Reads to design: `facade_props_ground.gd` :14-16 and :200-232, `facade_ruin_debris.gd` :85-110.
Deliverable, one spec (both files):
- Furniture (`facade_props_ground.gd:229`): x = `STRIP_X` 8.25 + the plan's r, both kinds, so it stands 0.55 m in front of the wall line as today (on the moved walk, or on the flagstones). Depth <= 1.0 keeps |x| >= 7.75, outside the lane's 7.6.
- Rubble (`facade_ruin_debris.gd:101`): `lo = 7.75 + kerb_r + half the piece` (kerb_r = r for an ordinary lot, 0 for a plaza lot, so rubble never lands on the asphalt fill but may spread over a plaza); `reach` (:91) already follows `face_x`.
No draw is added or reordered; with r 0 both lines are today's.
Audit, in `tile_recess_violations`: furniture and rubble meshes of a lot (the phase reads their node names) have AABB min |x| >= 7.75 + kerb_r - 0.05 for rubble, >= 7.75 + r - 0.05 for furniture.
Verification: check, smoke: 0 violations. Shots with `--pre "facade recess 3"`: `*-outside` views differ from the phase before; without: `SHOTS SAME`. No picture read unless a number disagrees.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 10 · Weeds and lamps
Piece 5. Reads to design: `facade_overgrowth.gd` :40-75, `facade_fixtures.gd` :52-78.
Deliverable, one spec:
- Gap weeds (`facade_overgrowth.gd:69`): `_clump(blades, side_sign, FACE_X + g, ...)` with `g = FacadePlan.gap_recess` (phase 8). Lot weeds (:49) already use `face_x`.
- Lamps (`facade_fixtures.gd`): no code change expected. A lamp inside a lot (:58) or snapped to the nearest lot from a gap (:76) already takes `face_x`; the `FACE_X` default at :54 survives only on a side with no plans, which gets no lamp. The phase confirms by the audit below; if it fails, the fix is to route that case through `face_x` of the nearest lot.
Audit, in `tile_recess_violations`: every light in group `facade_lights` under a side root lies 0 to 1.0 m in front of the face of the lot at its z (the pool is about 3.9 m across, `travel-and-stops.md` Lights); gap weed meshes have AABB min |x| >= 8.8 + g - 0.35.
Verification: check, smoke: 0 violations. Shots with `--pre "facade recess 3"`: `*-outside` views may differ from the phase before (weeds are small); without: `SHOTS SAME`. No picture read.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 11 · Overheads and bridges
Piece 6. Reads to design: `facade_overheads.gd` (about 150 lines), `set_pieces/pedestrian_bridge.gd` :15-45.
Deliverable: `FacadePlan.recess_at(plans, z0, z1) -> float`: the largest r of the lots touching z0..z1; inside a gap, the nearer lot's; no plans, 0. Largest, so an end is buried in the shallower building and never stops short of the deeper wall. Each end keeps today's burial: end x = 9.2 + recess (today 9.2 = 18.4 / 2, 0.4 behind the face line), so with r 0 nothing moves.
Spec A (`facade_overheads.gd`; `build` :18 already receives both plan arrays, unused): per piece, L = 9.2 + recess left, R = 9.2 + recess right over the piece's own z extent; length L + R, centre x (R - L)/2, in place of `_LENGTH` 18.4 (:42, :46, :66, :75, :96). Catwalk posts (:78-79) step from -L + 1 to R. Truss (:104): panels = `roundi((L + R) / 2.3)` (8 at 18.4). Ribs: posts at -(8.3 + recess left) and 8.3 + recess right (:131, :134), beam 18.0 becomes (9.0 + left) + (9.0 + right), centred the same way (:140). Every box still passes `keep_out`.
Spec B (`set_pieces/pedestrian_bridge.gd` :24-43, `pipe_bridge.gd` :29, reading `ctx[&"plans_left"]` / `ctx[&"plans_right"]`, `corridor_facades.gd:245-262`): the 18.4 shells, wall and pipes take L + R and the centre shift; the portals at ±9.2 move to -(9.2 + left) and 9.2 + right.
Audit, in `tile_recess_violations`: every `Overhead*` mesh and both bridge pieces: AABB max |x| on each side within 5 cm of 9.2 + `recess_at` over its z extent (rib posts: 8.3 + recess ± 0.3).
Verification: check, smoke (stress forces 3 and 6 m on rare and overhead tiles): 0 violations. Shots without force: `SHOTS SAME`. With `--pre "facade recess 6"`: read one `*-outside` picture that shows an overhead, once, for a floating end; if no view shows one, say so and rest on the audit.
Reviewed: approved by the owner in plan mode, 2026-10-05

### 12 · Turn on and docs
Pieces 1-7. Reads to design: one district `.tres`, `docs/glossary.md`.
Deliverable, spec A (the five `resources/facades/districts/*.tres`): `recess_mild_chance = 0.4`, `recess_deep_chance = 0.1`, `recess_side_chance = 0.12` (D1, D11; ranges stay 1-3 and 4-6); `plaza = true` in `commercial.tres` and `civic.tres` (D4; a lot there is a plaza only from r 3 m, D17).
Docs (the session writes these): `.claude/rules/travel-and-stops.md` gets one entry (recess, runs and kinds, the Lines from Constraints, the pier, `RunWalls`, the audit, the force command); `art-style.md` street paving line gains "plaza flagstones 1 m, tilt half the tile's"; `docs/glossary.md` gains "bars over the road / overheads" = `facade_overheads.gd` + `pedestrian_bridge.gd`, `pipe_bridge.gd`, "plaza", "build-out"; then `py -3 tools/gen_context.py`.
Check: stress `recess lots unforced: n of m` (phase 1: the builds no force touches; plain sides without a lot-claiming set piece): expected share 1 - 0.88 x 0.5 = 0.56; pass 0.40 to 0.70. Outside it: the roll is wrong, fix the roll, never the chances. Smoke `walk destroyed share` stays in [0.12, 0.50]; if not, the per-run sampling of phase 4 is wrong.
Timing (D18): Floor timing's uniform and mixed cases (Constraints), each at most 1.5 x today's in Carry forward; over, the fix it names for that case, then as it says.
Verification: check, smoke (0 violations, `bay mouth clear:`), then shots with no `--pre` against the before set: every `*-outside` view that shows street ground or walls changes, and this is the first phase where an unforced run may differ; views of the van interior with doors shut stay `same`. Read two `*-outside` pictures once each: a widened road with its build-out and pier, and a plaza. No `--bless`.
Try, in the report: launch, start a run with the base class, halt the van (C, then STOP), step out of the rear doors and walk onto a widened road and a plaza; `H` then `facade recess 6` shows the deepest case at once, then `facade plaza on` turns every stepped-back lot into a plaza (`off` for each to return). `facade district commercial` changes only streets spawned after it.
Reviewed: approved by the owner in plan mode, 2026-10-05

## Carry forward

- Before set (phase 1, captured on c831c48 before any code change): `street-setbacks-before`, in this worktree's `.godot/shots/street-setbacks-before/` (117 views). Compare: `py -3 tools/shots.py compare street-setbacks-before <set or dir>`.
- Shots with a force (once spec 1-2 adds `--pre`): `py -3 tools/smoke.py --shots <scratchpad>/shots-recess3 --pre "facade recess 3"`, one `--pre` per console line, then `py -3 tools/shots.py compare street-setbacks-before <scratchpad>/shots-recess3`. Unforced: `py -3 tools/shots.py capture <name>`.
- Phase 2 forced set (on 71e8655): `.godot/shots/street-setbacks-p2-recess3/` (117 views, `--pre "facade recess 3"`). Phase 3 compares its forced shots against it: `py -3 tools/shots.py compare street-setbacks-p2-recess3 <dir>`.
- Floor timing today (phase 6, on 8a19ecc before the plaza code): `road_floor` avg 18.90 ms (limit 1.5 x = 28.35). Phase 6 after the build: uniform 35.94 ms, recess 6 alone 32.12 ms. D22 (auto): over budget, kept (the recess walk, not the plaza, is the cost; phase 12's mixed case compares against 18.90 too).
- Phase 6 shot sets: `%TEMP%/sb-p6/plain` (unforced, SHOTS SAME vs `%TEMP%/sb-p4/plain`) and `%TEMP%/sb-p6/plaza` (`--pre "facade recess 4" --pre "facade plaza on"`, 35 of 117 changed vs `sb-p4/recess3`).
