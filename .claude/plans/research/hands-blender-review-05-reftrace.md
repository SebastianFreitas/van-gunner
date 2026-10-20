# hands-blender-review 05 · vein trace from the owner's photo (2026-10-18)

Source: `C:/Users/Traff/AppData/Local/Temp/vg-hbr/ref/owner_fists.png` (owner: "does this work for u?", answered yes; D64). Read once by the phase-3 plan writer; nobody needs to open it again to design, only the spec 3 sheets show it.

**What it shows (one line):** two clenched fists, backs to the camera, knuckles up, thumbs touching in the middle, forearms running down to the bottom edge, black background, side light; image about 600 x 900 px, the left fist in x 0..300, the right in x 300..600.

**Which hand is which (D66):** in a back view a right hand has its thumb on the viewer's left. The photo's left fist has its thumb on its right (the middle of the image), so it is an anatomical LEFT hand; the photo's right fist is a RIGHT hand. Our L is traced from the photo's left fist, our R from its right fist, no mirroring (a stock photo, taken as not mirrored).

## Frame (normalised, per fist)
s: 0 at the dorsal wrist crease, 1 at the knuckle row (top of the knuckle heads), negative up the forearm in hand lengths (one hand length = the wrist-to-knuckle distance in the photo: L about 170 px, R about 180 px). lat: -1 thumb-side flank, +1 pinky-side flank, measured across the hand (or forearm) at that s. Width w: visible width (full width at half shading) as a fraction of the hand width at the knuckle row (L about 210 px, R about 190 px). Read once from a 600 x 900 photo: points are good to about +-.05 in s and +-.1 in lat, widths to about +-.005; the approval stop (D65) settles anything the owner reads differently.

## Our L (photo left fist): an uneven lambda, strong limb on the pinky side
- **L-main** (the clearest vein in the photo): (s, lat) (0, +.80) -> (.29, +.67) -> (.56, +.52) -> (.76, +.29) -> fork F (.88, .00). Rises diagonally from the ulnar wrist toward the middle knuckle; one long gentle curve (bows toward the pinky side by about .05 lat at s .4), no zig-zag. w .033 on s .1-.5, .028 at s .76, .022 at F.
- **L-Y** (the thin Y before the knuckles): two arms from F, arm 1 to (.96, +.12) (toward the middle/ring gap), arm 2 to (.95, -.15) (toward the index/middle gap); w .015 tapering to .008; both end free short of the knuckle heads (dive under).
- **L-thumbward** (the fainter second limb): from F down to (.62, -.33) -> (.41, -.48), fades out (free end, dives under) well before the wrist. w .020 at F, .012 at its end. Straight, no meander.
- Faint pinky-side twig (low confidence): a short branch off L-main at (.65, +.45) toward (.85, +.55) (the ring/pinky gap), w about .010, free end.
- Wrist and forearm: L-main runs on from the ulnar wrist down the ulnar edge of the forearm: (-.29, +.75) -> (-.65, +.40) -> (-1.0, +.30), w .035. A faint radial rope runs on the thumb side from about (-.3, -.70) to (-1.5, -.40), w .025. The lower forearm (s -1.0..-1.9) shows two diagonal ropes running down toward the ulnar edge, about .25 lat apart, (-1.0, +.30) -> (-1.47, +.65) -> (-1.88, +.90) and (-1.35, -.10) -> (-1.88, +.35), linked by one diagonal cross-branch near s -1.3 (a loose ladder); w .030-.040, tapering toward their ends.

## Our R (photo right fist): a smooth back, veins at the wrist
- **R-diag** (faint): (0, +.42) -> (.19, +.16) -> (.36, -.11) -> (.50, -.26), fading out (free end) by mid-hand toward the index metacarpal. w .020 at the wrist to .010 at its end. Straight, no fork; nothing visible between s .55 and the knuckle row (knuckles, tendons and a bony highlight near (.40, -.05) only).
- **R-knot** (the strongest feature): just below the wrist on the pinky side, a short branching knot: (-.03, +.79) -> fork (-.22, +.68); arm 1 (-.47, +.47) -> (-.92, +.42) -> (-1.58, +.45), a long, gently snaking rope down the middle-ulnar forearm (bends of about .05 lat every .5 s); arm 2 (-.47, +.95) along the ulnar edge, fading by s -.8. R-diag's wrist end meets the knot's top. w .035 at the knot, .030 on the rope, tapering to .020 by s -1.5.
- Radial forearm: one faint rope on the thumb side (-.3, -.60) -> (-1.4, -.45), w .020, linked to the arm-1 rope by one diagonal cross-branch near s -1.0 (a ladder rung, w .018).

