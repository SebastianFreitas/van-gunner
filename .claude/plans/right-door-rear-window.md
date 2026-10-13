# right-door-rear-window

Stage: done
Started: 2026-10-12
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: full (D1)
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A, B, C done · build reviews 2 applied · 9 asked · missed: gasket inward cover vs glass gap (D12); rubber specular (D13); gasket lit response under the warm cabin lamp (D14); glass rim past the 0.05 lip (D15)
Questions: auto

## Brief (owner's words, verbatim)

Make the rear window on the right rear door (right as seen from inside the van, the yellow one) look like a window salvaged from a completely different vehicle than the left one. Its shape already differs, and the glass and iron bars can stay the same as the left window's. Everything else must change: the frame shader, the inside of the hole (the reveal faces) and the other details that are still built and shaded like the left window. Use the new window view commands to check both windows before and after.

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- Draft (asked): from `wcam_rear_right` and `wcam_rear_right_out` beside `wcam_rear_left[_out]`, a viewer says the right window came from a different vehicle: its frame, the inside of its hole and its fittings share no shape or finish with the left window's; the glass and iron bars match.
- Judged on: `py -3 tools/smoke.py --shots <scratchpad>/wcam --views wcam`, views `wcam_rear_right`, `wcam_rear_right_out` (changed) and `wcam_rear_left`, `wcam_rear_left_out` (unchanged), before and after.

## Scope

- In: the donor (x<0) leaf's window: its frame, the hole's reveal faces, the window lip and the street-face flange/swage round the hole, their shading.
- Out (stays exactly as is): the donor window's shape (`RearDoorProfile._donor_window`), the glass, the iron bars (`IronCross`), the stock (x>0) leaf's whole window, the rest of the donor leaf's dressing.

## Current state (explored 2026-10-12; anchors drift, grep the names)

- Naming: the owner's "right / yellow" rear door is the code's left leaf, `LeftHinge`, x<0, built from `RearDoorProfile.donor()` (map "Owner's words"). Its window camera is `rear_right` (`van_window_cams.gd:44`, tag "right" for side<0).
- `rear_door_leaf_build.gd:38` `build`: both leaves' bodies come from one `_Skin.build` (`:80`) with one `van_rear_door.gdshader` material (`_door_body_material` `:115`; the donor only gets other paint/rust params). Both get the same `WindowLip` (`:45-46`, `rear_window_lip.gd:25`, material = handle mount steel `:173`).
- `_fit_donor_window` (`:134`): hides the donor's `WindowFrame`, resizes `WindowGlass` to the hole box minus 0.10, refits `IronCross` (frame_half box+0.05, skin_reach, no gussets).
- `rear_door_skin.gd:45-52`: the reveal is `_walls` (a tunnel through the slab from the recessed panel level), then the skeleton `_flange` rolled lip (`:52`); the cabin face round the hole is a pressed flank (`rear_door_skeleton.gd:66-71`, `_Press.sweep(win, WIN_SLOPE, z_cab)`, 0.04 wide, 0.08 deep). The swage call (`:53`) builds no window ring on the donor (`rear_door_swage.gd:39`, `wide_street_bead()`), only its leaf-wide street bead, which stays (from review-build 1). `_filler` differs for the donor.
- `rear_door_lighting.gd:9` and `rear_door_portal.gd:246` handle `WindowFrame`/`WindowGlass` by name.
- Window views: `py -3 tools/smoke.py --shots <dir> --views wcam` writes `wcam_<name>.png` and `wcam_<name>_out.png` for 8 cameras (`smoke_shots_wcam.gd`, `.claude/rules/tooling-shots.md:31`, `van-geometry.md:54`).
- Rules a spec reads: `van-geometry.md` (audit must stay clean; invariant 16: hole sizes live in `VanOpenings`), `art-style.md`, `art-3d.md`, `art-shots.md`.
- No earlier `missed:` line bears on this Brief (vanfix D18/D41/D53 on window reveals and frame rows are audit rules already in `van-geometry.md`).

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- D10 Wet rubber: bone dry, fully matte, no sheen; roughness kept in the art range (owner) -> phase 2.
- D11 Cabin press: flatten the pressed recess round this window only so the rubber sits flush; the rest of the door's pressing stays (owner) -> phase 1.
- D12 (auto) Gasket inward cover stays 0.05: the 0.03 fallback opened a 0.02 m see-through gap to the glass edge, and the bars sit cleanly on the rubber (look-judge) -> phase 1.
- D13 (auto) Stand-in rubber albedo 0.03, no specular: the bead's inward slope caught street-light specular and read as a steel band (look-judge round 1 FAIL) -> phase 1; phase 2's shader keeps specular near zero.
- D14 Gasket still brown with a pale inner band after phase 2: investigate whether the band is the gasket, glass edge or hole wall, then cool/darken the rubber's lit response to the interior light until it reads near-black; phase 2 retries (owner) -> phase 2.
- D15 (auto) The pale band was the glass rim showing past the lip, not the gasket; INWARD widened 0.05 -> 0.08 (0.065 still showed it), glass untouched -> phase 2.

