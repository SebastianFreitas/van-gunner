# hands-blender-review 04 · vein paths (2026-10-18)

Owner, 2026-10-18: "You should make a new phase or pass before the veins. To change their position to more natural shapes" (app: "Vein paths").

## Anatomy (web)
- Dorsal digital veins run along the finger sides and unite near the proximal phalanx bases into three dorsal metacarpal veins (2nd-4th intermetacarpal spaces); intercapitular veins pass between the metacarpal heads (the knuckle valleys), never over them (Kenhub; Sobotta fig. 713).
- They drain into the dorsal venous network/arch over the mid metacarpus (an arch in about 70 %, asymmetric, varies person to person). Its radial end becomes the cephalic vein (from the anatomical snuffbox, thumb side of the wrist), its ulnar end the basilic; an accessory cephalic and a branch to the cephalic are common (Wikipedia "Dorsal venous network of hand", Kenhub, imaios).
- Sculpting: veins sit in the gaps between bones and wander, tendons run straight over the metacarpals; plan the paths before raising them; overdone veins look fake (anatomy4sculptors via search; novedge ZBrush tips).
- So: valleys between knuckle heads -> metacarpal veins between the cords -> one arch crossing the cords obliquely -> trunks at the radial and ulnar wrist borders, which wrap toward the palm like roots. Radius grows downstream (Murray: r_parent^3 = sum r_child^3).

## Measured (Blender, `arms.blend` HEAD 7af84174, scratch `vg-hbr/veinpaths/survey.txt`)
- Hand frame (`hand_frame`, lat + = index side): heads index (.953, +.0526), middle (1.0, 0), ring (1.009, -.0507), pinky (.842, -.0918), thumb.01 (.314, +.0637); span .1649. Same on L and R.
- Chart on the dorsal hand: x = 1.119 + .166 s - .123 lat (max residual .011); v changes about .54 per metre of lat (R: v rises toward the pinky; L: v falls toward the pinky). So a vein of chart r is about 2.26 r / .54 metres wide across lat.
- Cords (`ArmSkinFolds`, from 0.15 head to head): lat = k s, k index .0552, middle 0, ring -.0502, pinky -.109.
- Knuckle crest discs, 0.6 x 1.2 shaft: index .0197, middle .0240, ring .0194, pinky .0172 m; valley gaps between discs IM .0095, MR .0073, RP .0129; valley points IM (.975, +.028), MR (1.005, -.028), RP (.922, -.072).
- Mean edge on the back (mm): R 1.5-2.6 everywhere on s -0.4..1.0; L 1.5-2.5 on s .6-1.0 and on lat -.015..+.045 at s <= .3, but 5-9 mm on s .3-.5 and 5-19 mm on the radial flank (lat > .045, s < .5) and the ulnar wrist (lat < -.03, s < .3). Finger parts beyond s 1.05 are coarse (8-20 mm).
- Today's hand paths (R 2-9, L 3-5) run from s .6 to 1.2 as parallel knuckle stubs, two R ends land on palm-side vertices; R 0-1 and L 0 run straight from the forearm into the mid-back. Forearm paths (R 0-1 below s -0.3, R 10-12 palm, L 0-2 below s -0.3) come from the owner's photos and stay.

