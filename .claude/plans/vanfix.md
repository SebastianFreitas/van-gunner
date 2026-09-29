# vanfix

Stage: running
Questions: auto (owner, 2026-09-29: D46)
Started: 2026-09-28
Procedure: `.claude/skills/plan/SKILL.md` (the interview, then "go"; state in `.claude/plans/vanfix.state.md` while running).
Interview: done under the old procedure (no parts A/B/C); missed: thin PC rig props vs the audit tolerance (D49); missed: how the audit treats animated machine parts (D48); missed: cable/lamp fix scope (D35 auto); generator vent route (D36 auto); audit tool layout and method (D11 auto); gap size where 1 cm meets the audit's 1 cm coplanar tolerance (D12 auto); side door slide clearance through the wall (D13); door front edge vs cab wall (D14); street lighting on door and window parts (D15); window hinge pivot position (D16 auto); side skin layering against the wall (D17 auto); who owns the opening reveals and whether the buried casings go (D18 auto); side door slide path vs the belt line and rub rail (D19); whether the front audit calls for replacing the cab (D21 auto); front wheels moved out to clear the cab skin (D22 auto); audit speed-up, front windows posed apart from their doors and cross-mesh EDGE seams (D23 auto); roof height cap (D24), antennas (D25), rear roof (D26); roof place-or-drop grouping (D27 auto); flare and spare solids (D28 auto); arch trims, chain segments, exhaust and sill breaks (D29 auto); add-ons in the side door slide path (D30); low side armour vs the door path and chassis items (D32); side armour bands and plate lean (D33 auto); low chassis add-ons embedded (D34 auto); bulkhead grille and rib weld offsets (D37 auto); door frames vs the skin at the D13 recess (D38); props standing in a side door bay (D39); cable trunks across door bays (D40); window frame rows in the OPENING check (D41 auto); floor decal lift height (D42 auto); inner shell plates and patches vs ribs (D43 auto); bulkhead, hanger, ramp and flare depths (D44 auto); bulkhead post and kick plate joints (D45); missed: how sliver pairs count toward a row's visible area (D51 auto); missed: how to seal the side window frame-to-cut slot (D53 auto, owner-delegated)

## Rebase note (2026-09-28, landed on main)

This plan was written in a worktree cut from main at 1554975, before
van-exterior-2 phases 2 to 7 landed (c4711c6 .. c970044). Main now has the
audit (`research/van-exterior-2-01-audit.md`), the seam patches
(`van_hull_patches.gd`), the side-window exterior panes and casings, the
real cab-over cab (`van_cab*.gd`), the chassis kit (`van_chassis.gd`) and
the night read. So:

- **Current state** and **First look** below describe the old van: phase 1
  re-surveys the code on main and re-takes the shots before trusting them.
- **D1** is overtaken: van-exterior-2 finished (Stage: done), nothing is
  parked from it.
- **D5 is reopened**: phase 4 seals the existing real cab (gaps, joins to
  the body) instead of replacing it with a simple block; ask the owner at
  phase 4's start if the audit says otherwise.
- The owner's pictures 1 to 3 (side door from inside, window sawtooth)
  were taken of main's van and still stand.

## Brief (owner's words, verbatim)

> we need to fix the van once again dude
> from the outside 90% of the assets are not properlly connected
> the side doors, form the inside have some asset flcikering on top of eahc other probably
> also theres still artifacts coming out of the van, specially on the backpart, form the ouside you see weird vertical walls going above the van.
>
> for this place i wanan focus on these things specifically, right now, it doesnt matter if the textures are amazing, or whaetver, it looks horrible because of these 2 main issues, the assets arent connected you can see inside from literally every angle, and theres asset cliping, i have specially noticed on the window, the corners, very noticable after you open the window, and the side door on the inside. make a plan to review everything about the van for this specific problems and solve them
> if you want, before you start making the plan and ask me questions, i could send you tons of pictures

## Scope

- In: the van's geometry only: `scenes/van/van_shell.tscn` and its builders in `scripts/van/` (side walls, side doors and `side_door_leaf.gd`, side windows, rear doors, front wall, ceiling, pillars, rails), `scripts/van/look/` (hull, hull lines, cab, front kit, armour, markings, marker lights, wheels, roof, roof junk, rear dressing), a new geometry audit under `tools/`, new close-up views in `tools/smoke/smoke_shots.gd`, `.claude/rules/van-shell-and-hud.md`.
- Out (stays exactly as is): textures and shader looks (the brief: "it doesnt matter if the textures are amazing"); DoorSpill, RearCone, ExteriorLight and the `*-outside` budget; door and window gameplay (breach, smash HP, weld, gun ports), breach points and walk space; interior machines and cables unless the audit names one; the detailed real cab (D5).

## Current state (explored 2026-09-28; anchors drift, grep the names)