## Initial idea (full path, Part B; prose, beginning to end, as the owner experiences it)

Standing in the van looking at the yellow rear door, its window no longer reads as a twin of the left one: the hole keeps its own donor shape, the same glass and the same welded iron bars (D2), but there is no steel frame round it (D4). A fat ring of worn black rubber, like an old bus or VW T2 window, wraps the hole edge and holds the glass (D4). The pressed rolled lip, the swage line and the steel window lip the left window has are gone from this one, and the gasket covers the hole's edge so no steel tunnel face shows (D5). From outside (`wcam_rear_right_out`) the same rubber ring sits on the street face. The left window looks exactly as before (Scope). Nothing moves or is heard; this is a look change only.

### Piece 1 · Rubber gasket ring
A fat black rubber ring follows the donor hole's own outline on both the cabin face and the street face (one H-section that clamps the door skin, like a T2; D8). Rubber is worn, matte, slightly grey and grimy in the road's shader recipe, never glossy (D9). The glass sits in the ring's groove; the bars stay where they are (D2).

### Piece 2 · Bare hole, no left-style fittings
On this window the steel `WindowLip`, the rolled lip (`_flange`) and the swage round the hole are removed, and the reveal tunnel is hidden under the gasket (D5). The rest of the donor leaf's dressing stays (Scope).

### Piece 3 · Check
Before and after shots of `wcam_rear_right[_out]` change; `wcam_rear_left[_out]` stay the same; look-judge applies the Pass test (D3, D6).

## Walk-through (one line: the pieces were shown together)

- Pieces 1-3 · That is it; bars and glass ignored, untouched · D7

## Constraints (every phase)