## How the two arms differ
L carries the hand-back vein (a long diagonal limb from the ulnar wrist to a thin Y before the middle knuckle, with a fainter limb back toward the thumb side), and its ladder sits low on the forearm. R's back is nearly smooth (one faint diagonal that fades by mid-hand); its veins gather in a branching knot just below the wrist on the pinky side and run down the forearm as one long snaking rope, with a faint radial rope and one rung. Neither has a trunk pair, a symmetric arch or stubby forks; every vein is 1-4 % of the hand width, tapers to its ends and reads by its shading, not its width. Note for the approval stop: traced faithfully, our R back carries only R-diag (sparse); the owner may ask for L's lambda on R too.

## Mapping onto our hands (D67)
- s: on the hand (0 <= s_n <= 1) s = s_n x K(lat), K = the knuckle-row s interpolated piecewise linearly in lat over the four heads (research 04 Measured: index .953 at +.0526, middle 1.0 at 0, ring 1.009 at -.0507, pinky .842 at -.0918; held flat outside), lat from a first pass at s = s_n; below 0, s = s_n (hand-length units = the span .1649).
- lat (metres, `hand_frame`, + = index/thumb side): lat = c(s) - n h(s), c and h the centre and half-width of the dorsal skin at that s: 2nd and 98th percentile lat of the mesh table's dorsal skin vertices (dorsal normal > .3, thumb weight `tw` < .5) within |s' - s| < .03 (the D75 re-dump `Temp/vg-hbr/p3/d77/mesh_{R,L}.json`, research 04 `mesh_table.py`). Never filter on `wmax`: it is max(finger, thumb) and would drop the knuckle row, shrinking W_k and every width. Points below the skin's lowest dorsal s + .05 are dropped and listed for the owner stop.
- r (chart): w_vis = w x W_k (W_k = our knuckle-row width 2 h(.95), metres); r = w_vis / 4.53, because the (1 - q^2)^2 profile, q = d / (2.26 r), is at half height at d = 1.22 r chart and chart v runs about .54 per metre of lat, so its full width at half height is 4.53 r metres. Linear in r between the listed widths; free ends taper to .6 x their last listed r over the last 10 % of the path. (w .033 on a .15 m hand: r about .0011.)
- Points: the listed points with a Catmull-Rom spline through them, sampled every .04 s; no meander added beyond the bends listed above.
- Point to chart: the existing `VeinMesh` IDW (kept).

