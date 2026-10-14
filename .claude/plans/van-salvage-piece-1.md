# van-salvage-piece-1

Stage: done
Started: 2026-10-13
Procedure: `.claude/skills/plan/interview.md`, then `run.md` (state in `.claude/plans/van-salvage-piece-1.state.md`).
Path: full
Size: 20 KB, phases 2.5 KB (interview.md "Plan size")
Interview: C done · 9 asked · ready gate passed: build review 1 (88c41bd), design-fit and art-style (ca6697e), build review 2 (the last, 6b2052e); Questions auto confirmed 2026-10-13 · missed: does the bulkhead view light the rear-right ceiling enough to judge roof pieces? · missed: is one bulkhead view enough to judge a corner post's depth? · missed: do the wall pieces need the ring's pressing (corner radius, recessed inset) to read as one pressed shape? · missed: how is "seamless with the rear arch" measured, not only judged? · missed: does "seamless" mean one mesh/material with the arch, not two meshes that touch?
Questions: auto

## Brief (owner's words, verbatim)

here is my goal

first understand that the van inside must all be reworked, i already started the rear and the floor, but i wanna do my first litle piece into the rest as you see in the image

the goal is to in the end make the van look like it was savanged from many parts

in this plan ur gonna make i want you to look at the red outlier i put in the image and extend the same kind of van from the rear into those areas as if the rear outframe and the parts inside my red area came from the same vehicule get it? dont worry about how it fits with its surroundings, the goal is to make a high quality group of assets that fit well togheter within the red outliner and above everything they must be 3dimensional, ignore shaders and textures for nowk you can just repeat what we have on the rear outer arc if you want but it isnt important

what matters is that these assets feel like and eat into the space of the van, i made the van bigger on purpose so that we can consume the inner space with volumed assets, its ok if part of the side wall as a certain inclination a certain round or not round shapoe, and then suddently we do into another, but in this case we keeping the artstyle somehwat the same purelly for this puzzle piece we are making.

Reference image: described in `.claude/plans/research/van-salvage-piece-1-00-intake.md`, never opened again.

## Pass test (judged by the `look-judge`)

- (D11) In flat grey, a viewer at the bulkhead looking at the rear-left corner says (1) "that corner, the wall strip beside the rear door and the ceiling above it came off the same vehicle as the rear door frame: the same pressed-steel shapes, as deep as the ring plus its ledge or deeper, continued round the corner" (D39: pieces 0.5 deep, the ring 0.30 + ledge 0.20, said to the judge); (2) "those parts are solid volumes that stand well into the room, not plates on the wall"; (3) "where they stop, the old wall and ceiling just carry on; the cut is abrupt and that is fine"; (4) (D53) "the corner piece reads as the same pressed part as the rear arch, no visible seam or step".

## Scope

- In: `scripts/van/look/van_salvage_piece1*.gd`, `SalvagePiece1` and a `_proof.gd` under `Interior/Shell` (`van_shell.tscn`); the +x rear ends of `CoveR`, `*Rail_R_*`, `RoofEdgeSeal_R` and the cable trunk; `van_interior_cams.gd` (one view); `debug_flat_grey.gd` + `debug_van_commands.gd`; `_clamp_in` (one keep-out, D38); `shots.py` TOLERANCE rows; the scene-dump baseline; `van-geometry.md` and `docs/glossary.md` lines.
- Out (as is): the rear arch (`RearWall/Portal`), both leaves, the `RightRear` window (sash, bars, glass, breach point, collision), the floor, the x<0 wall and all on it, the ceiling outside the region, every lamp (but the fallback), the van size classes' values, shaders and materials, `VanPlayerContainment`, raider nav (but D38's keep-out), the facade keep-out, the smoke fingerprint.

## Current state (2026-10-13; grep the names)

- Arch (`rear_door_portal.gd`, `rear_door_surround.gd`): opening x ±2.7, top 3.6, corner r 0.375 about (2.325, 3.225); ring = outline + 0.30 (flat x 2.86..2.967, bevel to 3.03; outer arc r 0.675: x 3.00 at y ≤ 3.225, 2.954 at 3.47, 2.46 at 3.886), face z 6.14; ledge face z 6.24; pillar pocket y 1.0..1.6, x 2.885..2.935 (0.05 of the 0.107 flat), 0.12 deep.
- Region: `CoveR` (z 6.427, sunk 3.5 cm); `CargoRail_R_*` (y 0.72) and `BeltRail_R_*` (y 1.52), 6 cm boxes 1.5 cm in the wall to z 6.48; `RoofEdgeSeal_R`; the +x cable trunk (x 3.03, y 2.95 − sag, z −4.4..6.08, ties and splices; only `route()` drops avoid `build_keepouts`); `SidePillars/RightRear` hidden; `RightRear` window cut z 3.12..5.564, y 1.068..2.482.

## Open items

- none

## Decisions (`(auto)` = taken while running)