- Only the donor (code `LeftHinge`, x<0, owner's right/yellow) window changes; the stock leaf, the donor hole shape (`RearDoorProfile._donor_window`), `WindowGlass` and `IronCross` are never touched (D2, D7).
- Invariant 16: hole sizes stay in `VanOpenings`/`RearDoorProfile`; the van audit stays clean (if `tools/smoke/PAUSED` exists, it is paused; never make it pass otherwise). An audit row about the donor window that the removed lip/flange break is fixed in the audit's own check for the donor, never by putting steel back (memory: plans self-fix audit rows).
- Look: dark, light only from sources; rubber in the road's procedural grime recipe (`art-style.md`, `art-3d.md`). Specs read `van-geometry.md`, `art-style.md`, `art-3d.md`, `art-shots.md`.
- Every phase: `py -3 tools/check.py`, `py -3 tools/smoke.py`, `py -3 tools/scene_dump.py`, and `py -3 tools/smoke.py --shots <scratchpad>/wcam --views wcam` before and after (D3); `tools/shots.py compare` shows `wcam_rear_left`, `wcam_rear_left_out` unchanged, `wcam_rear_right[_out]` changed. Fingerprint `--bless` only for the donor window change, said in the report.
- Pass test statements: (1) right window frame shares no shape/finish with the left; (2) no steel hole tunnel, rolled lip or pressed ring round the hole is visible on the right (the leaf-wide street bead stays); (3) glass and bars match the left (D6).
- `WindowGasket` is lit like the glass: added to `rear_door_lighting.gd:9` parts list (layer street+interior), set before `add_child` (from review-build 3, `van-render-layers.md`).

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Look proof: strip fittings, crude gasket | code | - | Brief | done c1c46cb |
| 2 | Rubber finish and final look | code | 1 | Brief | done fb21e67 |

Needs: earlier phases whose output it builds on. Rests on: decisions still in the list, or Brief. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · Look proof: strip fittings, crude gasket
Research: `rear_door_skin.gd` build (window `_walls`, `_flange`), `rear_door_skeleton.gd:66-71` (window press), `rear_door_leaf_build.gd` `build`/`_fit_donor_window`; go past the list only for the audit rows.
Deliverable: (a) Donor only (`profile.is_donor()`): skip `skeleton._flange`, the window's cut in `cuts` uses offset 0 (`win` itself, not `_skin._ring(win, WIN_SLOPE)`) and its `_Press.sweep` is skipped, so the cabin face is cut flush at `win` with no open ring, and the tunnel `_walls` starts at `z_cab`; `profile.cabin_openings(rect, win, WIN_SLOPE)` keeps `WIN_SLOPE` so bay spacing is unchanged (from review-build-2 1) (D11; the rest of the door's pressing stays), skip `_WindowLip.build(...)` (D5). Keep the swage call (street bead, Current state). (b) New `scripts/van/rear_window_gasket.gd` (`RefCounted`, static `build(left, donor)`) from `_fit_donor_window`: a closed H-section rubber ring on the donor outline, mesh `WindowGasket` under `LeftHinge`, layers per Constraints. Section per face (cabin at `z_cab`, street at `z_street`): 0.05 m inward over the hole edge (glass inset 0.10/2, so the glass edge sits in the groove), 0.04 m outward onto the skin, a rounded bead (3 segments) 0.03 m proud at the crown, 0.015 m at the skin edge (art-3d chunky rule; from review-art 4). Web runs unbroken face to face, its inner face 0.015 m inside the outline (as `SLEEVE_OFFSET`, no FLICKER with `_walls`); every edge walled, no open edges (from review-build 4). Outline offset with corner-averaged normals; no UVs needed (phase 2 is model-space). Stand-in StandardMaterial3D albedo 0.06, roughness 0.95, metallic 0. Check: wcam pairs as Constraints; bars clear (`IronCross` clear_half inside the 0.05 lip); else inward cover 0.03. A new audit row from the press removal is fixed per Constraints.
Files: `rear_door_skin.gd`, `rear_door_skeleton.gd`, `rear_door_leaf_build.gd`, `rear_door_lighting.gd`, new `rear_window_gasket.gd`; reads `rear_door_profile.gd`, `rear_window_lip.gd`.
Verification: implementer runs Constraints commands; look-judge on `wcam_rear_right`, `wcam_rear_right_out` beside `wcam_rear_left[_out]`, Pass test statements 1-3 (finish judged on shape only, rubber grime is phase 2); FAIL stops the run; pictures go to the owner.
Reviewed: phases question answered, D10-D11
Notes: done c1c46cb; judge PASS round 2 after D12, D13; street outline still near the old lip's, phase 2 finish must sell rubber from outside.

### 2 · Rubber finish and final look
Research: `scenes/van/van_floor_mat.gdshader` (colour only), `scenes/shaders/grime.gdshaderinc`, `facade_prop_grime.gdshader` (model-space VERTEX varying), `art-3d.md` recipe (from review-art 1).
Deliverable: new `scenes/van/van_gasket.gdshader` (`render_mode diffuse_burley, specular_schlick_ggx`) including `grime.gdshaderinc`, model-space VERTEX varying as `facade_prop_grime.gdshader`; `van_floor_mat.gdshader` is a colour reference only (it is UV-driven; from review-build-2 2). Worn grey-black (base 0.05-0.07), grime laid out in model-space metres, pitches under 0.25 m faded with `fwidth`, slight greying on outward edges. Bone dry both faces, fully matte: roughness 0.95, default specular, no wet sheen (D10, D9). Hook it in `rear_window_gasket.gd`. Check: `wcam_rear_right` gasket darker than the yellow paint, no highlight.
Files: `rear_window_gasket.gd`, new `scenes/van/van_gasket.gdshader`.
Verification: Constraints commands; last look check: look-judge on the four wcam rear views, Pass test statements 1-3 all; pictures to the owner; FAIL stops the run.
Reviewed: phases question answered, D10-D11
Notes: done 3b925dc, 9720993, 09ccc62 (own cool matte light(), light_desat 0.85, light_scale 0.38), fb21e67 (INWARD 0.08, D15); judge FAIL twice then PASS round 3 (st.1-3); judge note: inside rubber a little smooth and bluish.

## Carry forward

- The donor gasket node is `LeftHinge/WindowGasket`, built by `rear_window_gasket.gd`.
- Gasket section constants (INWARD 0.05, OUTWARD 0.04, bead 0.03/0.015) and the stand-in material live at the top of `rear_window_gasket.gd`; phase 2 swaps the material only.
- `wcam_rear_right_out` shows the donor leaf (one implementer misread it).