## The v1 set (phase 3 reworks it by the Design rules below into Set v2; hand frame (s, lat, r chart); free end = dives under; W = wrap root, chart offsets (dx, dv) from the named trunk point, v sign: R radial -v / ulnar +v, L radial +v / ulnar -v)
R (richer, as its photos):
- R-A arch, one path, spliced on old R 0 and R 1 at their first point past s -0.30: (-.30,+.072,.0040) (-.12,+.069,.0042) (.04,+.066,.0044) (.18,+.058,.0043) (.32,+.047,.0040) (.44,+.037,.0038) (.53,+.028,.0036) (.59,+.018,.0034) (.63,+.004,.0034) (.625,-.012,.0034) (.59,-.032,.0035) (.54,-.050,.0037) (.47,-.066,.0040) (.35,-.076,.0043) (.20,-.078,.0045) (.05,-.073,.0046) (-.12,-.064,.0045) (-.30,-.058,.0042).
- R-IM free (.95,+.029,.0016) (.86,+.025,.0021) (.77,+.022,.0025) (.68,+.021,.0028) -> R-A at (.58,+.020).
- R-MR free (.97,-.027,.0018) (.88,-.024,.0023) (.79,-.020,.0027) (.71,-.020,.0030) (.655,-.028) -> R-A at (.602,-.026).
- R-RP free (.89,-.071,.0017) (.80,-.064,.0022) (.71,-.060,.0026) (.62,-.054,.0028) -> R-A at (.545,-.052).
- R-rad free (.90,+.074,.0015) (.78,+.068,.0020) (.64,+.060,.0025) (.50,+.052,.0028) -> R-A at (.40,+.040).
- R-uln free (.76,-.106,.0015) (.66,-.098,.0020) (.54,-.090,.0025) -> R-A at (.405,-.073).
- R-obl (accessory, crosses middle and index cords at 31-38 deg) free (.50,-.010,.0020) (.36,+.004,.0026) (.22,+.022,.0030) (.10,+.045,.0034) -> R-A at (.03,+.0655).
- R-W1 ulnar root from R-A's (.05,-.073): (-.008,+.012,.0028) (-.016,+.024,.0022) (-.022,+.034,.0016) free. R-W2 radial root from R-A's (-.12,+.069): (-.008,-.012,.0026) (-.016,-.022,.0020) free.
L (sparser, arch higher where L is dense):
- L-ceph spliced on old L 0 at its first point past s -0.30: (-.30,+.024,.0042) (-.14,+.022,.0046) (.02,+.020,.0050) (.18,+.026,.0052) (.34,+.036,.0052) (.48,+.046,.0050) (.62,+.050,.0044) then the arch (.70,+.030,.0036) (.74,+.008,.0034) (.75,-.012,.0034) (.73,-.034,.0036) (.68,-.055,.0038) (.60,-.070,.0040) then the basilic (.48,-.066,.0046) (.36,-.056,.0050) (.22,-.040,.0052) (.08,-.026,.0052) (-.06,-.020,.0050) (-.18,-.026,.0044) (-.30,-.030,.0036) free end (the ulnar root; L's ulnar wrist is too coarse to wrap).
- L-IM free (.94,+.030,.0017) (.86,+.027,.0021) (.78,+.025,.0024) -> arch at (.71,+.026). L-MR free (.97,-.028,.0018) (.89,-.025,.0022) (.81,-.023,.0025) -> (.742,-.022). L-RP free (.88,-.072,.0016) (.80,-.068,.0020) (.72,-.064,.0024) -> (.66,-.059). L-uln free (.76,-.106,.0015) (.66,-.094,.0020) -> (.58,-.071). L-rad free (.86,+.078,.0015) (.74,+.068,.0020) -> (.62,+.054) (r widened by the cover gate if needed: L's radial flank is 5-9 mm).
- L-W radial root from L-ceph's (.02,+.020): (-.010,+.010,.0030) (-.020,+.018,.0022) free.

Checked by hand on the table: every point clears the crest discs (closest R-uln start .0194 > .0172); metacarpal veins sit within .003 of the midline between their cords; arch crossings 37-90 deg; pack estimate R about 120, L about 95 points (cap 160). Not checked by hand: thumb/finger weights at the free ends and the join angles (the phase measures them).

## Design rules (veinfix, 2026-10-18; auto, owner-delegated: "finish everything without asking me", goal "creepy monster like ... professional level")
- D40 meander: v1 is five near-parallel, evenly spaced tributaries on one symmetric U, the same on both hands (design review 1). Interior points sit 2-5 mm (metres) off the segment joining their neighbours, as many as Gate 10's spacing allows (Gate 10 governs, D47), uneven sign and amplitude, fixed data (no seed); radius steps uneven per vein; one cross-link per hand (R: R-IM s ~.86 to R-MR s ~.70 across the middle cord; L: L-MR s ~.86 to L-RP s ~.74 across the ring cord), both ends joined, r <= 0.8 x the thinner vein; L and R differ in every path. Reason: veins in the gaps wander (Anatomy), the owner wants creepy, not a diagram.
- D41 knuckle forks: each valley vein (IM, MR, RP) ends in a Y at a fork F about 6 mm proximal of its valley point: arm A continues the vein (turn at F <= 25 deg), arm B is its own path ending on F; each arm hugs its neighbouring head on the valley side at disc + 1.5 mm, from psi -8 deg to +22..30 deg (angle from the head-to-valley direction toward distal; arc 6-10 mm), r .0009-.0013. Free ends and arm points stop under finger weight 0.25 (MCP flex creases, design review 4). Reason: the owner's "around the knuckles"; dorsal digital veins unite at the valleys (Anatomy).
- D42 trunks: r never falls downstream (apex to each wrist end); r at s -.30 >= the trunk's max on the hand. L's basilic runs on to s -.56 holding r, then dives (free end), because no old forearm path lies within .02 chart of its wrist point (L 1 ends (-.50,-.046) palm side, L 2 at (-.89,-.065), r .001 there would pinch it): no trunk ends on the hand. Reason: Murray (Anatomy), design review 5.
- D43 joins: tributaries meet a trunk on one of its points where it runs along the flow, approaching obliquely (20-75 deg); a branch's r at the join is its own last r, not the trunk's. Reason: square-on joins (82-124 deg) and trunk r on branches made v1 and the first v2 draft fail Gates 6-7.

## Splice
R 0 (radial, + lat) joins R-A's radial end, R 1 its ulnar end, reversed, so the path runs R 0 -> arch -> R 1 with their far free flags; L 0 joins L-ceph's s -.30 end. Old points kept where s < -.40, bridged straight to s -.30, r linear across the bridge. R 2-9 and L 3-5 leave `_next` (archived with the live sets in phase 4); R 10-12 and L 1-2 verbatim.

## Gates (phase 3, per hand, numbers in `paths.txt`; angles, and any length given in m or mm, in the (s x span, lat) plane; other distances and r in chart; `gates.py` tags each fail `G<n>`)
1. Pack <= 160 (`VEIN_MAX`), counted as `ArmVeinSet.pack`: points + 1 per path + 2 per free end on a path over .036 chart, verbatim paths included.
2. Turn <= 25 deg at every interior point.
3. No centreline point inside a crest disc (around each `.01` head: index .0197, middle .0240, ring .0194, pinky .0172 m) or on a skin vertex (nearest) with finger or thumb weight >= 0.5; free ends and fork arms under 0.25.
4. Two paths not joined to each other, sampled every .001 chart: >= 2.26 (r_a + r_b) apart, samples within .012 of any join of either path skipped.
5. Cords: every sample >= r_cord(t) + r from each cord segment. r_cord is phase 4's cord r: r0 = 0.42 fr / 2.26 at t 0.5 when .004..008, else .006; r(0.5), r(1) = min(r0, spacing / 4.52), spacing = chart-v distance to the nearer neighbour cord at that t; r(0) = r(0.5), linear between (fit, r0 .006: R index .0035/.0060, middle .0034/.0060, ring and pinky .0031/.0054; L .0033/.0057, .0032/.0056, .0028/.0049). A run of band samples is allowed only if it holds a crossing at >= 30 deg; at most one crossing per cord per vein.
6. Join angle 20-75 deg between the branch's last segment (a cross-link's first segment at its split) and the trunk's downstream tangent at the join point (mean of the trunk segments either side; downstream = away from the arch apex toward the wrist, or along a tributary's flow).
7. Murray: ratio = r_J^3 / (r_up^3 + the sum of r^3 of every branch ending at J), r_up = the trunk's previous point upstream of the join point J; 0.7-1.3; cross-links exempt.
8. Trunk r never falls downstream; 8b: r at s -.30 and beyond >= the trunk's max on the hand.
9. Cover >= 6 skin vertices within 2.26 r per .004-chart slice (mesh only, with Gate 3's weights: spec 2).
10. Meander (D40, D47): in each path of 3+ points (cross-links, fork-arm points and the fork point aside) at least one interior point sits 2-5 mm off the segment joining its neighbours; every interior point whose neighbours are >= 18 mm apart does; none over 5 mm. (A point h off the midpoint of neighbours d apart turns 2 atan(2h/d), so Gate 2's 25 deg allows h <= .11 d: 2 mm needs d >= 18 mm; the v1 tributaries' 14.8 mm steps cannot carry it.) Checked again after any Chaikin pass.

## Fallbacks (once per failing point, after the redesign rounds; what is left goes to the stop rule, D46)
- Crest or weight: the point moves .004 m toward its valley or the hand centre; an arm point at weight >= 0.25 is dropped, an arm left under 4 mm is dropped (listed).
- Turn: Chaikin passes on that path (ends and join points kept, join indices re-mapped) until every turn <= 25 deg, at most 3, pack re-checked; if Gate 10 then fails, the path keeps its pre-Chaikin points and its turns are listed.
- Separation or band: the point moves .002 m away from the nearer neighbour, at most twice.
- Join angle: the join slides .01 chart downstream along the trunk (the branch's last point follows).
- Murray under 0.7 (D49): first the trunk from J downstream raised to r_J = (r_up^3 + sum r_b^3)^(1/3) (later points to max(own, r_J), keeps Gate 8) while r <= .006; else the branch's last two points scaled down to ratio 1.0 (min .0025, arms .0009); over 1.3: the trunk r at J lowered to 1.0 unless that breaks Gate 8, then listed.
- Cover: r x 1.25 up to .006.

## Set v2 status (veinfix writers, 2026-10-18)
Draft `hands-blender-review-04/sets.py` with the checker `gates.py` (copied from Temp/vg-hbr/veinfix, D45; run `py -3 sets.py -v` in that folder; `-p` prints the points). Chart fit from the survey: x = 1.1188 + .1655 s - .1226 lat, v R = .0578 - .0130 s - .5367 lat, L = -.0578 + .0108 s + .5002 lat (residual .011 chart, so the mesh gates may still fire). Not converged: before Gates 8b and 10 were coded, R 32 / L 34 failures (pack R 156, L 123: passes), mostly turns 25-67 deg at the fork stems and tributary roots, join angles 82-124 deg where tributaries meet the arch square-on (D43), separation at R-obl, R-W2 and L-W roots near their joins, L-RP and L-uln in the ring and pinky bands. With 8b and 10: R 62 (50 blocking), L 58 (46); 8b R 1, L 2; Gate 10 R 29, L 22 (mostly trunk points under 2 mm). Phase 3 spec 1 finishes it and writes the final table here as "Set v2". Round 3 and the Fallbacks ran: L converged (BLOCKING 0), R did not (2 blocking G4 fails, see `## Set v2`).

## Set v2
Final `py -3 sets.py` (round 3 plus the Fallbacks once; D46 stop rule reached): R FAILS 2, BLOCKING 2; L FAILS 2, BLOCKING 0. Pack R 160, L 125. R-obl joins R-A 3 (R-A 3 r .0041, Murray 0.75).

| path | points | r range | joins onto |
|---|---|---|---|
| R-A | 18 | .0032-.0048 | trunk (free both ends) |
| R-IM / R-IMb | 8 / 4 | .0010-.0027 / .0009-.0016 | R-A 7 / R-IM 3 |
| R-MR / R-MRb | 8 / 4 | .0010-.0028 / .0010-.0017 | R-A 10 / R-MR 3 |
| R-RP / R-RPb | 7 / 4 | .0010-.0026 / .0010-.0018 | R-A 11 / R-RP 3 |
| R-rad, R-uln, R-obl | 5, 4, 5 | .0014-.0027, .0015-.0024, .0018-.0032 | R-A 5, 12, 3 |
| R-W1, R-W2 | 3, 3 | .0015-.0022, .0014-.0021 | R-A 15, 1 |
| R-x | 3 | .0014-.0028 | from R-IM 5 to R-MR 7 |
| L-T | 24 | .0034-.0046 | trunk (free both ends) |
| L-IM / L-IMb | 6 / 4 | .0010-.0028 / .0009-.0016 | L-T 9 / L-IM 3 |
| L-MR / L-MRb | 6 / 4 | .0010-.0025 / .0010-.0018 | L-T 11 / L-MR 3 |
| L-RP / L-RPb | 6 / 4 | .0010-.0026 / .0010-.0017 | L-T 12 / L-RP 3 |
| L-uln, L-rad, L-W | 3, 3, 3 | .0015-.0025, .0014-.0026, .0015-.0026 | L-T 14, 7, 3 |
| L-x | 3 | .0013-.0026 | from L-MR 5 to L-RP 5 |

Remaining fails:
- R G4 R-A-R-obl short .0028 at s .168 / .12 (R-obl beside R-A at its join): BLOCKING.
- R G4 R-MR-R-x short .0025 at s .707 / .683: BLOCKING.
- L G6 L-uln join angle 88.7: exempt (join angles are listed for phase 6).
- L G6 L-rad join angle 84.7: exempt.

D53 Gate 4 join exclusion + D54 R-obl nudge: BLOCKING R 0, L 0. R-obl point 4 moved lat +0.0390 to +0.0380 (now (0.1113, +0.0380, 0.0031); other R-obl points unchanged; join R-A 3). Exempt fails as printed: `F G6 L-uln join angle 88.7`, `F G6 L-rad join angle 84.7`.

### Mesh redesign (D55, p3-d55b)
Optimiser `opt4.py` = opt3 with `check(..., mesh=MeshTable)` (Gate 3 weights, Gate 9 cover), FIXED points and penalties kept; 3 rounds (8 seeds per hand in parallel; 400 / 500 / 700 iterations, each from the previous best), best points spliced into `sets.py`. Offline mesh_table before Fallbacks: start R 71 / L 67 fails (BLOCKING 71 / 65); after round 1 R 49 / L 48 blocking, round 2 R 42 / L 38, round 3 R 33 / L 33. On the fit the spliced set is R FAILS 3 BLOCKING 1 (G4 R-A-R-obl sep short 0.0003, G2 R-MR 25.7, G6 R-IM 76.1), L 0 / 0: the mesh wins, the fit is only a proxy.
`arms.py veinpaths` (vp3, Fallbacks once): R FAILS 35 / BLOCKING 33 before, FAILS 11 / BLOCKING 9 after; L FAILS 33 / BLOCKING 33 before, FAILS 18 / BLOCKING 16 after. Stop rule D46: BLOCKING is not 0, so phase 3 blocks.
TALLY R G10 2 G2 5 G3 1 G5 2 G7 1; DENSITY R 48.5 cover@.006 76/434.
TALLY L G10 3 G2 2 G3 1 G5 3 G6 1 G8 6 G9 2; DENSITY L 11.0 cover@.006 5/325.
Exempt fails: R G2 R-A turn 25.9 at 6; R G2 R-MR turn 25.7 at 1; L G6 L-uln join angle 88.7; L G6 L-rad join angle 84.7.
Left blocking: R G2 R-IM turns 76.4 / 75.2 at 1, 2 and R-IMb 41.9; G7 Murray R-IM[1] 0.68; G5 R-IM index band by 0.0068, R-IMb by 0.0009; G10 R-A 7, 8; G3 R-rad 0 weight 0.92. L: G2 L-IM 44.5; G6 L-IM join 78.7; G5 L-IM, L-RP, L-x bands; G8 L-T r (6); G10 L-T 13, L-IM; G9 L-T slices 94, 97 cover 4, 5 < 6.

### Hand re-route (D56, p3-d56a)
Hand edits (MeshTable numbers): L-T r raised to .0060 at its wrist end (idx 0, 1, 21-23) and mid-ulnar run (idx 17-20), so Gate 8/8b hold and its slices 93-100 have cover (L-T cover fails 8 -> 1); then anneal rounds (`opt5.py` = opt4 with step sizes up to 6 mm) on the mesh table, 8 seeds per hand: offline blocking after the L-T edit R 33 / L 26, restricted hand pass (R-IM, R-IMb, R-x, R-A, R-rad / L-T, L-IM, L-IMb, L-RP, L-x) R 31 / L 24, round 1 R 26 / L 22, round 2 R 23 / L 20, round 3 R 22 / L 19. The R-IM entry did not get below the join angle 75 deg by hand; the optimiser did not find a route clear of the index band either.
`arms.py veinpaths` (vp4, Fallbacks once): R FAILS 22 / BLOCKING 22 before, FAILS 6 / BLOCKING 5 after; L FAILS 21 / BLOCKING 19 before, FAILS 6 / BLOCKING 4 after (vp3: R 11 / 9, L 18 / 16).
TALLY R G2 1 G3 1 G5 2 G6 1 G7 1; TALLY L G10 2 G2 3 G3 1.
Leftover for phase 6 (D56: not a blocker; each line is in `paths.txt` as LEFT / EXEMPT with the nearest skin vertex ids where the fail has a point): R G2 R-IM turn 62.8 at 1 (verts 29717, 29707); G6 R-IM join angle 79.7 (exempt); G7 Murray R-IM[0] 0.17; G5 R-IM index band by 0.0030 near (0.682, 0.017) (verts 29348, 29347); G5 R-IMb index band by 0.0006 near (0.919, 0.026) (verts 29939, 29938); G3 R-rad 0 weight 0.97 (verts 339, 1025). L: G2 L-T turns 25.1 at 10 and 26.6 at 15 (exempt; verts 9036, 22491 / 8040, 8043); G2 L-IM turn 51.3 at 3 (verts 4205, 9200); G10 L-IM 4 off 1.3 mm (verts 9212, 9211) and L-IM no meander point; G3 L-rad 0 weight 1.00 (verts 343, 1046).

### Optimiser rounds (D56b)
A parallel run (p3-d56a, commit 5c527d00) landed first with a better set (vp4 R 6 / 5, L 6 / 4 after Fallbacks), so this run's set was not kept. Its 3 opt4 rounds on the mesh table (8 seeds per hand, 1500 iterations, each from the previous best): offline blocking R 21 -> 15 -> 11 -> 11 (round 3 no gain), L 25 -> 21 -> 20 -> 20; `arms.py veinpaths` vp5 after Fallbacks R FAILS 7 / BLOCKING 4, L FAILS 9 / BLOCKING 7. Its leftover lines were not adopted for phase 6; use the D56 list above.

## Build decisions (auto, owner-delegated, 2026-10-18; plan review round 2)
- D45 (auto, owner-delegated): the draft and checker live in `hands-blender-review-04/` (Temp is not versioned). `gates.py` checks Gates 1-8, 8b and 10 on the fit; Gate 3's weights and Gate 9 need the mesh, so it takes a `mesh` object (`chart`, `weight`, `cover`; its docstring) that spec 2 supplies, re-running every gate on the mesh chart.
- D46 (auto, owner-delegated) stop rule: spec 1 runs at most 3 redesign rounds by D40-D43, then the Fallbacks once; spec 2 the Fallbacks once on the mesh. If only `blocking()`-exempt fails remain (turns <= 35 deg, join angles), keep the best set and list each (path, point, value; spec 2 adds the nearest skin vertex ids) in `paths.txt` for phase 6. Any other fail: no `_next` `.tres`, the phase is blocked for the owner. Reason: two writers ran out of context without converging; the loop needs an end.
- D47 (auto, owner-delegated): Gate 10 governs D40. Reason: D40's "every interior point" and the old Gate 10's "one point" differ, and the arithmetic in Gate 10 sets what the spacing allows.
- D48 (auto, owner-delegated) two specs: spec 1 data and checker only (`sets.py` edits, the table here), no Blender; spec 2 `arms.py veinpaths`. Reason: finishing the set alone filled a writer session.
- D49 (auto, owner-delegated) Murray: grow the trunk first, branch floor .0025 (.0015 halved the metacarpal veins: R-IM .0028 into R-A .0034 is ratio .64).

## Spec 2 (phase 3, moved from the plan for size)
- `arms_veinpaths_bl.py` imports copies of `gates.py` and the final `sets.py` as `tools/blender/arms_vein{gates,sets}.py` (pure Python, no bpy) and passes `check` a mesh object (D45).
- `chart(ob)` in `arms_frame_bl.py`: a port of the only chart function, GDScript `ArmVeinSet.chart_of` (`scripts/player/arms/arm_vein_set.gd`), with the UV unpacking of `Temp/vg-hbr/veinpaths/survey.py` (lines 54-58): c = (UVMap.002 u, 1 - its v, UVMap.003 u, 1 - its v) = CUSTOM0, x = c.x, v = 0.035 atan2(c.z, c.y), mask c.w. Phase 4 uses it too.
- Paint renders: back and side per hand in look's framing, on in-memory copies: veins red, h = w (r/.006)(1 - q^2)^2, q = d/(2.26 r); cords blue, r as Gate 5; before = today's paths.