- (D1-D42 folded; `(auto)` ones collect here)
- D43 (auto): flatgrey re-scans the rig for 3 frames after it appears (VanLighting moves meshes onto `LAYER_VAN_INTERIOR` a frame late) and its black glass is `CULL_DISABLED` (side panes face the street); reviewer and judge findings.
- D44 (auto): `piece_rear_left` runs on its fallback camera (−3.0, `_EYE`, `BULKHEAD_Z` + 0.4); the first position failed the look check.
- D45 (owner, 2026-10-13): the `piece_rear_left` framing is accepted (all three parts in frame); flat grey gets its own even fill light, debug only (an ambient or camera light that `flatgrey on` adds and `off` removes). No game lamp changes; only the grey sets are judged for the Pass test.
- D46 (auto): views that frame the rear-right corner count as region views from phase 2 on (c15, c16, g03, g04, g10, g14, g45, g47, g48, f05, icam `prop_fuse_box`, `corner_rear_right`, `rear_doors`); the prisms show in them. g02's clip 1.50 % predates the pieces (p2pre 1.504).
- D47 (auto): the proof prisms run on the plan's self-fix ladder plus the tuning fallback (`van_salvage_piece1_proof.gd` constants: wall face x 2.80, post/roof rear z 6.23, front plane z 5.60, head bottom y 2.52, roof drop 0.26, bow drop 0.51, cant bottom y 3.42, roof from x 0.05); FLICKER rows forced each move.
- D48 (owner, 2026-10-13): the phase 2 stand-ins are accepted as proof of depth and volume (S2, S3 pass); S1 (one deep pressed shape carried round the corner, the post's depth visible) is judged again in phase 3 with bevels, the round-edged cant rail, pockets and beads in, and phase 5's final look check stays.
- D49 (auto): phase 3 FLICKER/OPENING self-fix moves on the wall pieces: floor sink y −0.045, back pad 0.03 (kick back x 3.42), front z 5.594 (clears `PlateR6`), head panel bottom y 2.54 (cleared OPENING `win_right_rear`); the lower post is one loft. The trunk cut lives in `van_cable_router.gd` (`cut_trunk`, `TRUNK_STOP_Z`) because `van_cable_runs.gd` sits at 400 lines.
- D50 (auto): the phase 3 fallback (pocket 0.15) left the region views `same` (0.008/0.016/0.001), so the judge was not re-run on identical pictures; its FAIL stands.
- D51 (owner, 2026-10-13): S1 blocker answered "add pressing first": new phase 3b before 4 carries the ring's rounded corner radius and a recessed inset panel (like the rear door's pressed inner frame) onto the post and head panel faces; the pressing is the main shape, never flat. Phase 3 is done; S1 is judged at 3b.
- D52 (auto): phase 3b built as two `room_sheet` calls (kick box + lower post to y 0.97, upper post from 1.63) with the 0.15 pocket band between, not one sheet; the reviewer found no hole, only seam vertices (fixed fc51596).
- D53 (owner, 2026-10-13), after 3b's shots: "this part we are making is supposed to fit seamlessly, like it's from the same place as the arch of the rear; at the moment it doesn't seem to be the case." 3b's judge passed S1 too leniently and nothing measured the join. Picked: stop phase 4, add phase 3c where the wall pieces continue the arch's own section (same depth, corner radius and pressing running on from the arch, no step or seam where they meet), judged on a close shot of the join plus a measured check (no depth step at the seam); phase 4 then reruns and builds the roof off that same section. Phase 4's partial output: the unwired `van_salvage_piece1_bow.gd` (84f6a43).
- D54 (auto), phase 3c: smoke's strict van audit fails on 7 FLICKER rows inside `RearWall/LeftHinge/DonorBox*`/`DonorSeamPacker*` that came in with main (2dee7f9 merge of 64b70b7, rear door donor box); outside Scope, left alone; this plan's smoke is judged as no row naming `SalvagePiece*`.
- D55 (owner, 2026-10-14), phase 3c blocked on S4 after its fallback: picked "grow it out of the arch": the post and head panel are an extension of the arch's own mesh, same material and normals across the join (no hairline or shade line), the head panel sweeping the arch's top arc (no hard vertical cut), the ring's pressing run on into the post (crests to the seam, no dark strip at another depth by the ring); about 2-3 specs, then the judge on the same views plus `icam_salvage_seam`; the measured seam check stays. `RearWall/Portal` stays Out (Scope), so the extension is built in the salvage files from the arch's own functions (from Scope).
- D56 (auto), phase 3c pass 2: the seam check's band samples the flat sheet only (crest and pocket rects, read from `_press.gd`/`_Surround`, are skipped), and every 0.1 m from y 1.0 to the arc end; zero normal pairs counts as a failure.
- D57 (auto), phase 3c pass 2: the band ends at z_deep (`_BAND_Z1` 0), since past the post's fillet only the arch's own `RampLoft` is there.
- D58 (owner, 2026-10-14), phase 3c blocked on S4 after pass 2 (Q2): picked "extend and sweep it": the head panel runs on along z to the arch and its arch-side end sweeps round the ring's outer arc at the arch's depth (one or two specs), and `salvage_seam` is reframed a little off grazing so S2 (the post standing into the room) can be judged; the seam check stays.
- D59 (auto), phase 3c pass 3: the head/post joint at z 5.594 closes by sinking the head's back end 2 cm into the post (both caps closed, `open_w` removed), and the head arc and the `ring` clip share one angle list (`van_salvage_piece1_head.gd`), after review found a hole and ~12 T-junctions (ef873ad).
- D60 (owner, 2026-10-14), Q3: picked "accept 3c and run phase 4": 3c done (seam 0.002 / 0° / 0.003, S2 4/4, S4 3/4; g02's field is the `SalvagePiece1Proof/CantRail` stand-in); phase 4's roof pieces meet the arch's upper corner and S4 on g02 is judged again in phase 4 and at phase 5. Phase 4 re-derived off 3c's section: rail = the head outline above y 3.47 run forward to z 4.2, panel underside on the arch room face top y 3.73 to x 2.0, bow crown 3.47 cut by r 0.525 (from `van_salvage_piece1_wall.gd`, `_head.gd`, `_bow.gd`).
- D61 (auto), phase 4: the look fallback ("panel underside filleted into the arch") was built as a half-round bead along the seam's room-face arc at z 5.70 (f2e84fe), because the probe showed the flat field is the seam's front strip, not the roof panel; still FAIL, so blocked on Q4.
- D62 (owner, 2026-10-14): Q4 answered "keep the bead, move on": the half-round return bead (f2e84fe) stays on the seam's flat front strip and phase 4 is accepted; S4 on g02 is judged again at phase 5's final look.
- D63 (auto), phase 5: the lamp check passes on g02; 08/11 back views over clip (0.747 %) predate the phase (0.48/0.51 in p4b) and the z 4.4 fallback did nothing, so the lamp stays at z 4.7.
- D64 (auto), phase 5: final look FAIL (S3 1/5, S4 1/5); the pocket-depth fallback was skipped because no failure is pocket depth (corner block at the arch, black ceiling, framing); run blocked for the owner.
- D65 (owner, 2026-10-14): the final look is accepted as built (S1/S2 4/5, S3 1/5, S4 1/5): the square block at the arch corner (bead kept, D62), the black rear-right ceiling in normal shading and the `icam_ceiling_rear` framing stay as they are for now. Phase 5 finishes with its Docs bullet only, and the plan closes.

## Initial idea (accepted D18)

Left of the untouched arch, the same deep pressed steel carries on from the floor round into the ceiling, 0.5 m proud of wall and roof (D13), then stops dead on flat cut faces (D6). No new interaction, sound or HUD text. Pieces: 1 corner post with the arch's pocket; 2 kick box under the window; 3 head panel over it; 4 round-edged cant rail (D19); 5 pocketed roof panel to x 0; 6 roof bow behind the lamp; 7 flat cut ends, clipped +x neighbours; 8 the `piece_rear_left` view and flat grey.

## Walk-through

- Pieces 1-8 · D18. Reviews 1-2 (D20-D29), C (D32), build 1 (D33-D37), design and art (D38-D42), build 2 folded.

## Constraints (every phase)

- Sides (D20, D25): the plan's "left" is +x; every node touched is `RightWall`/`CoveR`/`*_R`/`RightRear`; only +x neighbours are clipped, `_L`/`CoveL` stay (count before and after); the Out list is untouched.
- Host sampling (D33; sampled live): `inner_x_at(y)` = `wall_half_at` (`van_body_profile.gd:57-78`): 3.39 to y 1.65, belt blend to 1.95, lean −0.1955/m (3.253 at 2.5, 3.0636 at 3.47, 3.06 at 3.49) to y 3.596, then the corner arc r 0.5 about (2.548, 3.5): 2.91 at 3.845, 2.719 at 3.97, 2.548 at 4.0. `VanCeiling.vault_y_at(x)` with the shell's `edge_height` 3.97 (`van_shell.tscn:215`, not the script default 3.93) = 3.97 + 0.10·(1 − (x/2.855)²): 4.07 at x 0, 3.996 at 2.46, 3.993 at 2.50. Never `roof_y_at` or `section_points` (both clamp to the wall top 4.0, `van_body_profile.gd:103`); floor y 0 in the region (`VanFloorHeight.at`).
- Build language (D3, D16, D17): closed clockwise hard-edged prisms from 2D outlines, built as the arch (`rear_door_portal.gd`: `_prism` :186, `_punch` :133, pocket prisms 66-75; `rear_door_surround.gd`: BEVEL 0.03 in BEVEL_STEPS 4, POCKET_*; read BEVEL, never retype it, D41); deep members 0.5 (the bow 0.46, D31), skins 0.2, blind pockets 0.12; every cut end a flat bevelled plane; no notching, taper or trim. Fixings (D40, `art-3d.md`, the leaf): one continuous uneven bead per seam (none on the arch seam, D53), segments 0.06..0.09 by `rear_door_donor_welds.gd` `add_bead` (:145, SEG_* :26; no radius: boxes BEAD_W 0.02 × BEAD_H 0.012), stood off both faces as the leaf's `_filler` (:164): offset 0.4·BEAD_W off the piece's face, z = the seam face − 0.4·BEAD_H; RNG `rng_for(&"salvage_piece1")` as `iron_cross.gd` `_rng` (:179-191: VanLook by `VanLook.GROUP`, missing → seed `hash(name)`; connect `look_rebuilt` and rebuild the beads; `Interior` readies before `VanLook`, `van.tscn:109/361`, so a `_ready` lookup is null); material `weld_steel()` (:38; D42); no fixed-pitch stitches. Prisms `van_rust_steel_material.tres`; all `layers = VanLighting.LAYER_VAN_INTERIOR`, shadows on (D4). Sizes are constants from the van size classes (D9).
- FLICKER (D6, D21, D26, D29): a face against the host sinks 2 cm into it; pieces meeting the arch sink 2 cm into it (D53, from 3c: z 6.16 within the ring's offset 0.30, 6.26 on the ledge; was 1 cm clear at 6.13/6.23); 2 cm off a window reveal; new pieces sink 2 cm into each other, except room faces on one plane (post, kick box, head panel at x 2.89), which abut edge to edge in one ArrayMesh. Audit rows: the self-fix ladder (own face, own numbers, one neighbour's number, one exact exemption) (D9).
- Collision (D10): every volume adds `CollisionShape3D` children to `Interior/Shell` (StaticBody3D, `van_shell.tscn:172`); no wall face at x < 2.80 (door lane 2.75 + 0.05); ceiling pieces start at y 3.47 (the tallest cabin capsule tops out at 2.2).
- Verify (implementer; every tool is `py -3 tools/<name>`): `check.py`; `smoke.py` (FLICKER 0, `VAN CONTRACT` clean); `scene_dump.py` when a van scene changes; four shot sets (D35): `smoke.py --shots .godot/shots/p<k>-<set>` for `normal`, `normal-icam` (`--views icam`), `grey` (`--pre "flatgrey on"`), `grey-icam` (both); `shots.py compare p<k-1>-normal p<k>-normal` and the `-icam` pair: only the **region views** may read `changed` (`g02`, every `*-back` view; icam `piece_rear_left`, `wall_left_rear`, `ceiling_rear`); `gap_check.py` (no new magenta) and `shot_stats.py` on `p<k>-normal` (g02 and `*-back`: mean ≤ 0.10, p95 ≤ 0.28, clip ≤ 0.5 %, `art-shots.md`). `--bless` only in phase 5.
- Look checks: the `look-judge` gets the plan path, phase, statement numbers, `icam_piece_rear_left`, `icam_wall_left_rear`, `icam_ceiling_rear` and `g02-gap-rear-in-whole` (the `-grey*` sets for 1-2, `-normal*` for 3), before = the p1 sets, earlier verdicts, pictures to the owner. FAIL → the phase's one tuning fallback → judge again → still FAIL: `Status: blocked`.

## Progress

| # | Phase | Kind | Needs | Status |
|---|---|---|---|---|
| 1 | View and flat-grey render | code | - | done 87256fe |
| 2 | Look proof (stand-ins), loper keep-out | code | 1 | done 6688dc1 (S1 accepted to phase 3, D48) |
| 3 | Wall pieces, rail and trunk caps | code | 2 | done 3d03890 (S1 carried to 3b, D51) |
| 3b | Pressing on the wall pieces | code | 3 | done fc51596 |
| 3c | Seamless join with the rear arch | code | 3b | done c6b6786 (S4 g02 carried to phase 4, D60) |
| 4 | Roof pieces, cove and seal clips | code | 3c | done 40afd2d (bead kept, S4 g02 to phase 5, D62) |
| 5 | Final look, lamp check, baselines, docs | code+doc | 4 | done 0ab22bc, 28f3379 (look accepted as built, D65) |

Status: todo, done <sha>, deferred Q<k>.

## Phases

### Phase 1 · View and flat-grey render (code; piece 8)

- Deliverable 1, `van_interior_cams.gd`: view `piece_rear_left` at (−(`BOTTOM_HALF` − 0.5) = −2.89, `_EYE`, `VanOpenings.BULKHEAD_Z` + 1.0) looking at (2.89, `_EYE`, 5.5) (the post's face; D7, D37), through `_add` so `_check` runs. Working: `_FOV` 70, `KEEP_WIDTH`, 1440×720: vertical half-tangent 0.350; the region corners (x 3.39 / 2.5, y 0 / 4.0, z 4.9 / 6.1) sit at depth 6.1..7.5 with |Δy| 2.0: tangents 0.27..0.33. Check (look-judge, one yes/no on `icam_piece_rear_left` from `p1-normal-icam`): floor at the wall, ceiling over the window and the strip beside the door all in frame. Fallback once: camera (−3.0, `_EYE`, `BULKHEAD_Z` + 0.4) (depth to (2.5, 4.0, 4.9) 6.51, tangent 0.31); never the region (D2).
- Deliverable 2, flat grey (D8, D24): `scripts/debug/debug_flat_grey.gd` built like `debug_gap_light.gd`, console `flatgrey on|off` in `debug_van_commands.gd` (help line too): `on` sets one `StandardMaterial3D` (albedo 0.5 grey, roughness 0.9, metallic 0) as `material_override` on every `MeshInstance3D` under the rig whose `layers` include `LAYER_VAN_INTERIOR`, paints `WindowGlass`/`ExteriorPane` black as `gaplight` does, remembering the old overrides; `off` restores them. `--pre` runs before the van exists (`smoke_test.gd:9`): `on` with no rig arms it and applies when the rig appears (`get_tree().node_added`, then `VanAnchors.rig`).
- Deliverable 3: the four `p1-*` before sets.
- Verification (implementer): `check.py`; `smoke.py`; the four sets exist, the icam ones with `icam_piece_rear_left.png`; `compare p1-normal-icam p1-grey-icam` reads `changed` on every icam view and `compare p1-normal p1-grey` on g02; a second capture of each reads `same` on every view. Reviewer: the `off` restore path; nothing on `LAYER_VAN_INTERIOR` skipped.
- Files read: `debug_gap_light.gd`, `van_interior_cams.gd`. Specs: 2 (view; flat grey + sets).
- Notes: built 87256fe. Look check FAIL twice (first camera, then fallback): floor and door strip YES; the ceiling over the RightRear window is in frame but unlit, solid black in normal and grey (`judge2.md`). Run blocked on it.
### Phase 2 · Look proof, loper keep-out (code; pieces 1-6 as plain prisms)

- Deliverable 1, `scripts/van/look/van_salvage_piece1_proof.gd` on node `SalvagePiece1Proof` under `Interior/Shell`: six plain prisms (xy outline along z; no bevel, pocket or bead), rust steel, interior layer, each a convex shape on `Shell` (D10). Back faces 5 cm in the host (rails 1.5 cm in, cove 3.5: faces > 1 cm apart; nothing clipped before phase 3). Depths (D13, D17):
  - post: (2.89,−0.05) (3.44,−0.05) (3.44,1.8) (3.11,3.47) (2.89,3.47), z 5.584..6.13; kick box: x 2.89..3.44, y −0.05..1.0, z 4.9..5.584; head panel: (3.053,2.502) (3.303,2.502) (3.113,3.47) (2.89,3.47) (2.89,3.335), z 4.9..5.584;
  - cant rail (D33): outline (2.46, 3.47) (3.11, 3.47), then `inner_x_at(y)` + 0.05 up the corner arc (3.09 at y 3.6, 3.00 at 3.8, 2.90 at 3.9, 2.77 at 3.97) to (2.46, 4.04), z 4.2..6.13; roof panel: x 0..2.50 at six stations 0.5 apart, bottom `vault_y_at(x)` − 0.20 (3.87..3.793), top + 0.05 (4.12..4.043), z 4.9..6.13; bow: the same stations, x 0..2.48, bottom `vault_y_at(x)` − 0.46 (3.61..3.534), top − 0.18 (3.89..3.814), z 4.9..5.4.
- Checks: FLICKER 0, contract clean; fallback the ladder's second rung (back faces 2 cm deeper). `p2-*` vs `p1-*`; `gap_check` and `shot_stats p2-normal` within budget.
- Deliverable 2 (D38; the one exception to "raider nav stays as is"): `window_raider_motion.gd` `_clamp_in` (:152) keeps lopers (no collision) at x ≤ 2.54, z ≤ 5.66, so a corner loper's r 0.7 hitbox (x 3.24) sat in the post. Add one keep-out, the wall footprint x ≥ 2.89, z 4.9..6.3 grown by `CLEARANCE` 0.85: a centre with z > 4.05 is clamped to x ≤ 2.04. Check: `probe.py --cmd "summon loper" --eval` on the raider's `_motion._clamp_in` (group `enemy`, `window_raider.gd:60`; nothing puts a live loper in the corner): (3.3, y, 5.5) → x 2.04; (3.3, y, 4.0) → 2.54 (unchanged); (−3.3, y, 5.5) → −2.54. Fallback: widen by the overlap the numbers show.
- Verification: the Verify list (`scene_dump.py` prints the new node, not blessed). **Look proof (look-judge): statements 1, 2, 3** on the four views (D11), told these are unbevelled stand-ins at the real depths. Tuning fallback once: the wall faces out to x 2.80 (0.61 deep, the lane cap) and the ceiling pieces 0.05 deeper.
- Files read: `rear_door_portal.gd` (`_prism` :186), `van_shell.tscn:172`, `window_raider_motion.gd:1-40,152`. Specs: 2 (proof; keep-out). Needs: 1.
### Phase 3 · Wall pieces, rail and trunk caps (code; pieces 1-3, 7)

- Deliverable 1, `van_salvage_piece1.gd` (node `SalvagePiece1` under `Interior/Shell`: meshes + `Shell` collision) + `van_salvage_piece1_wall.gd` (builder), one ArrayMesh:
  - Post (D12, D13, D21, D26-D30): back `inner_x_at(y)` + 0.02 (3.41 below the belt 1.65, 3.08 at 3.49), room face the plane x 2.89 (0.52 deep at the floor, 0.19 at the rail), y −0.02..3.49 (2 cm into floor and cant rail); z front 5.584 (jamb 5.564 + 0.02), rear 6.13 inside the ring (x ≤ 3.03 below y 3.225, inside the r 0.675 arc above: x ≤ 2.954 at y 3.47), else 6.23. Pocket on the x 2.89 face: y 1.0..1.6, z 5.73..5.985 (0.255 = the ring's share 0.05/0.107), 0.12 deep, 3 cm bevels. Bead (the Build-language stand-off) on the seam x 2.89 / z 6.14: a (2.89, 0.1) → b (2.89, 3.4), offset (−0.4·BEAD_W, 0), z 6.14 − 0.4·BEAD_H.
  - Kick box (D15): x 2.89..3.41, y −0.02..1.0 (sill 1.068), z 4.9..5.584, abutting the post; room edges bevelled.
  - Head panel (D22, D28): outline (3.053,2.502) (3.273,2.502) (3.08,3.49) (2.89,3.49) (2.89,3.335), z 4.9..5.584, abutting the post; room and forward edges bevelled.
  - Collision: one convex shape per prism on `Shell` (room face x 2.89 ≥ 2.80).
- Deliverable 2, `van_side_wall.gd` `_add_rail_segments` (+x only, D5, D25): the `CargoRail_R` span crossing z 4.88 ends there; `BeltRail_R` spans with z0 ≥ 5.5 (in the post) are not built; `_L` counts unchanged. `van_cable_runs.gd` `_build_trunk` (D36): every RNG draw stays (`_build_junk` reads the same `rng` after, :89): for sx > 0 cut only the polyline given to `cable_bundle` at z 4.88 (after `hop_bays`); a tie or splice drawn past 4.88 gets no `_claim` and no mesh; the returned pts stay full (lamp-drop anchors); −x untouched. Remove the proof's post, kick and head stand-ins (roof ones stay).
- Verification: the Verify list (`p3-*`). Reviewer: −x rails and trunk untouched, no RNG draw added or removed, abutting faces share vertices. **Look check (look-judge): statements 1 and 2** on the four views, told the ceiling is still stand-ins. Tuning fallback once: pocket depth 0.12 → 0.15 (bevel stays 0.03, D41).
- Files read: `rear_door_portal.gd:66-75,133,186`, `rear_door_surround.gd` (BEVEL, POCKET_*), `rear_door_donor_welds.gd:26-50,145,162-168`, `iron_cross.gd:179-194`, `van_side_wall.gd:293-325`, `van_cable_runs.gd:96-133`. Specs: 2. Needs: 2 (PASS).
### Phase 3b · Pressing on the wall pieces (code; pieces 1-3, D51)

- Deliverable 1, new helper `scripts/van/look/van_salvage_piece1_press.gd` (the wall builder is at 276 lines): the x 2.89 room faces become one pressed sheet like the leaf's cabin face (`rear_door_skeleton.gd:63-85`): the crest is the face rect minus the crest outlines (`rear_door_skin.gd` `_pieces` :121), flanks `RearDoorPress.profile` (:62; read `DEPTH` 0.08, `STEPS`, `ROUND`, never retype them) foot to crest, a flat floor at the foot (`floor_panel` :56). `sweep` writes leaf-local z, so port it through the builder's basis and `_quad`/`_tri` (`:34-35`, `:257-276`). Crest outlines in (z, y), corners `RearDoorPress.rounded` (:106) r = the ring's `rear_door_flange.gd` `RADIUS_BOTTOM` 0.18; foot = crest shrunk by the flank 0.05 (`rear_door_skeleton.gd` `BOT_SLOPE`), so r 0.13:
  - post (face z 5.594..6.13 × y −0.045..3.49): lower z 5.664..6.06 × y 0.12..0.88, upper z 5.664..6.06 × y 1.72..3.32; the 0.15 pocket (y 1.0..1.6) stays on the beam between;
  - kick box (one sheet with the post): z 4.97..5.524 × y 0.12..0.88;
  - head panel's sloped room face ((3.053, 2.54) to (2.89, 3.335)), in (z, distance up the slope from the nose): z 4.97..5.524 × 0.20..0.70, recess along the face normal.
- Deliverable 2, the ring's radius on the outline: the head panel's nose (3.053, 2.54) filleted r 0.18, 12 segments, in its xy outline (tangent 0.147 up the slope, under the opening's 0.20); other edges keep their 3 cm bevels (D41). Collision unchanged (convex hulls, room face ≥ 2.80).
- Verification: the Verify list, sets `p3p-*` (`p3b-*` is phase 3's fallback) compared with `p3-*`. Implementer: one read of grey `icam_piece_rear_left` for inside-out faces. Reviewer: crest, flank and floor share vertices (no T-junction, as 374bf01), clockwise fronts, press constants read not retyped, −x untouched. FLICKER rows: the self-fix ladder (Constraints). **Look check (look-judge): statements 1 and 2** on the four views (`-grey*` sets), told the ceiling is still stand-ins; before = `p3-*` and `%TEMP%/p3/judge.md`. Tuning fallback once: recess 0.08 → 0.12 (`rear_door_surround.gd` `POCKET_DEPTH`) and flank 0.05 → 0.08; still FAIL → `Status: blocked`.
- Files read: `rear_door_press.gd:1-72,106-120`, `rear_door_skeleton.gd:1-35,63-85`, `rear_door_skin.gd:121-160`, `rear_door_flange.gd:1-10`, `van_salvage_piece1_wall.gd`; rules `art-style.md`, `art-3d.md`, `art-shots.md`, `van-geometry.md`, `van-look.md`. Specs: 1. Needs: 3.
- Notes: built e062fb6 (wired), 59f81cb (helper split, wall 295 / press 193 lines), fc51596 (seam vertices). Look check PASS first time (S1 3/3, S2 3/3 wall views; `icam_ceiling_rear` has no wall piece, still a stand-in), no fallback. Merge of main (20e57d6, f4ca0c2) moved f04, c09/c10, rear-door and `-front` views (reviewer: rear-door change, not the piece).
### Phase 3c · Seamless join with the rear arch (code; pieces 1-3, D53, D55, D58)

- Third pass (D58) fixes judge 4 (`%TEMP%/p3c5/judge4.md`): in g02 the head panel ends in a vertical edge (x≈288, y 90-210) short of the arch's upper corner (x≈395-430); S2 can't be judged on the grazing seam view.
- D1, head sweep (`van_salvage_piece1_wall.gd`): first name the face behind that edge (WallPieces faces in x 2.83..3.27, y 2.54..3.91, with their z; one report line). Then the head panel (`build_walls` :78-80 `head_outline`, solid :109-116, z `KICK_Z0` 4.9..`FRONT_Z` 5.594) and the upper post (`_upper_post` :169-212, z 5.594..`rear_in_z`) run on along z to the arch, and their arch-side top follows the ring's outer arc `_arc_pt(RING_R, a)` (r 0.685 about (`ARC_CX` 2.325, `ARC_Y` 3.225): (3.01, 3.225) to (2.325, 3.91)) at `rear_in_z` (z_deep + `SINK`, inside the ring) instead of stopping; the `ring` clip (:187-190) runs its arc over the whole quarter (`_Flange.ARC_STEPS` steps to PI/2, not 7 × 0.1 rad). Room face arc r `ARC_R` 0.505 unchanged; back on the host (`_back_x`, `inner_x_at` arc r 0.5 about (2.548, 3.5): 2.834 at y 3.91). New vertices on the seam's rows (no T-junction); `_wall.gd` 291 lines: a new function goes to a helper.
- D2, view: `salvage_seam` (`van_interior_cams.gd:47`, now (1.9, 2.0, 5.1) → (2.83, 2.3, 6.14)) to (1.2, 2.0, 4.2) → (3.0, 2.0, 5.9): about 45° to both the room face and the post's front face, the seam at 6.14 still in frame; `_add`'s `_check` passes (z > `BULKHEAD_Z` 1.0 + 0.3).
- Check: Verify list, `p3c6-*` vs `p3c5-grey*` / `p3c3-*`; seam check stays green (step ≤ 0.005, normals ≤ 10°, band clean). Reviewer: no T-junction, clockwise, −x and Portal untouched. Look-judge (grey) S2 and S4 on g02, `icam_salvage_seam`, `icam_piece_rear_left`, `icam_wall_left_rear`; before judge 4.
- Self-fix: seam check fails → that face to the measured arch value, once. Look FAIL → one fallback: the sweep carries on past the arc's top along the ring's flat top to x 2.0 (the `ring` clip's end), camera (0.9, 2.2, 3.9). Still failing → blocked.
- Rules as 3b. Specs: 2 (head sweep; view). Needs: 3b.
- Pass 3 (D58, D59): 5f095b3, ef873ad, d50002e, 8793a61 + fallback c6b6786 (flat-top tab to x 2.0, seam camera (0.9, 2.2, 3.9)); seam stays 0.002 / 0° / 0.003; judge 5 FAIL (S2 4/4, S4 3/4, g02 no); g02 `same` after the fallback; probe: g02 (288,150) WallPieces (2.83, 2.94, 5.60), (340,85) `SalvagePiece1Proof/CantRail` (2.57, 3.42, 5.71), (410,100) Portal `RampLoft` (2.48, 3.63, 6.30), so the flat field is phase 4's roof stand-in → blocked Q3.
- Notes: pass 1 c35498a (arch section, bead archived, seam check, view). Pass 2 (D55) done 7e38bbb, 25223eb, 7820a30 + normals-blend fallback: seam step 0.002, normals 0° over 77 pairs, band 0.003; hairline, shade line and ring strip gone; judge 4 S1 4/4, S2 3/4, S4 3/4 → D58. Done per D60 (Q3): seam measured clean, S4 on g02 judged again in phase 4 and 5.
### Phase 4 · Roof pieces, cove and seal clips (code; pieces 4-7, D60)

- Section (D60; constants read from `_wall.gd`/`_head.gd`): arch room face tops at y 3.73 (`ARC_Y` + `ARC_R` 0.505, level at x ≤ 2.325), ring arc `RING_R` 0.685 at 3.91; 3c's head carries both (underside 3.73, top 3.91 to `TAB_X` 2.0), z to `rear_in_z` 6.16 / `rear_out_z` 6.26.
- Deliverable 1, `van_salvage_piece1_roof.gd`, called at the end of `build_walls`, writing into its `mesh` and `hulls` (one ArrayMesh: room faces abut edge to edge):
  - Cant rail (D19): `head_outline` (rounded) clipped to y ≥ 3.47: (2.767, 3.47) (3.092, 3.47) (3.042, 3.73) (2.788, 3.73), ring arc, (2.325, 3.91) (2.0, 3.91) (2.0, 3.73) (2.325, 3.73), room arc down; z 4.2..`KICK_Z0` 4.9, abutting the head's front cap (shared vertices, no cap between); 4.2 end a flat bevelled cut.
  - Roof panel (D17): x 0..2.0, underside y 3.73 abutting the tab's x 2.0 edge (both x 2.0 faces skipped below 3.91), top `vault_y_at(x)` + 0.02; z 4.9 to `rear_in_z` below y 3.91, `rear_out_z` above; flat cut at x 0. Four underside pockets 0.255 wide, pitch 0.451 from x 0.196, z 5.50..`pocket_z1` 6.01, 0.12 deep. Edge vertices at the tab's z rows.
  - Bow (D14, D31): resume WIP `van_salvage_piece1_bow.gd` (84f6a43): top level 3.73 + `SINK`, crown level 3.47 (flush with the rail underside; `FLAT_X`, vault terms go), end arc about (2.325, 3.225) r `ARC_R` + `SINK` 0.525 (x 2.325 top, 2.789 crown); stations sorted.
  - Collision: a convex hull per piece on `Shell`, bottoms ≥ 3.47.
- Deliverable 2 (D5): `CoveR` and `RoofEdgeSeal_R` (s > 0) end at z 4.18; `build_keepouts` takes `keepout_aabbs()` from group `&"cable_keepout"`: x 2.80..3.45 × y −0.05..3.73 × z 4.88..6.3, x 2.0..3.1 × y 3.47..3.95 × z 4.18..6.3, x 0..2.0 × y 3.47..4.1 × z 4.88..6.3; no cable vertex inside (fallback +0.05). Delete the proof script and node.
- Check: Verify list (`p4-*` vs `p3c7-*`); seam check green (step ≤ 0.005, ≤ 10°, band). Reviewer: shared vertices at both joins, clockwise, `_L`/−x untouched. **Look-judge (grey): S4 on g02**: no flat dark field between head panel and arch upper corner. Fallback once: panel underside filleted into the arch with `_Seam` rows along y 3.73. Still FAIL → blocked.
- Files read: `_wall.gd:70-127,175-222`, `_head.gd`, `_bow.gd`, `van_ceiling_cove.gd`, `van_cable_router.gd`. Specs: 3. Needs: 3c.
### Phase 5 · Final look check, lamp check, baselines, docs (code+doc; piece 8, Pass test)

- Lamp (D23, D34): `RearDoorLamp` (`van.tscn:310-317`) casts no shadow (`van_junk_lamp.gd:60`) and its 70° is the half-angle (`:57`), so the bow cannot cut its light; it only lights the bow's front web 20 cm behind the can (z 4.7 vs 4.9). Check: `shot_stats p4-normal` g02 within budget. Fallback once (D23's 0.3 can move): the can forward to its anchor z 4.4 (`transform` z only; anchor, aim, energy unchanged); still over → `Status: blocked`.
- **Final look check (look-judge): statements 1, 2, 3, 4** on the four views plus `icam_salvage_seam`, before p1 / after p5 sets (D11); pictures to the owner. Tuning fallback once: pocket depth 0.12 → 0.15 (bevel stays 0.03, D41).
- `shots.py` TOLERANCE: re-measure every region view (two captures of each set, `compare --raw`, double), adding rows for the three icam ones, each with a dated comment.
- `py -3 tools/scene_dump.py --bless` (the van tree gained `SalvagePiece1`, lost nothing; said in the report); the smoke fingerprint stays unchanged: no `smoke.py --bless`.
- Docs: `.claude/rules/van-geometry.md` paragraph "Salvage piece 1" (the node, the +x clips at z 4.88/4.18, the `cable_keepout` group, the 2 cm sink and ring-depth rules); `docs/glossary.md` lines: corner post / D-pillar, kick box, head panel, cant rail, roof bow, salvage piece; `gen_context.py`.
- Verification: the Verify list (fingerprint unchanged; `scene_dump.py` prints `BASELINE WRITTEN`; `p5-*`; every view `same` unless the lamp fallback fired, then region views only). Reviewer: none.
- Files read: `tools/shots.py:36-95`, `scenes/van/van.tscn:300-320`. Specs: 2 (tolerances + bless; docs). Needs: 4.
## Carry forward

- Phase 1: the rear-right ceiling is unlit from the bulkhead in both normal and flat grey (`icam_ceiling_rear` normal-vs-grey diff only 1.055); the Pass test needs the roof pieces visible there. The only lamp in scope is phase 5's `RearDoorLamp` fallback.
- Phase 1: full `p1-grey` repeats differ on up to 7 non-region views (elevator/rear-park stops, v04-v06, a19, f01; diffs up to 3x tol); region views (g02, `*-back`, icam) repeat `same`.
- The rest of the Brief: the x<0 wall, the ceiling forward of z 4.2, the window surrounds, then textures; `van_salvage_piece1*.gd` is the pattern.
