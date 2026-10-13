# rear-right-door-beam

Stage: done
Started: 2026-10-13
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: full   <- or light: one area, no new user-facing design (interview.md "Light path")
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: C done, ready gate passed (2 build rounds, design fit, art style) · 13 asked · 2 blocker answers (D18, D19) · missed: the plan built a new crude beam instead of copying the bottom box beam the owner meant (D18)
Questions: auto (from memory: owner takes Recommended; plans never stop for questions)

## Brief (owner's words, verbatim)

lets do our next update on the rear right door,
the first image i put a cirlce around the area we will be working on
as you see in the 2nd image i basically want to add a beam shapped like that, straight forming the new corner of the doorand the tip is bent , this will be the new limit, diving beam/yellow part, we should add some elemtns some horizontal short pars screwed in as if holding the yellow part
the goal is to have then some addons on top of the beam (form the inside) so that the litle metal things that form the locking mehcanism of the door are here, all redneck
make a plan out of this

(Owner's images, 2026-10-13: image 1 circles the right rear door's inner edge on the hinge-away side, the vertical strip between the rusty left leaf and the yellow right leaf, top to floor; image 2 draws a straight vertical beam along that edge whose top tip bends inward at an angle. Paths: see Current state.)

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- Owner-approved (D11): from the cabin a viewer can say (1) a separate steel beam runs straight up the right rear door's inner edge and bends along its top corner cut, and the yellow sheet stops at it; (2) short horizontal straps with visible screws cross from the beam onto the yellow sheet as if holding it, none over the lower dark panel; (3) a scrap lock rod sits on the beam's cabin face and read as the door's lock, all redneck (welded, bolted, mismatched).
- Judged on: look-judge on the close view `g48-gap-rear-in-donor-latch` (D19; `g02-gap-rear-in-whole` is context only); `py -3 tools/smoke.py` audit clean, `gap_check.py --strict` unchanged.

## Scope