## Mesh resolution (D76)
D6 adds no vertex, so no subdivision. Spec 2 prints per path and per 0.1 s the mean skin edge (from the dumped `edges`) within w_vis of the path beside w_vis. Where the edge exceeds w_vis (L-main's ulnar wrist and s .3-.5, research 04 Measured: 5-19 mm): (1) each sampled point there snaps to the nearest skin vertex within the photo's tolerance (+-.05 s, +-.1 lat), repeats dropped, so the crest rides on vertices; (2) r there widens to the mean edge / 4.53 (w_vis = the edge), linear back over .1 s. Every such stretch is listed (path, s range, edge, w_vis) in the owner stop's Blocker. Phase 4 raises the snapped, widened path.

## Joins and the Splice (D68, D73, D77)
The traced forearm polylines are built (D73), so `_next` = R 10-12 palm and L 1-2 verbatim plus the trace; every old dorsal path (R 0-9, L 0, L 3-5) leaves `_next` and the D60 bridge goes (nothing old continues). Joins, all inside the trace, by sharing a point exactly:
- L: L-main is one path from its forearm end (-1.0, +.30) through the ulnar wrist to F; L-Y arms 1 and 2 and L-thumbward start at F's point; the twig starts at its L-main point (.65, +.45). Ladder rope A continues L-main from (-1.0, +.30) (same path); rope B and the radial rope have two free ends; the ladder rung is a 2-point path from rope A's point nearest s -1.3 to rope B's point nearest s -1.3, w .030.
- R: R-knot's trunk (-.03, +.79) -> fork (-.22, +.68) and arm 1 down to (-1.58, +.45) are one path; arm 2 starts at the fork point and ends free at s -.8; R-diag's first point is the knot's top (-.03, +.79); the radial rope has two free ends; the R rung is a 2-point path from arm 1's point nearest s -1.0 to the radial rope's point nearest s -1.0, w .018.
- No path crosses the hand back from one flank to the other (the rejected U arch, D63).

## Practical gates (D69; every other gate dropped)
- G-a off nails and claws: every point's nearest vertex in the (s x span, lat) plane, over the dumped skin, `fingers` and `webs` vertices (D75), is a skin vertex, and s_n <= 1.
- G-b off the knuckle crest tops: every point at least crest disc + w_vis / 2 from each head in the (s x span, lat) plane (discs: research 04 Measured).
- G-c clean deformation: every free end and Y-arm end at finger/thumb weight < .25 (`VeinMesh` weight).
- G-d splice: each join shares its point exactly with the path it joins; where one path continues another (rope A after L-main, arm 1 after the trunk) r steps <= 15 %; a branch starts at its own listed width; pack <= 160 per hand.
- Fallback, once per failing point: slide it along its path toward the wrist (G-a, G-c) or out of the disc along the head-to-point line (G-b) by the smallest move that passes; still failing, listed by name and vertex id for the approval stop. Pack over 160: the stretches below s -.4 resample every .06 s, once. No redesign rounds.

## Renders (spec 3)
True width: `arms_veinpaint_bl.py`'s trace mode without the .0025 minimum half-width and without centreline dots. Before writing `_next`, render the rejected set from the current `vein_set_*_next.tres` (= tag `archive/hands-veins-optimiser`) as `rejected_<R|L>_back.png`. Sheet per hand `sheet_<R|L>_back.png`: the photo's fist (L: x 0..300, R: x 300..600) | the traced set | the rejected set, all three framed on s -1.9..1.1 (D72: the photo's extent, forearm included; the photo crop placed and scaled by its own wrist crease and knuckle row onto the same s range). `arms_veinpaint_bl.py` takes the s range per call; the look and its before/after paint renders keep -0.2..2.2.

## Kept modules (D74)
`arms_veingates.py` and `arms_veinsets.py` stay unchanged: `arms_veinpaint_bl.py` imports `arms_veingates` (`cords`, `ORDER`, `chart` for the cord overlay), `arms_veindump_bl.py` imports `arms_veinsets` (`apply`, `side_R`, `side_L` for its 20 proof samples), and `arms_veintrace.py` takes `SPAN` and `HEADS` from `arms_veingates`. Only `arms_veinpaths_bl.py` stops calling their gates and sets.

## Dump (D75)
`arms.py veindump` (`arms_veindump_bl.py`; `VeinMesh.__init__` keeps its local `fw`, `tw` as attributes) adds per skin vertex `fw` and `tw`, the skin `edges` (vertex index pairs) and per `<side>_{fingers,webs}` vertex its (s, lat) in `hand_frame`; written to `Temp/vg-hbr/p3/d77/`.

## Decisions after the plan review (D71-D77, auto, 2026-10-18; `.claude/specs/reports/plan-reviewer-reftrace.md`)
- D71 · Owner stop: phase 3 ends `Status: blocked`, row 3 `todo (awaiting owner approval)`; approval marks it done, a change runs one fix round of phase 3. Reason: a Blocker without `Status: blocked` never stopped the run.
- D72 · Sheets framed on s -1.9..1.1. Reason: the look framing (-0.2..2.2) cuts R's knot, R's rope and L's ladder, so the owner could not judge R.
- D73 · The traced forearm veins are built and raised in phase 4; old R 0, R 1, L 0 retire. Reason: the forearm ladder is the photo's strongest feature, the goal is buff monster arms, and the owner sees them on the sheet and can strike them there.
- D74 · `arms_veingates`/`arms_veinsets` kept. Reason: two kept scripts import them.
- D75 · Re-dump with `fw`, `tw`, `edges` and the finger/web vertices. Reason: the d55 table holds only `wmax` and skin vertices, so the thumb filter and G-a could not run.
- D76 · Snap and widen where the edge exceeds the vein, no subdivision. Reason: D6 forbids added vertices; a 5 mm vein on 5-19 mm edges would raise as blobs.
- D77 · Joins inside the trace, stated per path. Reason: with the old ropes retired the old rule left R's radial rope nothing to join and split R 0 / R 1 by guess.
- D60 (old-rope bridge) is superseded by D73; D61 (paint w = 1 - finger weight) stays; D57-D59 were never used.