- `van_shell.tscn` `Shell`: SideWalls (`VanSideWall`), Ceiling (vault), Floor, SideWindows (4: hinge + frame + glass + iron + breakable), SideDoors (CSG-style Panel parts Body/OuterSkin/Inset/BeltLine/LowerCrease), SidePillars (6 hard-coded 0.18 × 3.05 × 0.5 m posts), Rails (4 bowed edges).
- `VanBodyProfile`: `inner_x_at`, `outer_x_at` (+0.12 wall), `roof_y_at`, `outer_roof_y_at` (+0.14 roof); the one outline.
- `van_hull.gd`: skin pushed out 0.06 (`SKIN_OFFSET_M`) from the liner, i.e. halfway through the 0.12 wall, built as separate sides, roof (0.05 lip), rear, sills (y -0.25): separate pieces, not one closed body.
- `van_hull_lines.gd`: rails, belt, drip, corner posts at `inner_x_at + 0.06`, the same plane as the skin.
- `side_door_leaf.gd` `fit_door_leaf`: body 0.14 thick, outer skin 0.035, frame rings and panel trims at 0.035–0.045 offsets on the same curve: coplanar candidates for the inside flicker.
- `side_windows.gd` `_fit_window_root`: glass, iron cross and breakable glass ride the hinge within 1–6 cm of the fixed frame (0.05 thick at offset 0); the 10-step frame ring and the cross bars meet at the corners the swing passes.
- `rear_doors.gd`: two leaves 0.16 thick, 12 mm centre gap, window hole; `van_rear_dressing.gd` adds lock bar, welded bars, chains, cage corners.
- `van_cab.gd`: hood, windshield, header, headlights; from the quarter view the front is an open box you can see into.
- Add-ons: `van_armour.gd` (plates at a fixed `FACE_X` 2.6, rebar, spikes, road signs), `van_roof.gd` (rack at y 3.66, antennas 1.2–2.2 m, dish), `van_roof_junk.gd` (can exceed the rack), `van_wheels.gd` (spares, arches, flaps).
- Tooling: `smoke_shots.gd` whole-van views v01–v03, interior v04–v07, lit v08–v16; debug `ghost`, `torch`, `floodlight`.
- Owner pictures (2026-09-28, `images/1-3.png` in that session's scratchpad): (1) side cargo door from inside is a see-through hole: the leaf's inner face is missing, the street shows through and only trim strips float in it; (2) same with the gun port open; (3) the opened side window: the frame ring and wall reveal have sawtooth, stepped edges along the opening. The rear "vertical walls above the van" had no picture: the audit finds them.
- First look (2026-09-28 shots): side door leaf reads as a glossy black slab from outside; the front is an open wooden box; rear doors and hull meet the side skin with visible steps.

## Option map (planning only; struck lines are settled by a D)

### Relation to van-exterior-2
- ~~Replace it, park cab/underside/night read~~ → D1
- ~~Pause and resume after~~ / ~~Fold into it~~

### Finding problems
- ~~Headless measuring audit + close-up shots, kept in smoke~~ · precedent: mesh-lint passes in asset pipelines (open-edge / coplanar checks) → D3
- ~~Shots only~~ / ~~Owner pictures only~~

### Holes
- ~~One closed outer body from the outline, reveals at openings~~ · precedent: watertight/manifold hulls (racing-game car shells) → D4
- ~~Patch each gap~~ / ~~Double-sided liner~~

### Front
- ~~Sealed simple cab block~~ → D5 / ~~Full real cab now~~ / ~~Leave out~~

### Add-ons
- ~~Snap to body, height cap, else drop~~ → D6 / ~~Strip all~~ / ~~Only pictured ones~~

### Flicker
- ~~One owner per surface, fixed lift gap for trim~~ · precedent: decal offset / polygon offset practice → D7 / ~~Nudge apart~~

### Window swing
- ~~Same swing, clearance checked at closed, half, open~~ → D8 / ~~Slide into pocket~~ / ~~Outer shutter~~

## Open items

- none (round 2 answered 2026-09-28).

## Decisions (owner answers; `(auto)` = taken while running, review at the end)

- **D1 · Old plan.** Vanfix replaces van-exterior-2: it takes over the audit, holes/seams and window phases; the cab, underside and night-read phases are parked as notes for after vanfix.
- **D2 · Pictures.** Yes: the owner sends pictures before round 2.
- **D3 · Audit.** Tool + close-up shots: a headless audit tool lists every pair of surfaces lying on top of each other and every gap between outside pieces, with node names; fixed close-up shots of every seam, door and window, closed and opened; it stays in the smoke test so a new gap or overlap fails.
- **D4 · Holes.** One closed outer body: the outside skin rebuilt as one sealed shell from the body outline (sides, roof, rear, front, bottom meeting), every door and window opening lined by a reveal; add-ons sit on top.
- **D5 · Front.** (Reopened, see Rebase note: seal the existing real cab.) Seal it as a simple cab: a plain sealed cab block on the body outline (windshield, doors outlined, no gaps); the detailed real cab stays parked.
- **D6 · Add-ons.** Snap to the body, else drop: every add-on placed against the sealed body's surface and checked (touches the body, clear of every door, window and opening, under a height cap above the roof); a failing one is not built.
- **D7 · Flicker.** One owner per surface: duplicates deleted; trim, frames and plates that sit on top lifted by a fixed gap (about 1 cm); the audit checks the gap.
- **D9 · Order.** Inside first: audit tool and shots → side door and window from inside → sealed outer body → sealed simple cab → add-ons snapped and height-capped.
- **D10 · Gun port.** Leave the port as is: the door leaf is sealed and solid from inside around the port's existing opening; hatch, hole and open/close stay as they are and the audit skips them. The port gets a full rework later (owner: "its gonna have to be fully reworked").
- **D8 · Window.** Same swing, clean clearance: frame, glass, bars and wall opening cut so nothing passes through anything anywhere in the swing, checked at closed, half and fully open.
- **D11 · Audit layout (auto).** `tools/van_audit.py` + `tools/van_audit/` runner that boots the van at IDLE like the probe, collects every visible triangle in rig space, and reports FLICKER / CLIP / OPENING (triangle tests, doors and windows posed closed, half, open without tweens), HEIGHT / REAR_ROOF, EDGE and LEAK_IN / LEAK_OUT (Jolt ray and sphere queries on temporary layer-20 proxies); close-ups are a `c`-prefixed view set so `v01`.. never renumber. Reason: physics queries make leaks cheap in GDScript, and a separate tool keeps smoke untouched until phase 5 wires it in.
- **D12 · Gap vs audit tolerance (auto).** Where two parallel faces sit edge to edge (leaf vs jamb, frame rim vs wall cut, trim ends vs frame openings) the gap is 2 cm, because the audit counts faces within `PLANE_EPS` 1 cm as coplanar; stacked depth lifts stay `TRIM_LIFT` 1 cm (D7). Reason: 1 cm exactly still flagged, and 1 cm more is invisible in play.
- **D13 · Door slide recess.** The side door recesses 0.24 m outward (was 0.17) before sliding, so its cabin-side trim clears the 0.16 m side wall; the open door stands 7 cm further off the van side and keeps its framed-panel relief inside.
- **D14 · Door front edge.** Shorten the side door 13 cm at its front edge (2.34 → 2.21 m wide, rear edge unchanged); the wall opening, jamb and track follow, so nothing is buried in the cab back wall or the front corner posts.
- **D15 · Street-lit door and window parts.** Door `CurvedOuter`, `LatchPlate`, `Handle` and window `CurvedFrame`, `WindowGlass`, `IronCross` go on render layers 1 and 2, so street lights, the torch and cabin lights all reach them.
- **D16 · Window hinge pivot (auto).** The side window's hinge pivot moves from the liner to 0.32 m outboard of it at the same height (past the hull skin's outer face at 0.22 and the casing at 0.13; 0.14 still clipped the skin's rounded top corners), so no sash part rises into the wall while it swings (D8). Reason: with the pivot at the liner the frame's outer top corner lifts into the wall above the cut; any pivot outboard of every sash part and all wall material fixes it with no visible change when closed.
- **D17 · Side skin layer (auto).** The side hull skin owns only the outer layer: the wall's own grid and cuts from the wall's outer face (0.16) to `VanHull.SIDE_SKIN_OUTER_M` 0.22 off the liner, no inner face, so its returns continue the wall's edge to edge. Reason: the old skin was the whole wall panel shifted 0.06 out, overlapping the wall and z-fighting its returns (4 m² FLICKER); 0.22 keeps the outer face, casings and `HINGE_OUT_M` where they are.
- **D18 · Reveal owners (auto).** Each side opening's cut is lined by two bands with one owner each: the wall's own reveal from the liner to 0.16 (split into `<Left|Right>WallReveals`, wall material, layers 1+2) and the skin's returns from 0.16 to 0.22; the door jamb keeps only its lip (its outer return is stripped), and the side door and window casings, fully buried inside wall and skin with holes equal to the cuts, are deleted as duplicates (D7). Reason: no visible change from inside, street light now reaches the reveal from outside, and every duplicate face pair is gone.
- **D19 · Hull lines over the door's slide path.** The belt line and the rub rail break over the side door's slide path, from the door bay's rear edge to the fully open door's rear edge, the way the drip rail breaks around openings; the door itself carries no rail. The recess stays D13's 0.24 m and the rails keep their profile.
- **D21 · Cab sealing scope (auto).** The phase 4 audit shows no LEAK, CLIP or OPENING row at the front and the shots show a closed cab, so D5's reopened course stands: phase 4 keeps the real cab and only removes its coplanar trim (FLICKER) and closes the back wall from both sides. Reason: nothing in the audit says otherwise.
- **D22 · Front wheels off the cab skin (auto).** The front wheels sit `VanWheels.FRONT_WHEEL_OUT` 0.04 m further out than the rear, the cab steps 3 cm out (inner face 2 cm off `CabSkin`) and the A-pillars 3 cm inside the outline (2 cm inside the bumper ends), because the tyre caps, treads and steps lay on the cab's bowed side plane and the pillars 1 cm off the bumper ends (FLICKER). Reason: a few cm, invisible in play; review at the end.
- **D23 · Audit poses and seams (auto).** The audit visits each flicker pair once (padded-AABB min-corner cell, normal and moving-root rejects first; ~50 s whole run), poses the side doors with the rear windows (`half`, `open`) and the door-adjacent front windows alone (`win_half`, `win_open`) as the interlock allows in play, and closes an open edge whose ends and midpoint each lie within 1.5 cm of another mesh's edge. Reason: `--strict` in smoke needs a fast run with no rows play can never show; test tooling only.
- **D24 · Roof height cap.** Roof add-ons may stand at most 0.7 m above the roof crown (`outer_roof_y_at(0)` 3.57, so tops at y ≤ ~4.27): rack, crates, tarps, straps, tyres and the spotlight stay; anything over (stacked piles such as the 4.44 tyre) is not built. The audit's HEIGHT check uses the same cap.
- **D25 · Antennas.** Antennas are exempt from the D24 cap, but none stand in the rear 1.5 m of the roof.
- **D26 · Rear roof.** In the rear 1.5 m of the roof nothing stands above rack height (0.12 m over the crown): crates and antennas there move forward, or are dropped if they don't fit. The audit's REAR_ROOF check uses the same rule.
- **D27 · Roof place-or-drop (auto).** `VanRoof.fits` checks every roof mesh after the build (grouped parts drop together: dish, each antenna, each tarp with its straps; the rack is exempt), the rear antenna slots move to `rear_zone_z - 0.65`, and junk cells reaching the rear zone defer to free forward cells or drop; the rear zone starts at `profile.half_length() - 1.5`. Reason: one check shared with the audit's constants; the dish (top ~4.48) now never fits and is not built.
- **D28 · Flare and spare solids (auto).** Wheel flares are one closed single-sided L sweep 2 cm thick buried 3 cm into the skin; hub bolts stand 2 cm proud; the spare hub is 8 cm thick and its chains 2 cm thin 2 cm off every face. Reason: the double-wound flare quads and 5 mm–1 cm stacks were FLICKER (D12).
- **D29 · Arches and chains (auto).** Flare end caps use only profile vertices (quad P0P1P4P5 + two triangles); tandem rear arches trim their flares where they meet (1 cm each side of the mid z) and clamp their wells to the mid z; the spare chains are four 0.20 m segments that stop inside the hub; the exhaust pipe sits 2 cm off the sill; the sill breaks over the rear arches (spec-5-1). Reason: T-junctions, overlaps and buried faces the audit reports; invisible in play or a clear fix (the tyres ran through the sill).
- **D30 · Add-ons behind the side door.** The spare wheel, saddle tank and toolbox move out of the side door's slide path into the slot behind the open door (z 0.16 to the first rear arch's flare, less 2 cm) and pack in order on each side: exhaust side toolbox then spare; other side the tank shortened to 1.2 m, then spare. Whatever doesn't fit is not built (D6), so six-wheel vans mostly lose their spares and four-wheel vans keep one. Reason: the sliding door passed through all three (owner, Q1).
- **D32 · Low side armour dropped.** `VanArmour.SLOTS` `low_front` (in the side door's slide path) and `low_mid` (over the D30 toolbox/tank/spare; the band left above them, y 1.0 to the window bottom less 2 cm, is too thin for a plate) are both removed. The side keeps its pillar, top and tail armour, all snapped to the real skin (`VanHull.SIDE_SKIN_OUTER_M`). Reason: the open door slid over the low plates with no room, and D6 drops what doesn't fit (owner, Q2).
- **D33 · Side armour bands (auto).** The pillar (z 0.9..1.55) and tail (z 4.12..4.62) slots stop at y 2.575 and the top slot runs y 2.665..2.99 from z 0.16 (behind the open door's rear edge), 2 cm clear of the belt line and drip rail; plates lean onto the skin's chord (inner face pushed out past the bow + 1 cm), top plates are never crooked, stacked layers step 2 cm, and a placement check (door path, windows padded 3 cm, belt/drip bands, roof cap) drops a misfit. Reason: the top plates sat in the door's slide path and floated up to 35 cm off the skin; plates over the body lines FLICKER; invisible beyond a few cm, review at the end.
- **D34 · Low chassis add-ons stay embedded (auto).** The toolbox, tank, spare mount and steps keep `VanChassis.SKIN_X` 2.56 (inside the skin/sill at 2.64..2.72): they read as bolted through, the audit shows no row for them, and moving them to the skin face would push them 15 cm further out. Reason: no audit row; D6's "touches the body" holds.
- **D35 · Cables and side lamps on the real walls (auto).** `van_cable_runs.gd` resolves the side walls and props at `../../Interior` (its `../Interior` never resolved, so trunks fell back to x 2.3 inside the wall and the door leaf, and feeds had no prop keep-outs); side clearance lamps sit on the real skin (`VanHull.SIDE_SKIN_OUTER_M`) and any lamp over the side door's slide path is not built (D6), keeping z 2.1 and 4.2. Reason: a path bug and the old 0.06 skin; review the lamp count at the end.
- **D36 · Generator exhaust inside the wall (auto).** The exhaust pipe rises to local y 1.3 then leans 0.35 m toward the aisle to a vent at van y 2.49 (was straight up to 2.89 at x 2.36, through the bowed wall and skin); the roof rack end bars go 0.02 thick (0.04 left their faces 1 cm off the rails', which the audit still flags, D12). Reason: LEAK_OUT and FLICKER rows; a small prop move.
- **D37 · Bulkhead weave and rib welds (auto).** The bulkhead grille's `MeshFwd` strands sit 1.2 cm in front of the grille plane and `MeshBack` 1.2 cm behind (`MESH_WEAVE_Z`), and the inner-shell rib welds are 0.07 × 0.07 × 0.03 (2 cm proud of the rib's thin faces, buried in its depth), because both shared faces within 1 cm (826 and 98 FLICKER rows). Reason: invisible in play.
- **D38 · Side door recess 0.30 m (owner, replaces D13's 0.24).** The side door steps out 0.30 m before it slides, so its cabin-side frames (0.055 proud of the leaf's inner face) clear the D17 skin (liner + 0.22) by about 2 cm in `half`/`open`; the open door stands 6 cm further off the van side. Anything placed against the 0.24 recess (door path keep-outs in armour, lamps, chassis slot) follows the new value.
- **D39 · PC rig stays in the left door bay (owner).** The `Interior/Props/RequestBoard/PcRig` stays where it is: the left side door is a breach point, never walked through. Its OPENING rows go on the audit's exemption list.
- **D40 · Cable trunks hop over the side door bays (owner).** The upper-wall cable trunks (y ~2.88) break at each side door bay and cross over it along the ceiling, so no cable runs across a door opening under its top (3.05).
- **D41 · Window frames exempt from OPENING (auto).** The audit's OPENING check skips the side wall, its reveals and the side skin (`Interior/Shell/SideWalls/`, `VanLook/Hull/SideSkin`) for the four side windows: they frame the cut and always have triangles in its padded rectangular box at the rounded corners. Reason: test tooling; the rows can never mean an obstruction.
- **D42 · Floor decal lift (auto).** The flat floor decals (mats, paper, cardboard, rag, tape, oil stains) sit `DECAL_LIFT` 1.2 cm above the deck instead of 3-7 mm, and small stacked prop parts embed 1.5 cm into what they sit on rather than lie flush, per D7/D12. Reason: the audit counts faces within 1 cm as coplanar; 1.2 cm is barely visible in play. Review at the end.

- **D43 · Inner shell dressing fit (auto).** Scrap plates and weld patches are placed clear of the rib z bands (rib half depth 0.035 + 2 cm) and the patch disc stands 2 cm proud of its weld ring (ring 5 mm buried .. 1.5 cm proud, patch 1.5 .. 3.5 cm), so no rib, plate, ring or patch shares a face plane; a piece with no free spot is not built (D6). Reason: FLICKER rows; dressing positions only.
- **D44 · Small structure depths (auto).** Bulkhead top rail segments step depth (inset 0.07, odd 4 cm less), mid posts run rail centre to rail centre, door header and bottom rail 0.20 deep with inner ends buried in the opening post, kick plate 0.08 deep; rear bumper hangers slimmed, entry ramp 2.16 wide, wheel flare inner face at `SKIN_X + 0.06`; wall-post and kick-strip joints left as they are (alternating them showed as steps, Q1). Reason: FLICKER rows at a few cm, invisible in play (shots 01/03).
- **D45 · Bulkhead joint rows exempt (owner, Q1).** The bulkhead `LeftWallPost_n/RightWallPost_n vs n+1` and `KickPlate_n vs n+1` joint rows stay as built (tiny, hidden in the post corners; alternating segment depths showed as a saw-toothed post and a striped kick plate) and go on the audit's exemption list with that reason in phase 11.
- **D46 · Questions auto (owner).** "the last 7 questions i just like awnsered the recomended one, just let the map keep working." From phase 8 on, every phase question, on the stop line or not, takes its Recommended option and is recorded as `D<n> (auto, owner-delegated)`; no phase blocks for a question. Only a check that fails and can't be fixed still blocks. Stage done lists every owner-delegated D under Look at for review.
- **D47 · Visible flicker floor (owner-delegated plan review).** FLICKER rows under `MIN_VISIBLE_AREA` 0.005 m² (about 7×7 cm) are reported as `FLICKER_MINOR` and neither fixed nor failed. Reason: 311 of the 418 FLICKER rows after phase 7 are slivers nobody sees in play, and fixing them one by one was most of the plan's time. `--strict` fails on FLICKER rows at or above the floor that aren't exempt, plus CLIP, OPENING, LEAK_IN, LEAK_OUT and HEIGHT.
- **D48 · Audit freezes machines (auto).** `van_audit.gd` `_freeze_machines()` stops every `MachineMotion` and restores each spin/pump/wobble target to its rest pose (`add_spin` now stores `&"rest"`, a data field, no game-code hook) before the first collect. Reason: fan, flywheel and needle poses made FLICKER rows vary run to run; test tooling only.
- **D49 · PC rig flicker fixes (auto, owner-delegated).** CRTs (`MachineParts.crt`) get a `Shell` box and a `Bezel` lip ring (`_frame_mesh`, band `max(0.1*s, 0.024)`) with the `Screen` 1.2 cm behind the lip; crate slats show only on the sides and back; the five fanned floppies and their label become `FloppyPile` + `FloppyLoose` sunk into the desk; the `MouseMat` is deleted (a thin mat can't sit 1.2 cm off the desk) and the mouse is sunk 1.2 cm; sticky notes curl 0.3 rad off the partition; `StatsFoot` and `MainNeck` are buried in the CRT shells. Reason: every thin prop lying on a host face is a FLICKER row under the 1 cm tolerance; review the look at the end.
- **D50 · Hopper and rack flicker fixes (auto, owner-delegated).** Relay rack flanges start at their rail's front face; shelf lip sits ahead of the shelf; the cabinet cut-back is 1.3 cm thick, 1.2 cm proud of the door, contactors on it; gauge, knife switch, fuse plate and breakers move 2 to 2.5 cm off the front wall (the rack's backboard is buried in the wall slab, face at rack-local z -0.348). Hopper: pane 0.40 wide, button 1.5 cm in, chute lips 1 cm out, mid rails end at the post centres 3.6 cm deep, braces 4.4 cm deep at z -0.34, bin walls stand on the base, scrap tilted ±0.3 rad (second rng, seed 4242), chain Link0/Link6 (inside the sprockets) dropped. Reason: every pair was a same-facing face within 1 cm; a cm or two is invisible in play, review at the end.
- **D51 · Visible flicker area (auto).** A FLICKER row's visible `area` sums only triangle pairs over `MIN_AREA` 1 cm²; every pair over 1e-6 m² adds to `total`, which decides whether the row exists (> `MIN_AREA`). FLICKER vs `FLICKER_MINOR` uses `area` against `MIN_VISIBLE_AREA`. Reason: the per-pair 1 cm² cut made a borderline pair flip rows between runs; summing slivers instead pushed gauge dials and rack uprights (60 slivers each) over the floor though nothing visible changed. Test tooling.
- **D52 · Audit ray probe (auto).** `py -3 tools/van_audit.py --probe x,y,z:dx,dy,dz` (repeatable, rig-local) skips the audit and prints every triangle the ray crosses, brute force and not through the physics proxies, plus the first hits of 8 rays offset 1 and 2 cm around it (`van_audit_probe.gd`). Reason: the proxy trace stops early and cannot show which faces border a gap; test tooling.
- **D53 · Side window stop ring (auto, owner-delegated).** Each side window gets a static `WindowStop` ring on its root (not the swinging hinge), frame material, 8 mm thick, its outboard face 1.5 cm inboard of the liner, from 4 cm outside the wall cut to 5 cm inside it (3 cm over the frame), because the frame's outer edge sits 2 cm inside the cut (D12) and a grazing ray slid along that slot out through the wall (the LEAK_IN row). The sash swings outward, so the ring never blocks it; the audit's window OPENING exemption lists `/WindowStop`. Reason: seals the slot with no coplanar faces; reads as window trim. Review in play.
- **D54 · Faces seen through side opening gaps (auto, owner-delegated).** A LEAK_OUT ray whose first hit is a door jamb lip, a wall reveal, the wall's own cut face, a door leaf's `CurvedBody` edge band or a ceiling rib end is `LEAK_OUT_EXEMPT` when the hit lies inside a closed side door leaf or window sash box grown by `OPENING_PAD` (0.40, 0.15, 0.20) (`van_audit_leaks.gd`), because probes showed these are interior faces seen through the leaf's 13 cm clearance (covered by the jamb lip, D12/D18), not see-through holes: the `Left/CurvedBody` y 0.16 ray enters the leaf and exits its bottom into the jamb. No leaf seal was needed. Reason: by design; a hit outside every opening still reports.

## Constraints (every phase)

- Geometry only: no texture or shader-look work; exterior materials keep their recipe (`art-style.md`: procedural grime, metallic ≤ 0.3, roughness 0.78–0.95, always night).
- `VanBodyProfile` is the one outline for anything meeting the wall, vault or skin (rules file); no piece gets its own width constants.
- Light pairing: set `layers` / `light_cull_mask` before `add_child`; retarget only through `VanLighting.retarget_layers`.
- Door/window gameplay, breach points, collision shapes and walk space unchanged unless a phase says so.
- `DEFAULT_VAN_SEED` 1337; the scene dump and smoke fingerprint are blessed only by a phase that says the tree changes, and the report says so.
- Worktree mode: commit by path on the branch, never push.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| 1 | Geometry audit tool and close-up shots | code, research | D3, D9, D11 | done 60e1a32 |
| 2 | Side doors and windows from inside | code | D7, D8, D10, audit | done cf9e65a |
| 3 | One sealed outer body | code | D4, D7, audit | done a809f31 |
| 4 | Sealed simple cab | code | D5, D4, audit | done 815948b |
| 5 | Add-ons snapped and height-capped | code | D6, audit | done 32a481d |
| 6 | Side-wall and cable flicker | code | D12, audit | done 0dcc580 |
| 7 | Small structure flicker | code | D12, audit | done 6c2de5c |
| 8 | Generator and welder visible flicker | code | D12, D47, audit | done 471f24f |
| 9 | PcRig and CRT visible flicker | code | D12, D47, audit | done 649a98f |
| 10 | Hopper, rack and leftover visible flicker | code | D12, D47, audit | done c842e91 |
| 11 | Audit floor and exemptions | code | D45, D47, audit | done a92d1cb |
| 12 | Leak tracing and side window stop ring | code, research | D52, D53, audit | done 9f1eb2a |
| 13 | Side door leaks and jamb exemptions | code | audit | todo |
| 14 | Rear door centre seam and glass crack | code | audit | todo |
| 15 | Window reveal and sill leak exemptions | code | audit | todo |
| 16 | EDGE rows and FLICKER leftovers | code | D47, audit | todo |
| 17 | Audit strict in smoke | code | D23, D47, audit | todo |

## Phases

### 1 · Geometry audit tool and close-up shots (D3, D9)
Research: how to list coplanar overlaps and open gaps from Godot meshes headless (triangle/AABB tests on the built `van.tscn`), then go past it.
Deliverables: a headless audit under `tools/` (run from `tools/smoke/` or its own `.py`) that instances the van at seed 1337 and reports, with node paths: surface pairs within 1 cm of each other and facing the same way (flicker), outside edges that don't meet a neighbour (see-through gaps), anything above a roof height cap, anything passing through a door or window opening; side doors and windows checked closed, half and fully open; the gun port skipped (D10). Close-up `--shots` views of every seam, both side doors from inside and outside, every side window closed and open, the rear roof line. `.claude/plans/research/vanfix-01-audit.md`: every finding (node, builder, picture, severity), the owner's three pictures matched to findings. The audit's pass/fail wiring into smoke comes in the phase that clears its last finding; until then it reports.
Verification: check, smoke, the audit names the side-door hole, the window sawtooth and something above the rear roof line.
Notes: done 60e1a32. `tools/van_audit.py` + `tools/van_audit/` (mesh, states, overlap, gaps) and close-ups c01–c32; findings in `research/vanfix-01-audit.md` (side-door LEAK_OUT on CurvedOuter, window CurvedFrame FLICKER vs hull casing, REAR_ROOF rack/crate/antenna). Audit takes ~4 min.

### 2 · Side doors and windows from inside (D7, D8, D10)
Deliverables: side door leaves solid from both sides (inner face built, trim lifted by the D7 gap, duplicates removed), port untouched; the window frame, reveal, glass and iron cut clean along the opening with no stepped edges and no part crossing another at closed, half or open.
Verification: check, smoke, scene dump (bless if the tree changes, say so), audit clear for doors and windows, close-up shots re-read against pictures 1–3.

### 3 · One sealed outer body (D4, D7)
Deliverables: the exterior skin rebuilt as one closed shell from `VanBodyProfile` (sides, roof, rear, bottom, meeting the front), reveals at every door and window, hull lines on the D7 gap, the rear doors seated in it; the liner faces only in.
Verification: check, smoke, scene dump, audit clear for gaps on the body, lit shots v08–v16 and the new close-ups.
Notes: done a809f31 (sessions 4–9: 1e0f3ab..a809f31). Side skin 0.16–0.22 (D17), reveal owners (D18), roof/rear/sills/belly/front skin at the 0.22 face, RearSkin ring around the leaves, hull lines breaking over the door slide (D19), FrontSkin closing the cab step. Audit: CLIP 102, EDGE 24, FLICKER 1727, LEAK_IN 1, LEAK_OUT 44; the body's EDGE rows left are per-mesh seams and the single-sided side skin, no holes.

### 4 · Sealed simple cab (D5, D4)
Deliverables: `van_cab.gd` front closed into a plain sealed block on the body outline, windshield and door outlines, joined to the body without gaps; front kit refit onto it. The detailed cab stays parked.
Verification: check, smoke, scene dump, audit clear at the front, front and quarter shots.
Notes: done 815948b (session 11: fda7fad, 23f70b1, 815948b). Real cab kept (D21): windshield frame, post, grille surround, headlight bezel/lens buried off the cab face's plane, back wall double-sided; ram joints, cage tabs, lamp cages refit; cab steps, front wheels and A-pillars off the cab side and bumper (D22). Audit: `VanLook/Cab/` FLICKER 41 → 0, total FLICKER 1727 → 1683; the 3 cab EDGE rows left are tube ends (CabLiner, CabBackLip) and a CabFace seam at the windshield corner, no holes.

### 5 · Add-ons snapped and height-capped (D6)
Deliverables: armour, rebar, spikes, signs, roof rack, roof junk, antennas, spares and rear dressing placed against the sealed body's surface; a placement check (touches the body, clear of openings, under the roof cap) drops any failure; the audit becomes a smoke failure.
Verification: check, smoke (fingerprint/bless as the phase states), scene dump, audit fully clear across several `van` seeds, rear and roof shots.
Notes: done 32a481d (split 2026-09-29 after three partial sessions: autoplan's "same phase partial 3 times"). Landed: armour slots and `_clear_of_openings` (D32/D33), chassis slot packing (D30), roof rack/junk/antennas on the rails, D38–D42, side rails and rear-door window flicker. Audit at the split: CLIP 0, OPENING 0, EDGE 23, FLICKER 508, LEAK_IN 1, LEAK_OUT 45. The rest is phases 6–11; the state file's "Completed phase" lists the FLICKER groups by name.

Every phase 6–9: re-run `py -3 tools/van_audit.py`, group `^FLICKER` rows by a=/b= prefix, one spec per group or builder; faces ≥ 1.2 cm apart, parts still touch (embed rather than float); keep implementer prompts narrow (file, grep for the rows, line range). Verification: check, smoke, scene dump (bless if the tree changes, say so), the phase's groups gone from the audit, no new rows.

### 6 · Side-wall and cable flicker (D12)
Deliverables: `DoorJamb_L/R` vs Left/RightWall (drop the jamb's inner-face triangles where the wall panel runs into the bay at z -4.655..-4.616, not `x_shift`); `DoorJamb_R` vs `FrontWall/Slab`; `FloorSeal_L/R` vs `Bulkhead/*WallPost_0`, `RightWallReveals`, `RightHinge/CurvedBody`; cable strand pairs (`van_cable_runs.gd` / `van_cable_router.gd`).
Notes: done 0dcc580 (74cfe3c, 0dcc580). `MachineParts.cable_bundle` offsets strands across the run (`_strand_sides`, mitered), not along world X: same-segment strand rows gone, cable FLICKER 36 → 25 rows all < 0.01 m². Jamb front return 1.7 cm into the slab (`JAMB_FRONT_OUT`), jamb cabin face clipped to the panel grid edge (`_front_overlap`, `_clip_front_strip`); floor seals y -0.03..0.05, inner face 1.5 cm further in, ends 0.10 short. Audit: EDGE 23, FLICKER 492, LEAK_IN 1, LEAK_OUT 45; no DoorJamb/FloorSeal row but LEAK_OUT (L 96, R 86 rays).

### 7 · Small structure flicker (D12)
Deliverables: WallRib vs Plate, PatchWall/Ceil `_Ring` vs patch, Bulkhead TopRail vs TopRail_7..9 / MidPost, RearEntryRamp and RightHinge/CurvedBody vs BumperHanger, `CargoRail_R_0` vs `VanLook/Wheels/FlareR1/R2`, wheel `Hub` vs `Bolt%d` (2 cm bolt lift, `van_wheels.gd` `_build_wheel`).

Phases 8–10 fix only FLICKER rows with `area=` ≥ 0.005 m² (D47); smaller rows are left for the phase 11 floor. Filter: `awk '/^FLICKER/ { split($3,a,"="); if (a[2]+0 >= 0.005) print }'` over the report, then group by a=/b= prefix. Each phase is at most three specs; if a group is still open at the end, note it in the state file and move on (phase 11/13 pick up leftovers), don't go partial for it.

### 8 · Generator and welder visible flicker (D12, D47)
Deliverables: `Interior/Props/FuseBox/*` (Generator) and `CraftingTable/Welder` rows ≥ 0.005 m² (FuseBox ~26, Welder ~12, incl. WelderBody vs Panel 0.0624); the audit freezes or skips animated fan/flywheel/spoke parts so their rows are stable run to run; optional first step: the ceiling patch ring 2 cm under `_ceiling_y` (`van_inner_shell.gd` `_build_ceiling_patch`, `Shell/Ceiling` rows).
Notes: done 471f24f (e820646 shared builders + audit freeze D48, 56351cb welder, 471f24f generator). Fan blades pitched per arm, flywheel spokes 0.024 wide, hubs >= 0.04, motor caps +1.5 cm, gauge face 1.2 cm proud, pipe flange 0.03 with `flange_a`/`flange_b` flags; welder panel, scorch and visor slabs +-1.3 cm through their host, bottle bands +1.2 cm; generator skid web inside its flanges, rust slabs 1.35 cm proud, jerry cans 1.2 cm lower, gauge 1.5 cm out. Audit: FLICKER 418 -> 370 (identical across two runs), no FuseBox/Welder row >= 0.005, EDGE 23, LEAK_IN 1, LEAK_OUT 45; 58 rows >= 0.005 left elsewhere. Optional ceiling ring step skipped (row left for phase 10/11).

### 9 · PcRig and CRT visible flicker (D12, D47)
Deliverables: `RequestBoard` (PcRig) rows ≥ 0.005 m² (~18), incl. CRT Bezel vs Screen 0.0768 and the StatsCrt Bezel vs Screen 0.0555 (same builder: screen set back 1.2 cm or more behind the bezel lip); `FrontWall/Slab` vs PcRig.

### 10 · Hopper, rack and leftover visible flicker (D12, D47)
Deliverables: `LootMachine` (Hopper) rows ≥ 0.005 m² (~16), `CabRelay` Rack (~8) and `FrontWall/Slab` vs Rack, then the single leftovers: `FrontWall/CasingLeft/Right`, `Bulkhead/TopRail_9`, `FrameRailL/R`, `Cables/@366`. Bulkhead `KickPlate_n` / `WallPost_n` joint rows are not touched (D45).
Notes: done c842e91. LootMachine and CabRelay rows >= 0.005 cleared (FLICKER 343 → 291) except Scrap2 vs Scrap8 (0.0095, still sharing a tilt plane); leftovers carried to 11/13: CasingLeft/Right vs CasingHead, Vault vs PatchCeil0_Ring, Cables @366/@386, FrameRailL/R vs RearBumper, VentDuct vs VentGrille, Bulkhead TopRail_9 vs MeshBack_322 (D50).

### 11 · Audit floor and exemptions (D45, D47)
Deliverables (tooling only, `tools/van_audit/`): `MIN_VISIBLE_AREA` 0.005 m²: FLICKER rows under it print as `FLICKER_MINOR` and never fail; an exemption list (one entry per rule, each with its reason and its D) holding D41 window reveals, D45 bulkhead joints, the 6 Wells (single plates), 4 ExteriorPane, SideSkin inner face (D17); EDGE edges matched across meshes in `van_audit_gaps.gd` so per-mesh seams stop counting; the PerimeterFrame vs SideSkin MIN_AREA flip in `half` made stable. The report header prints counts with minor and exempt rows split out.
Verification: check, audit run twice gives identical counts; FLICKER (non-minor, non-exempt) at the phases 8–10 leftovers only.
Notes: done a92d1cb (721fd76, a92d1cb). `van_audit_exempt.gd` holds the rules (FLICKER KickPlate/LeftWallPost/RightWallPost joints D45; EDGE Wells D29, ExteriorPane D41, SideSkin D17) and the OPENING exemptions (D39, D41); rows print as `FLICKER_MINOR`, `FLICKER_EXEMPT`, `EDGE_EXEMPT` and stay out of `AUDIT SUMMARY` (header `COUNTS`/`MINOR`/`EXEMPT`, tail `AUDIT INFO`). Visible area per D51. EDGE T-junction seams close in `van_audit_seams.gd` (only CabFace cleared). Two runs identical: EDGE 10, FLICKER 9 (the phase 8–10 leftovers exactly), LEAK_IN 1, LEAK_OUT 45; minor 417, exempt EDGE 12 / FLICKER 31.

### 12 · Leak tracing and side window stop ring (D52, D53)
Done across sessions 5-7 (autoplan stopped it after three partials; split 2026-09-29 into 12-16): every LEAK row carries its first ray's trace (5ffaddc), `tools/van_audit.py --probe` (7d0de6e, D52), side window stop ring (9f1eb2a, D53). Findings for 13-16 are in `.claude/plans/vanfix.state.md`.

### 13 · Side door leaks and jamb exemptions
Deliverables: split `van_audit_gaps.gd` (399 lines) before adding; a LEAK_OUT rule in `van_audit_exempt.gd` (`rule_for("LEAK_OUT", ...)`, reason and D) for jamb lips and reveals seen through the side door openings (`DoorJamb_L/R`, `RightWallReveals`, `Right/CurvedBody` rear edge); seal the side door leaf where the probe shows see-through (`Left/CurvedBody` row at y 0.16: rays pass under the leaf; the closed leaf `DOOR_HALF_Z` 1.105 leaves ~13 cm at each end of the opening z -3.42 ± 1.235, check its frames first, D12 wants 2 cm).
Verification: check, smoke, audit (side-door LEAK rows gone), shots of the side doors closed from inside and outside.

### 14 · Rear door centre seam and glass crack
Deliverables: split `rear_doors.gd` (400 lines) first; an overlap strip (astragal) on one rear leaf covering the centre seam (rays from `(0, 0.8|2.0, 5.052)` heading -z pass at x ≈ 0..0.12, ~25 LEAK_OUT rows); close the rear window glass-to-frame crack behind the last LEAK_IN.
Verification: check, smoke, audit LEAK_IN 0 and no centre-seam rows, rear shots read (closed doors, inside and outside).

### 15 · Window reveal and sill leak exemptions
Deliverables: LEAK_OUT rules with reason and D for window reveals and the rear sill seen through openings; any leftover LEAK_OUT row fixed or exempted.
Verification: check, smoke, audit LEAK_IN 0, LEAK_OUT 0.

### 16 · EDGE rows and FLICKER leftovers
Deliverables: each EDGE row in the state file's list (CabLiner, CabBackLip, RearSkin, CornerPostFL/FR, BellySkin, RearWall hinge CurvedBody, RearCornerL/R, Wells, ExteriorPane, SideSkin) fixed or exempted with reason and D (by-design single-sided plates exempt); the 9 FLICKER leftovers fixed in code.
Verification: check, smoke, audit EDGE 0 and FLICKER 0 (after exemptions); shots only if a fix is visible.

### 17 · Audit strict in smoke (D23, D47)
Deliverables: every failing audit count 0 at seeds 1337 and two others (fix any leftover ≥ floor row); audit fast enough for smoke (carry-forward speed notes); door-adjacent window posed apart from its door; `--strict` wired into `tools/smoke.py` as a failure. Then Stage done, listing every `(auto, owner-delegated)` D under Look at.
Verification: check, smoke (fails on a planted flicker, passes clean), `py -3 tools/smoke.py --shots DIR --van-seeds 3` rear and roof shots read, including the D40 ceiling cables, the rear-door bars and the generator pan.

## Carry forward

- (Plan review 2026-09-29, owner-delegated) Phases 8–11 re-cut into 8–13 around D47: 311 of 418 FLICKER rows after phase 7 were under 0.005 m²; only the ~107 visible ones get fixed, the floor and the exemptions move into their own tooling phase (11) ahead of leaks (12) and strict (13). Questions auto from here on (D46).

- (Phase 1) The audit takes ~4 min, nearly all in three FLICKER passes; phase 5 must speed it up (normal bucketing, or moving-roots-only flicker at half/open) before `--strict` goes into smoke.
- (Phase 1) The side door leaf `CurvedBody` clips the jamb, casing and forward into the cab back wall (z to -4.74); fix the leaf length before triaging the door OPENING rows (props in the PcRig/CabRelay area).
- (Phase 1) Rear doors show the same missing inner face as the side doors (LEAK_OUT on `RearWall/*Hinge/CurvedBody`): phase 3 seats the rear doors.
- (Overtaken, see Rebase note: van-exterior-2 finished all seven phases.) Parked from van-exterior-2 (D1): the real cab with a dark interior and dash glow (its D3, D9), the underside and wheels (D6), the night read (D7). Its phase 1 tooling (torch, floodlight, lit shots v08–v16) stays and is used here.
- A fresh worktree's first smoke run fails on `VanLook` not found (stale class cache); `py -3 tools/check.py` first fixes it.
- (Phase 2) The audit poses every door and window at the same fraction, so the front window and its side door are audited open together, which the interlock forbids in play (except a breach smash); phase 5 should pose door-adjacent windows and their door in separate states.
- (Phase 2) `side_windows.gd` `HINGE_OUT_M` 0.32 is sized to today's hull skin (panel mesh 0.16 thick, 0.06 out: outer face 0.22 off the liner). Phase 3 rebuilds the skin: re-derive it (pivot outboard of all wall material around the opening, open pane below the cut's rounded top corners) and re-audit the window swing.
- (Phase 2) Left for later phases: front window vs its own slid-open door rows (the audit's all-open pose; play's interlock forbids it except a breach smash, phase 5 poses them apart); door vs `VanLook` Hull/Armour/Wheels/Cables/MarkerLights rows (D6, phases 3 and 5); `CurvedBody` LEAK_OUT past the jamb gap (phase 3); ExteriorPane EDGE rows (single-sided pane, by design); the rust band on the window reveal in c10 is the grime shader, not geometry.
- (Phase 3) Every exterior piece but the side skin sits at `SKIN_OFFSET_M` 0.06 off the liner (roof edge, rear posts, sills, patches, hull lines, armour face), while the side skin's outer face is at 0.22 (D17): the sealed body needs one outer surface; the roof crown must stay under the rack (y 3.66). `VanBodyProfile.outer_x_at` is liner + 0.12 but the wall is 0.16 thick.
- (Phase 3, session 5) `HINGE_OUT_M` 0.32's reasoning named the window casing (0.13), now deleted; the skin's outer face 0.22 still sets it. `van_side_wall_panel.gd` and `van_side_wall_shell.gd` are at the 400-line cap: any further panel or ring change needs a helper split first.
- (Phase 3) The audit's EDGE check is per mesh (open = one triangle, no physics body within 1.5 cm), so edge-to-edge seams between hull pieces (FrontSkin/RoofSkin, RearSkin/Sill/BellySkin/RearCorner at the rear bottom corner, CornerPostF caps at z -4.58) and SideSkin's by-design missing inner face (D17) still report; phase 5 should match edges across meshes before `--strict`. LEAK_IN 1 at (2.703, 1.086, -0.202) is unexplained. Optional FLICKER: `Left/RightWall` vs `DoorJamb_L/R` at (±2.495, 2.237, -4.644), `DoorJamb_R` vs `FrontWall/Slab`.
- (Phase 4) Every wheel's `Hub` and its `Bolt%d` boxes share planes (FLICKER on `VanLook/Wheels/Wheel*/Hub`, 30 rows); `van_wheels.gd` `_build_wheel`. Clear them with the add-ons in phase 5 (a 2 cm lift of the bolts off the hub face).