- In: `rear_door_donor_beam.gd` gains a shared run builder and the upright edge copy (D18; the bottom beam's own output stays identical); two new helpers, `scripts/van/look/rear_door_donor_edge.gd` (straps; calls the edge copy) and `rear_door_donor_lock.gd` (rod, guides, keepers, grip), called last from `rear_door_donor_dressing.gd` `build()`; one appended view in `tools/smoke/smoke_shots_closeups.gd`; the latch and diagonal runs of `rear_door_donor_welds.gd` CutStrip (archived, phase 1) and `_latch` in `rear_door_donor_hinges.gd` (archived, phase 4); the donor `Handle` node's x and z (set by the lock helper after `rear_door_portal.gd` `_layout` sets x 2.59, not in the scene file).
- Out (stays exactly as is): the stock (x>0) leaf, its hardware and Handle, the yellow skin and pressed bays (`rear_door_profile.gd`, `rear_door_skin.gd`) except the donor seam-side crest's yellow (D15) and, only if it collides, the donor molle panel's width (D18), the astragal, the street face, the bottom box beam's look and place, the hinges and hydraulic ram, the door swing (`rear_doors.gd`), the portal, `van_shell.tscn`.

## Current state (explored 2026-10-13; anchors drift, grep the names)

- Owner images (seen once, no need to reopen): `C:/Users/Traff/AppData/Local/Temp/claude/C--Users-Traff-Documents-van-gunner--claude-worktrees-right-door-rear-window-2cdf75/e46293b2-be3a-4423-8a02-e00fdcfdbf3c/images/1.webp` and `.../2.png`.
- The owner's "right door" is node `RearWall/LeftHinge` (x<0, donor leaf, yellow), hinge at world (-2.7, 1.55, 6.59). Hinge-local +x runs from the hinge to the meeting edge, z negative toward the cabin; world y = local y + 1.55. Leaf rect x 0..2.688, y -1.53..2.05; cabin crest z -0.17 (`rear_door_leaf_build.gd` CABIN_Z).
- Meeting edge straight at x 2.688 up to y 1.80, then a 45-degree cut to (2.438, 2.05) (`rear_door_profile.gd` DONOR_LATCH_CUT 0.25). Astragal x 2.65..2.75, z -0.218..-0.206.
- Bottom box beam: top y -1.275, latch end x 2.648 (+0.5 cm cap), cabin face z -0.23, grime steel (`rear_door_donor_beam.gd` TOP, BACK_Z, material block in `build`).
- Handle (CSGCombiner) at local (2.59, -0.82, -0.12); children Mount 0.14 x 0.36 x 0.05 and Grip 0.06 x 0.26 x 0.06 at z -0.07 (`van_shell.tscn` `RearWall/LeftHinge/Handle`). `rear_doors.gd` `_ready` stores the Grip and Mount local positions, so moving Handle keeps open and close right.
- Molle bay crest edge x 2.468, y -0.01; window crest ends x 1.91; vent crest 1.665. Old scrap latch at x 2.44..2.54, y -0.13..-0.63.
- Missed lines that bear: vangapfix D71 (FLICKER near the astragal), vangapfix D75 (a phase fixes its own audit rows), rear-window-seal D19 (small parts read at `g02` distance). Research: `.claude/plans/research/rear-right-door-beam-00-intake.md`.

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- none (D1 to D13 folded into Constraints and the phases; the Option map's answers live there too)
- D15 (owner, 2026-10-13, after phase 1's look proof failed twice on the pale band between beam and yellow): the edge beam is exactly as wide as the door's bottom horizontal box beam (measure it in `rear_door_donor_beam.gd`; never widen it, no filler plate). Close the gap by extending the yellow instead: the leaf's seam-side crest (`rear_door_skeleton.gd` SEAM_BEAM, x 2.278..2.688) is painted the same yellow as the pressed bays out to the beam's cabin-side edge, so yellow runs straight into the beam with no pale band; the straps cross from the beam onto that yellow. This overrides Scope Out for the yellow paint on that crest only (the pressed bays' shape stays). missed: the plan placed the beam from the meeting edge without checking where the yellow ends (x 2.438), so a 12 cm unpainted crest showed between them.
- D16 (auto, phase 1 rebuild; x range and straps superseded by D18): D15's width is the bottom beam's HEIGHT 0.175; crest yellow is a donor-only shader band `crest_paint_x0/x1` = 2.09..2.48, lip suppressed in the band. missed: what "as wide as" measures.
- D17 (auto, phase 1 rebuild; superseded by D18, the rod values move to phase 3): the edge beam and 45-degree box wear their own cool raw-steel grime (0.09, 0.095, 0.105) with a dark weld bead down the cabin-side corner; same-as-bottom-beam grime read as the rusty stock leaf. Rod r 0.016, x 2.5525, z -0.288, orange (0.62, 0.30, 0.08); Handle x 2.49, z -0.26. missed: the beam's tone against the neighbouring rust leaf.
- D18 (owner, 2026-10-13, on the rebuilt phase 1: "this vertical bean should look the same as the horizontal one in the bottom. Just longer. Upright. And bent at the top ... copy the thing there rotate make longer and then the bend ... If the black part in the bottom doesn't fit just shrink it's width"; reference: Owner images 1.webp, red outline up the meeting edge into the 45-degree cut): the edge beam IS the bottom box beam (`rear_door_donor_beam.gd`): same 0.175 cross-section, material block, end caps, diamond beads, bolts and grime, built by that same file through a shared run helper both use, never a new-look asset. It stands upright END_SET (4 cm) inside the meeting edge, x 2.473..2.648, from the bottom beam's top y -1.275, and bends along the 45-degree cut (DONOR_LATCH_CUT) END_SET inside it. The leaf makes room for it: yellow meets it (D15 band); if a pressed bay collides, the donor molle panel (the dark lower panel) gets narrower, nothing else. The lock rod, keepers and small parts gate no look proof before phase 3; Pass test (3) is not judged in phases 1 and 2, and phase 1's rod render bug (two hair-thin green lines) is fixed in phase 3. D15's width and yellow-meets-beam stand; D16's x range and D17's own grime and rod are superseded. missed: the plan built a new crude beam instead of copying the bottom beam.
- D19 (owner, 2026-10-13, Q2 "Judge on close view"): Pass test (1) is judged on `g48-gap-rear-in-donor-latch`; `g02` is context only and never fails a phase.
- D20 (auto, from D2 "from the inside" and D18): the copy keeps the bottom beam's cabin side only: its box runs z -0.23 (BACK_Z, flush with the bottom beam's cabin face so the L reads as one) back to -0.165 (0.5 cm into the leaf), so the street face stays untouched; the street-side bolt row is dropped, the cabin row kept.
- D21 (owner, 2026-10-13, after phase 1's D18 rebuild failed look-judge (1) twice on g48: flat dark face sinking into the seam shadow, no bolts visible, bend reading as a hollow frame): give the upright and the bend a lit, chamfered street-to-cabin edge (a 45-degree lip like the bottom beam's lit top) and a bigger cabin bolt row. Same material, geometry only, the edge stays 17.5 cm wide; D20 (street face untouched) stands. The bend must read as one solid continuous L with the upright and the floor joint, not an outlined frame or a black slot. missed: copying the bottom beam's code did not copy how it reads, because its lit top face has no counterpart once stood upright.
- D22 (owner, 2026-10-13, after the D21 build still read dark in g48 under the high front lamps): accept the beam as it reads now (928e9df); phase 1 is done and its look proof closed. No work light, wear band or new view for it. missed: g48 sees the upright edge-on under lamps high in front, so no geometry could light its cabin face from that camera.
- D23 (owner, 2026-10-13, after phase 2's straps failed look-judge (2) on g48 after the r 1.5 cm screw fallback): accept the straps as they read (3d1eec9); phase 2 is done. Following the owner's earlier "I don't care about the details", look checks on small parts (straps, screws, rod, keepers, grip) from here on are reported with their pictures, not blocking: a FAIL on one is noted in the state file and the run goes on; only a crash, a failed tool check, or a broken beam/door shape blocks. missed: g48 is too far for 5-8 cm parts to pass a judge, and the owner keeps accepting them.
- D24 (auto, from D23): phase 3's look-judge FAIL on (3) (rod pale tan, reads as part of the left leaf, guides blend in) is reported, not blocking; the written fallback (rod r 1.6 cm, wider guides, z -0.2735) was skipped because it changes neither the colour nor the placement read the judge named. missed: whether the rod should be darker or sit nearer the beam's middle.

## Initial idea (Part B, approved; the numbers live in the phases)

From the cabin the yellow leaf ends at a copy of the bottom box beam (D18) standing up its meeting edge from the bottom beam and bending along the top corner cut (phases 1, 2). Five crooked Z straps with two screws each cross from the beam onto the yellow, above the dark lower panel (phases 1, 2). A rusty rebar lock rod in six welded guides runs up the beam's face, its ends in two crude welded keepers; the door grip sits on the beam beside the rod and slides past it on opening, with no lever (phases 1, 3). The old cut strips under the beam (phase 1) and the scrap striker, handle, hasp and padlock beside it (phase 4) are archived.

## Walk-through (one line: the pieces were shown together)

- Pieces 1-7 · That is it (piece 5 per D12, piece 6 per D13) · D12-D13

## Reviews

- Ready gate round 1 (build, design fit, art style): beam laps 1.2 cm over the cut; strip archive and tag moved to phase 1; Handle shifted so the Grip clears the rod, lever on the static Handle; beam UVs as a BoxMesh face; rod via `add_rod`; rod-end keepers (D14). Owner then dropped the lever (the grip slides past the rod).

## Constraints (every phase)

- Cabin face only; the street face and everything under Scope Out stay as they are (D2, from Brief: "from the inside").
- The lock is a static asset: nothing turns or animates (D9, owner: "for now just the asset").
- New pieces are built only by the two new helpers, called last in `rear_door_donor_dressing.gd` `build()` (after `RearDoorDonorJamb.build`) and drawing from its rng after every existing user, so no seeded piece moves. Meshes go through `_Panels.add` (layer 2) into `out`; no collision (the door still opens through the leaf's `Interact` body).
- The edge beam is built by `rear_door_donor_beam.gd` itself (D18), so its material, caps, beads and bolts are the bottom beam's by construction; no other file defines a beam look. Other materials: rust and weld steel = `rear_door_donor_welds.gd` `rust_steel()` / `weld_steel()`; screws dark Color (0.12, 0.08, 0.06) as in `rear_door_donor_hinges.gd`.
- Audit (`van-geometry.md` Seams; vangapfix D71, D75): a new face stands at least 1 cm (1.2 cm used) off any parallel same-facing face it overlaps; the phase fixes its own audit rows. Swing: every new point within 2.692 m of the hinge axis (sqrt(x^2 + z^2); 2 cm inside the stock leaf's edge 2.712).
- Every code phase, implementer: `py -3 tools/check.py`; `py -3 tools/smoke.py` (audit clean); `py -3 tools/shots.py capture` before (parent commit) and after, then `compare`: only views that look at the donor leaf's cabin face change (`rear-in` views, plus f04/f05 as phase 1 found), every other `same`, the bottom beam unchanged; `py -3 tools/gap_check.py <after set> --strict` ok. Reviewer when over 150 lines. Look checks: `look-judge` on `g48-gap-rear-in-donor-latch` (D19; g02 sent as context), pictures to the owner; a FAIL after the phase's fallback stops the run.
- Specs list under Read first: `.claude/rules/van-look.md`, `van-geometry.md`, `art-style.md`, `art-3d.md`, plus `art-shots.md` and `tooling-shots.md` in phase 1. Hand-built meshes wind clockwise; check the close view for see-through faces (memory: inside-out meshes).

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Look proof: bottom-beam copy upright and bent, stand-in straps (redo per D18) | code | - | D18, D19, D21 | done 928e9df (D22) |
| 2 | Welds at the L and the bend, real straps | code | 1 | D18 | done 3d1eec9 (D23) |
| 3 | Lock rod (render fix), guides, keepers and grip | code | 2 | D18 | done f48a227 (D24) |
| 4 | Archive the scrap latch | code | 3 | Brief | done b9ea9d5 |

Needs: earlier phases whose output it builds on. Rests on: decisions still in the list, or Brief. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · Look proof: bottom-beam copy upright and bent, stand-in straps (redo per D18)
Already landed (keep): view `g48` (camera rz - 2.8), the strips archived at `archive/donor-latch-cut-strips`, the D15 crest yellow band 2.09..2.48 (shader `crest_paint_x0/x1`). First action: open `rear_door_donor_beam.gd` `build` and `rear_door_donor_edge.gd`.
Deliverable (2 specs):
- Spec 1 (`rear_door_donor_beam.gd`): move `build`'s steel, caps, material block, `_corner` beads and `_bolts` into a shared run helper; `build` calls it unchanged (bottom beam identical: no non-donor view changes, scene_dump same apart from new nodes). Add `build_edge(hinge, rect) -> Array[Node3D]` (no rng) calling it for the upright (D18, D20): box z -0.23..-0.165; straight run x 2.473..2.648 (rect.end.x - END_SET - HEIGHT .. rect.end.x - END_SET) from y -1.275; bend run at 45 degrees, outer face on x + y = 4.488 - 0.04 x 1.414 = 4.431, inner on 4.431 - 0.175 x 1.414 = 4.184, mitre corners (2.648, 1.783) and (2.473, 1.711); its far end square and capped, highest corner at y 2.01 (END_SET under the top 2.05). The mitre is cut, not two overlapping boxes (two cabin faces at -0.23 overlapping are a FLICKER row), with a `_corner` bead along it. Cabin bolt row on both runs at the bottom beam's pitch; beads where the runs meet the cabin skin (z -0.17). Swing: cap corner (2.653, -0.24) radius 2.664 < 2.692.
- Spec 2 (`rear_door_donor_edge.gd`): drop the stand-in beam, 45-degree box, own grime, cabin-corner bead and rod; call `_Beam.build_edge` first. Z straps keep their y and 5 cm: face leg x 2.473..2.643, z -0.23..-0.242; side leg x 2.461..2.473, z -0.17..-0.242; foot x 2.356..2.461, z -0.17..-0.182. Handle to x 2.5605, z -0.25 (Mount back 0.5 cm into the beam face; corner (2.6305, -0.275) radius 2.645).
Verification: Constraints' commands. Check: the donor molle crest edge (x 2.468) stands 0.5 cm off the beam's inner face; an audit row or a bay touching the beam in g48: donor-only narrower molle panel, x1 2 cm in (auto, D18). Look-judge on g48 (D19): (1) the beam reads as the bottom beam turned upright (same tone, caps, bolts, beads), straight up the edge and bent along the cut, yellow meeting it; (2) straps placement and size. (3) not judged (D18). Fallback once: straps' face leg 1 cm narrower each side.
Reviewed: Right (owner, phases question 2026-10-13; redone per D18)
Notes:

### 2 · Welds at the L and the bend, real straps
Deliverable (1 or 2 specs, `rear_door_donor_edge.gd` only; reads `rear_door_donor_beam.gd` `_corner`, `rear_door_donor_hinges.gd` `_hex_bolt`). The beam is the real copy from phase 1 (D18); only joints and straps here.
- Welds (`weld_steel`): diamond beads like `_corner` (no face parallel to a beam face) across the cabin-face joint at y -1.275 where the upright sits on the bottom beam, and down the upright's inner side, so the two read as one welded L (D5).
- Straps: each a Z of three 5 cm tall, 1.2 cm thick bars at phase 1's x and z; a short bead where the face leg meets the beam. Two hex screws per foot at x 2.376 and 2.436: 6-sided, r 1.2 cm, 1.2 cm tall. Each strap turns rng 1 to 4 degrees about its beam end, sign alternating; straps 1, 3, 5 `rust_steel`, 2 and 4 `weld_steel` (D7, D11 "mismatched"). Feet land on flat yellow crest: x 2.356 > window 1.91.
Verification: Constraints' commands. Look-judge on g48: Pass test (1) and (2) in full; (3) waits for phase 3. Fallback once: screws r 1.5 cm.
Reviewed: Right (owner, phases question 2026-10-13)
Notes:

### 3 · Lock rod (render fix), guides, keepers and grip
Deliverable (2 specs: new `rear_door_donor_lock.gd` called right after the edge helper; take the Handle line out of `rear_door_donor_edge.gd`; reads `rear_door_donor_hinges.gd`). First: why phase 1's rod showed as two hair-thin green lines (D18; inside-out or culled faces, the cylinder build, or grime on a thin mesh); the rod here must render. The numbers below were worked for the old 8 cm beam (x 2.56..2.64, face -0.24): shift them to D18's beam, every x by -0.0945 (rod x 2.5005, guides 2.476..2.525 inside the beam's 2.473) and every z by +0.01 (face -0.23), keeping each gap; the Handle stays where phase 1 put it (x 2.5605, z -0.25), so the Grip (x 2.5305..2.5905) clears the rod's edge 2.513 by 1.75 cm; the Grip and Mount lines below give way to these.
- Rod (D8): rebar via `iron_cross_geo.gd` `add_rod` on a flat geo (`IronCrossGeo.new(null, 0.0, 1.0, 1.0)`: `surface_z` 0), path (2.595, -1.25, -0.27) to (2.595, 1.78, -0.27), radius 0.0125, 8 sides, `IronCross.RIB_STEP` ribs, `rust_steel()`; `on_mesh` sets layer 2, shadows off (as `_Panels.add`); node into `out`.
- Keepers (D14, owner: "one crude scrap welded keeper at each end", rod still static): a guide-profile U (below) 6 cm tall, a 1.2 cm plate closing its end, beads at the leg feet. Bottom y -1.27..-1.21, plate at the bottom (-1.27..-1.258), rod foot 0.8 cm above it. Top y 1.745..1.80, plate at the top (1.788..1.80), rod top 0.8 cm under it, 1.5 cm over strap 5 (top 1.73); beam face at the right leg reaches 4.505 - 2.6195 = 1.886.
- Six welded flat-bar U guides, 3 cm tall, 1.2 cm bar: front x 2.5705..2.6195, z -0.2825..-0.2945; legs x 2.5705..2.5825 and 2.6075..2.6195, z -0.24..-0.2825; a bead blob at each leg foot. Centres y -1.15 and -0.55 (below and above the Mount, -1.00..-0.64) and 0.29, 0.70, 1.10, 1.51 (midway between straps).
- Grip (D10, D12): the lock helper sets the donor `Handle` where phase 1 put it (after `rear_door_portal.gd` `_layout`); opening (`rear_doors.gd` pulls the Grip 6 cm cabin-ward) slides it past the rod; no lever. Swing: every new corner's radius <= 2.692.
Verification: Constraints' commands. Look-judge on g48 (last check before removal): Pass test (1), (2), (3) all. Fallback once: rod r 1.6 cm, guides and keepers 0.35 cm wider, rod z -0.2735.
Reviewed: Right (owner, phases question 2026-10-13)
Notes: built f48a227; rod renders solid (rebar via add_rod, flat rust_steel, no grime shader); look-judge (3) FAIL: rod reads pale tan and as part of the left leaf, guides blend in; (2) unchanged FAIL; report-only per D23, fallback skipped (D24).

### 4 · Archive the scrap latch
Deliverable (1 spec; reads `rear_door_donor_hinges.gd` `build`):
- Hinges: drop the `_latch` call, `_latch` and `LATCH_AT` (no rng use); phase 1's tag `archive/donor-latch-cut-strips` already holds them (memory: archive removed art; D4, D13). The rod is the only lock (D13).
- Docs: one line in `van-look.md` naming the two new helpers and the tag; `py -3 tools/gen_context.py`.
Verification: Constraints' commands. Look-judge: Pass test (1), (2), (3) still hold with the old latch gone.
Reviewed: Right (owner, phases question 2026-10-13)
Notes: built b9ea9d5; check, smoke (audit clean), scene_dump identical; shots: only 02-idle-back moved (0.791, tol 0.622); gap_check strict same 8 known fails, g48 0 px; look-judge (1) PASS, (2) and (3) FAIL unchanged from phase 3, report-only (D23, D24).

## Carry forward

- The close view is `g48`; the beam's cabin face z is -0.23 (D20), its x 2.473..2.648 (D18).
- Phase 1 first build (df98866, superseded by D18): close view `g48-gap-rear-in-donor-latch`, camera at z rz - 2.8; `van-geometry.md` view count 48; old strips archived at tag `archive/donor-latch-cut-strips`; the crest yellow band (D15) closed the pale gap; the rod stand-in rendered as two thin green lines (fixed in phase 3).
- Phase 3 (f48a227): lock pieces live in `rear_door_donor_lock.gd` (`DonorLock*` nodes, Handle placed there); before/after shot sets `rrdb-p3-before`/`rrdb-p3-after`; 02-idle-back, f04, f05 move when the donor cabin face changes.
