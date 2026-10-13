# rear-window-seal

Stage: done
Started: 2026-10-13
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/rear-window-seal.state.md` while running).
Path: full   <- or light: one area, no new user-facing design (interview.md "Light path")
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: C done · 9 asked · ready-gate reviews applied · build review round 2 applied · missed: is a 1.5 cm ring readable from the cabin at g02 distance, and is a 1 cm corner swell visible at shot resolution? (answered D19: g02 dropped, swell 3.5 cm)   <- A/B/C open or done, running total; missed: lines while running
Questions: auto

## Brief (owner's words, verbatim)

this is not really what i wanted, can you make a plan to fix this? it looks like dumb rubber all around doesnt looks like a real window at all, you need something else or to changes this radically i guet the rubber on the corners, but it woudlnt be so big . and the center of the hole rubber as well? dont think so, its actually only agaisnt the glass, so it would be only on the outside? rehtink this make a plan

(Context: follows plan `right-door-rear-window` (done), which replaced the right rear door's donor window steel lip with a full H-section rubber gasket `WindowGasket`, inward lip 0.08 m, cool matte shader `van_gasket.gdshader`.)

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- Draft (asked): from `wcam_rear_right` and `wcam_rear_right_out`, a viewer says it looks like a real van window: the rubber/seal is a thin line against the glass, mostly on the street side, at most a little fuller at the corners; no rubber fills the hole wall or covers a band of the cabin face; the cabin side shows the door's steel edge.
- Judged on: `py -3 tools/smoke.py --shots <scratchpad>/wcam --views wcam`, views `wcam_rear_right`, `wcam_rear_right_out` (changed), `wcam_rear_left`, `wcam_rear_left_out` (unchanged), before and after.

## Scope

- In: the donor (code `LeftHinge`, x<0, owner's right/yellow) window's seal (`rear_window_gasket.gd`, `van_gasket.gdshader`), its hole wall and cabin edge (`rear_door_skin.gd` donor branch, `rear_door_skeleton.gd` donor press round the window), and the donor glass placement in `_fit_donor_window` if Q1 picks bonded.
- In (D21): a new donor-only hole-wall tag in `van_rear_door.gdshader`; existing tags unchanged.
- Out (stays exactly as is): the donor hole shape, the glass material, `IronCross` bars, the stock (x>0) leaf's whole window, the rest of the donor leaf.

## Current state (explored 2026-10-13; anchors drift, grep the names)

- Naming: owner's right/yellow door = code left leaf `LeftHinge`, x<0, `RearDoorProfile.donor()`; window camera `rear_right` (from right-door-rear-window).
- `rear_window_gasket.gd`: `INWARD` 0.08 (:10), `OUTWARD` 0.04 (:12), `FRONT` bead profile (:21-22); `build` (:26) sweeps `_section` (:81-95), an H that runs from z_cab to z_street at -INWARD..+OUTWARD round the hole, so the whole hole wall and an 8 cm cabin band are rubber; `_material` (:113).
- `van_gasket.gdshader`: near-black matte (base 0.038 :11), own cool `light()` (:49), `light_scale` 0.38 (:17) (D13-D15 of the old plan).
- `rear_door_leaf_build.gd`: `build` (:39) gives the donor no steel `WindowLip` (:46-47); `_fit_donor_window` (:135) hides `WindowFrame`, sizes `WindowGlass` to the hole minus 0.10, refits `IronCross`, then `_Gasket.build` (:150).
- `rear_door_skin.gd:46-56`: the donor hole tunnel starts flush at z_cab (:47, no panel drop; the old plan's D11 flattened its press), no rolled `_flange` (:50-55, stock only); the swage ring is stock only.
- `rear_door_skeleton.gd:17` `WIN_SLOPE` 0.04 cabin press round the window (stock keeps it; donor flattened).
- Left (stock) window for comparison: steel `WindowLip` (`rear_window_lip.gd`), recessed tunnel from `PANEL_DROP`, rolled street lip `_flange`, swage ring, its `WindowFrame`.
- `rear_door_lighting.gd:9` lists `WindowGasket` among lit parts.
- Earlier `missed:` lines: none bear on this Brief.

## Open items

none

Reviews: build review round 2 (2026-10-13) applied: phase 2 own before set, D15 cap 0.08, slit check as look-judge statement; no leftovers.

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- **D1 · Glazing.** Thin outside gasket: a 1-1.5 cm black rubber lip around the glass on the street side (old VW T2 / Bedford style); the hole wall is plain steel (owner).
- **D2 · Cabin edge.** Small pressed return: a little lip pressed into the inner steel round the hole, different from the left door's; no rubber on the cabin face (owner).
- **D3 · Corners.** The thin lip swells slightly at each corner, like a moulded gasket (owner).
- **D5 · Walk-through.** Three pieces accepted as shown (owner).
- **D6 · Corner swell.** About 2.5 cm wide at each corner (owner).
- **D7 · Cabin press.** The pressed step is 1 cm deep (owner).
- **D8 · Glass depth.** Glass seated in the ring's groove at the skin plane (from D1's VW T2 precedent, research file).
- **D4 · Pass test.** Drafted wording accepted as written; left window views stay the same (owner).
- **D10 · Phases.** Both phases right as shown (owner).
- **D12 · Thin vs 3 cm rule.** Keep the 1.5 cm ring and 1 cm step; phase 2 writes a named exception into `.claude/rules/art-3d.md` "Chunky, not fine"; look checks also judge `g02-gap-rear-in-whole` (rear doors from 4 m at eye height, full `--shots` set) (owner).
- **D13 · Glass shape.** Donor glass is the hole outline `_Skin._ring(window_hole, -0.004)` extruded 0.016 as an ArrayMesh on `WindowGlass` (z 0.030, front 0.038): edge 6 mm under the 1 cm ring, never inside the 2 cm skin plate (z 0.02..0.04), so no audit FLICKER; `BreakableGlass` only hides the node (from build review, `rear_door_profile.gd:204`, `van_audit_flicker.gd:8`).
- **D14 · Corner weight.** All 22 hole vertices lie on corner arcs (`rear_door_profile.gd:221-223`), so per arc with n steps, vertex k: w = sin(pi k / n); width 1.5 + 1.0 w cm, crown 0.4 + 0.2 w cm (from build review, D6).
- **D15 · Distance tuning.** If the ring does not read in `g02-gap-rear-in-whole`, the one tuning try raises `van_gasket.gdshader` base albedo 0.038 to at most 0.08 so the rubber stays black (D1); recorded D (auto) (from art review; cap from build review 2).
- **D17 · Lip profile (auto).** The lip became a wedge (belly sunk 5 mm, skin edge and glass tip at height 0, crown 0.4 cm, no vertical walls) because a walled bead gave audit FLICKER=2 against the glass and CurvedBody (implementer, phase 1).
- **D18 · D15 applied (auto).** Gasket base albedo 0.038 -> 0.08 (the cap); the judge still FAILed (b) and (e), so phase 1 stopped as blocked.
- **D19 · Ring after phase 1 (owner, 2026-10-13).** Keep the thin street ring as built (D17 wedge, D18 albedo 0.08). Drop "the ring reads as a line in `g02-gap-rear-in-whole`" from phase 1's look check: from the cabin a 1.5 cm street-side lip behind glass is meant to be near-invisible. Grow the corner swell to 3.5 cm total width (from 2.5 cm) so "a little fuller at the corners" shows in `wcam_rear_right_out`; the rest of phase 1's look check stands. Re-run phase 1 with only this change.
- **D20 · Corners accepted (owner, 2026-10-13).** A real moulded gasket's corner swell is subtle: keep the ring as built (3.5 cm corners, aa21c78) and drop "fuller at the corners" (b) from phase 1's look check. With (a), (c) and (d) passing and checks clean, phase 1 is done; run phase 2 as written.
- **D21 · Cabin edge look (owner, 2026-10-13).** Keep the 1 cm step (D7) as built in 5adde3c. Give the donor hole wall and step their own worn-steel look: a new donor-only wall tag in `van_rear_door.gdshader` (dark painted steel like the leaf, edge wear on the lip, wear running along the wall rather than stretched radially), so it reads neither as clean rust nor as a bright yellow band. Scope widens to `van_rear_door.gdshader` for this tag only; the stock leaf and every existing tag must look unchanged (left views ≤ tol). Re-judge phase 2's (e) and (f).
- **D22 · Cabin edge accepted (owner, 2026-10-13).** Keep adaaf6a as built (TAG_DONOR_WALL 6, dark wall, no bright band). A 1 cm step can't show in this lighting: drop "reads as worn steel / step visible" from (e). Phase 2 is done and the plan closes.
- **D16 · Steel tags.** The bared donor hole wall is tagged `TAG_EDGE` like the stock tunnel (`rear_door_skin.gd:42`), the step keeps `_Press` crest/valley tags; the look check judges "no bright or clean band" (from art review).
- **D11 · Press depth.** `_Press.sweep` always presses `DEPTH` 0.08 (`rear_door_press.gd:10,60`); its `width` arg is only the flank width, so phase 2 adds a depth argument (from `rear_door_press.gd`, D7).
- (D1-D16 folded into the phases and Constraints.)

## Initial idea (full path, Part B; prose, beginning to end, as the owner experiences it)

Seen from the street (`wcam_rear_right_out`) and the cabin (`wcam_rear_right`), the owner's right (yellow, donor) rear door's window reads like a real old van window. Three pieces:

### Piece 1 · Thin street-side rubber
Only on the street face: a black rubber ring about 1.5 cm wide grips the glass edge and the steel hole edge, a low rounded bead (D1, Brief "only against the glass ... only on the outside"). Working: today the lip reaches 8 cm in (`INWARD` 0.08, rear_window_gasket.gd:10) and 4 cm out (`OUTWARD` :12); new visible ring = 1.0 cm over the glass + 0.5 cm onto the skin = 1.5 cm (D1's top value). It keeps the cool matte shader (`van_gasket.gdshader`, unchanged). No rubber on the hole wall or the cabin face (D1, D2): the web and cabin flange in `_section` (:81-95) go.

### Piece 2 · Glass that reaches the rubber
Today the glass is a box, the hole bounds minus 5 cm a side (`- 0.10`, rear_door_leaf_build.gd:140), so a 1 cm lip would leave a see-through gap. The glass takes the hole's own outline inset 4 mm, its edge tucked 6 mm under the ring, seated at the skin plane (D8, D13). Bars and hole shape stay (Scope Out).

### Piece 3 · Steel edge and small press from the cabin
From inside, the hole wall is plain steel (D1) and a small pressed return rings the hole, not the left door's (D2): a 1 cm step pressed 1 cm into the inner skin round the hole, a quarter of the stock's `WIN_SLOPE` 0.04 (rear_door_skeleton.gd:17) so it stays "different". (D7: 1 cm deep)

### Corners (in Piece 1)
At each rounded corner the ring swells to about 2.5 cm wide and a little prouder, like a moulded gasket (D3) (D6: about 2.5 cm, peaking mid-arc, D14).

## Walk-through (one line: the pieces were shown together)

- Pieces 1-3 · That is it · D5

## Constraints (every phase)

- Only the donor (code `LeftHinge`, x<0, owner's right/yellow) window changes; the stock (x>0) leaf, the donor hole shape, glass material, `IronCross` and the rest of the donor leaf stay (Scope). Views `wcam_rear_left`, `wcam_rear_left_out` must compare unchanged.
- No rubber on the hole wall or the cabin face: the hole wall is plain steel, rubber only on the street face (D1).
- Rubber keeps `van_gasket.gdshader` unchanged (cool matte, old plan's D13-D15), except D15's one tuning try. Art: `.claude/rules/art-style.md`, the van's `art-*.md`, `art-shots.md`; Read first in every spec.
- Archive, don't delete: before phase 1 changes it, tag the current H gasket `archive/donor-h-gasket` (owner's archive rule; D9 from memory "Archive removed art").
- Verify per CLAUDE.md: `py -3 tools/check.py`, `py -3 tools/smoke.py`, `py -3 tools/scene_dump.py` (van scenes), shots `py -3 tools/smoke.py --shots <scratchpad>/wcam --views wcam`; implementer runs them; a `--bless` only for the intended donor-window fingerprint/tree change, said in the report. If `tools/smoke/PAUSED` exists, baselines are not touched.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | thin street ring + glass (look proof) | code | - | D1, D3, D6, D8, D13-D15, D19, D20 | done aa21c78 (dbbb13d, 7980e50; D20 accepted) |
| 2 | cabin pressed return (last look check) | code | 1 | D2, D7, D11, D12, D16, D21 | done adaaf6a (5adde3c; D22 accepted) |

## Phases

### 1 · thin street ring + glass (look proof)
Deliverable: first, before any edit, `git tag archive/donor-h-gasket HEAD` (D9) and shoot the "before" sets `py -3 tools/smoke.py --shots <scratchpad>/before` and `--shots <scratchpad>/wcam_before --views wcam`. `rear_window_gasket.gd` builds a street-only ring, no web, no cabin flange (D1): `_section` keeps only the street bead, back sunk `SINK` 0.005 into the skin. Width = 1.0 cm over the glass (`INWARD` 0.08 -> 0.010) + 0.5 cm onto the skin (`OUTWARD` 0.04 -> 0.005) = 1.5 cm. Crown keeps the old ratio 0.030/0.12 = 1/4 (`FRONT` :21-22): 0.4 cm. Corners (D14): on each corner arc of n steps, vertex k gets w = sin(pi k/n); width 1.5 + 1.0 w cm (offsets scaled), crown 0.4 + 0.2 w cm; arc ends stay 1.5 cm. Glass (`_fit_donor_window`, D13): replace the BoxMesh with an ArrayMesh of `_Skin._ring(window_hole, -0.004)` extruded 0.016 (same glass material), node z 0.030 (front 0.038, 0.2 cm behind z_street 0.04; plate 0.02..0.04 is never entered): edge 6 mm under the ring. Check: van audit clean (no FLICKER); the slit check is a look-judge statement (Verification). Files: `scripts/van/rear_window_gasket.gd`, `scripts/van/rear_door_leaf_build.gd`.
Verification: implementer runs check, smoke, scene_dump, `--shots <scratchpad>/after` and the wcam shots; `tools/shots.py compare` of `wcam_before` vs the new wcam set shows `wcam_rear_left*` unchanged (tol 1.0). Look-judge on `wcam_rear_right`, `wcam_rear_right_out`, `g02-gap-rear-in-whole`: rubber is a thin line against the glass on the street side, a little fuller at the corners, no rubber in the hole wall or on the cabin face, no see-through slit between ring and glass in `wcam_rear_right_out`; in `g02` the ring still reads as a line (else D15). Cabin steel edge not judged yet (phase 2). FAIL after one tuning try stops the run.
Reviewed: Right (D10)
Notes: built dbbb13d (ring+glass, wedge D17) and 7980e50 (D15 albedo 0.08); checks clean, left views unchanged; judge FAIL twice on corner swell (b) and g02 readability (e); blocked. Re-run after D19: aa21c78 (CORNER_WIDTH 0.020, 3.5 cm corners), checks clean, judge (a)(c)(d) PASS, (b) FAIL again (corners look as thin as the sides; wcam2 vs new diff only 0.007/0.011); blocked.

### 2 · cabin pressed return (last look check)
Deliverable: first, before any edit, shoot this session's own `py -3 tools/smoke.py --shots <scratchpad>/wcam_before --views wcam` (phase 1's after state; a scratchpad is per session). From the cabin the hole wall is plain steel and a small pressed return rings the hole, unlike the stock leaf's (D2): a 1 cm step pressed 1 cm into the inner skin (D7), a quarter of the stock `WIN_SLOPE` 0.04 (`rear_door_skeleton.gd:17`). `_Press.sweep`/`profile` press a fixed `DEPTH` 0.08 (`rear_door_press.gd:10,60`; `width` is only the flank width), so add an optional `depth: float = DEPTH` to both (stock calls unchanged) (D11). In `rear_door_skeleton.gd` the donor branch (:66-75, today flush, no ring) cuts `_Skin._ring(opening, 0.01)` and calls `sweep(..., 0.01, z_cab, 0.01)`: 1 cm flank, 1 cm deep; in `rear_door_skin.gd:47` the donor `z_tunnel` starts at z_cab + 0.01 so the tunnel meets the pressed step (no slit; was z_cab). No rolled `_flange` and no swage ring (those stay stock-only, to read as a different vehicle). The bared donor hole wall is tagged `TAG_EDGE` like the stock tunnel, the step keeps `_Press` crest/valley tags (D16). Update the comments at skin.gd:46 and skeleton.gd:66 that say the rubber hides the edge. Add to `.claude/rules/art-3d.md` "Chunky, not fine": exception, donor rear window seal 1.5 cm ring / 1 cm press step (owner 2026-10-13, D12). Check: van audit clean and `scene_dump` diff only the donor window nodes; if the step opens a slit against the tunnel, sink the tunnel start to match the measured step, record D (auto). Files: `scripts/van/rear_door_skeleton.gd`, `scripts/van/rear_door_skin.gd`, `scripts/van/rear_door_press.gd` (depth arg only), `.claude/rules/art-3d.md`.
Verification: implementer runs check, smoke, scene_dump, full and wcam shots; compare against this phase's own `wcam_before`: left views unchanged. Look-judge on `wcam_rear_right`, `wcam_rear_right_out`, `wcam_rear_left`, `wcam_rear_left_out`, `g02-gap-rear-in-whole`: every Pass test statement (thin street-side line, fuller corners, no rubber in the hole or on the cabin face, cabin side shows the door's steel edge with a 1 cm pressed step that reads as worn steel like the rest of the leaf with no bright or clean band, ring still a line in `g02`, left windows unchanged). Pictures to the owner. FAIL after one tuning try stops the run.
Reviewed: Right (D10)
Notes: built 5adde3c (step 1 cm flank/1 cm deep via `_Press` depth arg, tunnel from z_cab+0.01, wall TAG_EDGE); checks clean, scene_dump identical, left views unchanged (0.005/0.006). Judge (a)(c)(f) PASS, (e) FAIL: step invisible, wall a clean brown band. Tuning try (wall TAG_CABIN) made a bright orange band, still FAIL; reverted; blocked.

## Carry forward

- Archive tag `archive/donor-h-gasket`; ring 1.5 cm / corners 2.5 cm; glass = hole outline inset 0.004 at z 0.030; each phase shoots its own `wcam_before` in its own scratchpad before any edit.
- Phase 1 shots and judge reports: `C:/Users/Traff/AppData/Local/Temp/rws-p1/` (before, wcam_before, after, wcam, after2, wcam2, judge.md).

- Phase 2 shots and judge: `C:/Users/Traff/AppData/Local/Temp/rws-p2/` (wcam_before, wcam, full = committed build; wcam2, full2 = reverted TAG_CABIN try; judge.md).
