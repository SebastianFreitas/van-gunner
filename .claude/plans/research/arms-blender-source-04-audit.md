# arms-blender-source 04: wrist weights, seam, width audit (phase 4 spec 1, stopped at step 1)

`arms hands` rows, R / L. Steps 2 and 3 are in `EDITS` but switched off ("on": False): not measured, phase stopped.

    row            | before            | after wrist_mirror (band -0.25..0.5) | band -0.25..1.0
    R W0..8        | .075 .080 .086 .093 .100 .101 .104 .098 .094 | same | same
    L W0..8        | .060 .073 .081 .091 .098 .101 .104 .098 .094 | same | same
    jump R/L       | 3.18 / 3.04       | same | same
    dome R/L       | .379 / .352       | same | same
    palm_depth R/L | .486 / .499       | same | same
    wrist_step R/L | .000 / .036       | same | same
    wrist/palm R/L | .819 / .789       | same | same

Step 1 changed 23 L vertices (band to 0.5) and 55 (band to 1.0), unmatched 0 (all L vertices have an R partner within 1e-4).
Result: L W0 stays .060, short of .070. Fallback (band widened once) fired, still short: stop.

Finding: the glb's L vertex weights in the band already equal R's mirror partner's, vertex for vertex (the coarse mesh has
only about 3 verts near slab 0; printed weights identical before and after). So the L W0 gap is not in the source weights; look at
what `ArmBulk.inflate` does with the L hand (refine adds verts, per-bone geometry, rest bones) or at L/R bone rests.

Step 2 note: radius 0.06 x DEF-forearm.?.001 length (0.2524) = 0.0151; the nearest vertex to the DEF-hand head is 0.0362 away,
so `seam_smooth` selects 0 vertices on both arms as specified (a no-op).

Step 3 (`width`) moves 54 verts per arm (110 with the one-ring); built once together with the others, not measured on its own.

Naming pitfall met: weight groups look like `DEF-forearm.R.001`, so the .R to .L rename needs a token regex, not a suffix test.
After a build run `py -3 tools/check.py` before `arms hands`, otherwise the probe reads the stale import.

## Left wrist (D56)

Cause: not a load step. `DebugArmsHands._shape` (`scripts/debug/debug_arms_hands.gd:148-154`, old) took each vertex's largest weight and counted it when that bone was `DEF-hand` or a `DEF-palm*`. At the thumb side of slab 0 the weights sit on a three-way tie (forearm .34, palm.01 .34, thumb.01 .31); R's mesh is cut far finer there (2300 slab-0 vertices against L's 576, the per-arm vein relief), so R has vertices on the palm side of the tie at lat -0.070 and L has none (its nearest, v7843, is at -0.042). The glb vertices match one to one (R v1153 and L v1153 have identical weights; every unrefined pair checked matched), so the game's weights and gains are side-symmetric and no load step (`ArmRefine.refine`, `ArmWeightSmooth.apply/weld`, the `hand_gain` loop) was changed.

Diagnosis table (slab 0, weights per vertex, hand-weighted by the old pick vs by hand+palm weight share):

| pick | R W0 | L W0 | R hand verts | L hand verts |
|---|---|---|---|---|
| old: largest weight is hand/palm | .075 | .060 | 548 | 19 |
| share >= .30 (new) | .075 | .074 | 1622 | 351 |
| share >= .35 | .075 | .074 | 1376 | 293 |
| share >= .50 | .065 | .060 | 665 | 109 |

Fix: `_shape` counts a vertex when its hand + palm weight is at least `HAND_SHARE` 0.30 of its total (no tie, no mesh-density dependence). Only the probe changed; no game code.

`arms hands` rows after, R / L (only these moved; every other row, `tip_off` and `claw_len` included, is identical):
- growth W0..8: R .075 .085 .093 .099 .105 .101 .107 .104 .094 (was .075 .080 .086 .093 .100 .101 .104 .098 .094); L .074 .078 .091 .094 .105 .101 .107 .104 .094 (was .060 .073 .081 .091 .098 .101 .104 .098 .094)
- jump: R 4.34 (was 3.18), L 5.54 (was 3.04)
- dome / palm_depth: R .363 / .509 (was .379 / .486), L .329 / .510 (was .352 / .499)
R moved up to .008 because the old pick mis-measured it too (it also dropped thumb-side tie vertices). Raw: `Temp/vg-p4/hands_wrist.txt`.

## Width (spec 1 step 2)

Step `width` on (54 verts moved per arm, 110 in the normals ring). Targets missed; step left on with the last f, fallback fired.

- Try 1, f = 1 .924 .878 .855 .831 .887 .856 .909 1 (D58): R wrist/palm .900, L .869, pinky knuckle .30/.29 (ROW CHECK), mono false, jump R 3.96 / L 7.57.
- Fallback (D40, f x= T/R W): f = 1.014 .895 .824 .804 .772 .903 .825 .924 1.056: R wrist/palm .888, L .857, pinky knuckle .29, jump R 3.59 / L 6.50.
- f7 raised to 1.0 (the limit): f = 1.014 .895 .824 .804 .772 .903 .825 1.0 1.056. Final.

Final `arms hands` rows, before (hands_wrist.txt) then after (hands_width3.txt):
- growth W0..8 R: .075 .085 .093 .099 .105 .101 .107 .104 .094 then .073 .080 .084 .087 .091 .086 .095 .095 .092; mono false both; jump 4.34 then 3.74
- growth W0..8 L: .074 .078 .091 .094 .105 .101 .107 .104 .094 then .071 .067 .083 .078 .091 .086 .095 .095 .092; jump 5.54 then 5.85
- wrist/palm R .819 then .861, L .789 then .832 (band .70...85; R out)
- palm half .0973 then .0926; r1/palm and dome change with it
- knuckle R/L: index .37 then .40, middle .39 then .39, ring .41 then .39, pinky .36 then .39 (all in band)
- wrist_step R .000 then .019, L .036 then .016
- tip_off, claw_len, gaps, knots: unchanged within 0.002 (gap1 shifts by <= .005).
The jump is driven by the early slabs (W1/W2 L .067/.083, W3 .078): the forearm-end verts barely move with f, so a lateral scale cannot lift W0..W2 to the target ramp. Raw: `Temp/vg-p4/hands_width{,2,3}.txt`.

Afterwards the supervisor switched `width` back off (`"on": False`, final f kept in the table) and rebuilt: `arms.glb` is again byte-equal to the no-edit build, `arms hands` equals `hands_wrist.txt` (HANDS OK), CHECK CLEAN. The phase is blocked: see the state file's Blocker.

## Probe p95 (D59)

Method: slab membership unchanged (hand + palm weight share >= 0.30). W_k is now the |lateral offset| where the cumulative vertex weight (a third of the area of its adjacent triangles, bind arrays) first reaches 0.95 of the slab total. `mono` and `jump` run over slabs 0..7 only (jump over (W7 - W0)/7); W8 is still printed.

`arms hands` rows that changed, before (hands_wrist.txt) then after (hands_p95.txt); every other row is identical:
- R growth W0..8: 0.075 0.085 0.093 0.099 0.105 0.101 0.107 0.104 0.094 mono false jump 4.34, then 0.074 0.081 0.088 0.093 0.107 0.115 0.111 0.107 0.099 mono false jump 3.12
- L growth W0..8: 0.074 0.078 0.091 0.094 0.105 0.101 0.107 0.104 0.094 mono false jump 5.54, then 0.079 0.077 0.093 0.093 0.107 0.115 0.112 0.107 0.099 mono false jump 4.00
- R dome 0.363 palm_depth 0.509, then 0.355 and 0.497
- L dome 0.329 palm_depth 0.510, then 0.321 and 0.497
- wrist/palm R 0.819, L 0.789, knuckle rows: unchanged (they do not read W).
- Sanity: L vs R differ by 0.005 on W0 and W2, 0.004 on W1; not tuned.

## Width, D59 ramp

Probe slabs match the step (knots at s = k/8, probe slab +-1/16 thick). Targets T_k = W0 + (W7-W0)(1-(1-k/7)^1.5) on R's no-edit W (`hands_p95.txt`).
- T k0..7: .074 .0808 .0871 .0927 .0977 .102 .1052 .107
- f first try (k0..8): 1.0 .998 .99 .997 .913 .887 .948 1.0 1.0
- f after D40 fallback (f_k x= T_k / measured R W_k, clamp 1): 1.0 .998 .99 .997 .866 .845 .948 1.0 1.0
- wrist/palm fallback: not needed (R .840 first try).

| row (W0..8) | before R | before L | first try R | first try L | fallback R | fallback L |
|---|---|---|---|---|---|---|
| W | .074 .081 .088 .093 .107 .115 .111 .107 .099 | .079 .077 .093 .093 .107 .115 .112 .107 .099 | .074 .080 .086 .090 .103 .107 .105 .102 .099 | .079 .076 .091 .090 .103 .107 .105 .102 .099 | .074 .075 .090 .088 .101 .105 .103 .102 .099 | .079 .076 .090 .088 .101 .105 .104 .102 .099 |
| mono / jump | false 3.12 | false 4.00 | false 3.25 | false 4.37 | false 3.73 | false 4.21 |
| wrist/palm | .819 | .789 | .840 | .811 | .840 | .811 |
| knuckle (all 4) | .37 .39 .41 .36 | same | .37 .39 .41 .38 | same | same | same |

HANDS OK both runs. Result: mono and jump still out (the peak W5 sits only ~.003 above W7, and slab 7 loses width because the f6/f7/f8 interpolation overlaps its +-1/16 band). `width` switched back off, rebuilt: probe equals `hands_p95.txt`. L's wrist slab (W1 < W0, .077 < .079) fails mono before any edit.

## Width diagnostic (p4-3)

Probe warning fixed (`_p95` local `run` renamed `acc`), CHECK CLEAN. Temporary per-slab output (reverted). Columns per slab k: n = vertices the probe counts, area = their summed area, thumb% = share of that area whose largest weight is a `DEF-thumb*` bone, W = probe W_k, Wno = W_k with those left out.

Width off (no-edit build), R / L:

| k | R n | R area | R thumb% | R W | R Wno | L n | L area | L thumb% | L W | L Wno |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 1621 | .00662 | 1.5 | .074 | .074 | 350 | .00648 | 0 | .079 | .079 |
| 1 | 1940 | .00903 | 17.3 | .081 | .081 | 462 | .00699 | 9.0 | .077 | .069 |
| 2 | 1367 | .00898 | 15.2 | .088 | .088 | 286 | .00956 | 18.3 | .093 | .093 |
| 3 | 1162 | .00838 | 8.4 | .093 | .093 | 165 | .00784 | 10.8 | .093 | .093 |
| 4 | 1106 | .00776 | 15.9 | .107 | .107 | 237 | .00743 | 17.4 | .107 | .107 |
| 5 | 1076 | .00805 | 0 | .115 | .115 | 663 | .00805 | 0 | .115 | .115 |
| 6 | 1410 | .01198 | 7.1 | .111 | .112 | 1469 | .01135 | 7.5 | .112 | .113 |
| 7 | 2228 | .01030 | 2.7 | .107 | .107 | 2319 | .01025 | 2.8 | .107 | .107 |
| 8 | 2430 | .01171 | 0 | .099 | .099 | 2365 | .01180 | 0 | .099 | .099 |

Width on, D59 first-try f (`1 .998 .99 .997 .913 .887 .948 1 1`), build "moved 54" per arm, CHECK CLEAN:

| k | R n | R area | R thumb% | R W | R Wno | L n | L area | L thumb% | L W | L Wno |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 1621 | .00661 | 1.6 | .074 | .074 | 350 | .00646 | 0 | .079 | .079 |
| 1 | 1937 | .00898 | 17.4 | .080 | .080 | 462 | .00701 | 9.0 | .076 | .069 |
| 2 | 1371 | .00887 | 15.6 | .086 | .086 | 290 | .00942 | 18.8 | .091 | .091 |
| 3 | 1163 | .00822 | 9.1 | .090 | .090 | 163 | .00764 | 11.5 | .090 | .090 |
| 4 | 1105 | .00758 | 17.5 | .103 | .103 | 226 | .00729 | 19.1 | .103 | .103 |
| 5 | 1068 | .00769 | 0 | .107 | .107 | 655 | .00760 | 0 | .107 | .107 |
| 6 | 1445 | .01175 | 7.5 | .105 | .105 | 1475 | .01114 | 7.9 | .105 | .106 |
| 7 | 2150 | .01009 | 3.1 | .102 | .102 | 2328 | .01004 | 3.2 | .102 | .102 |
| 8 | 2429 | .01163 | 0 | .099 | .099 | 2357 | .01171 | 0 | .099 | .099 |

Also (on): share of slab 4..6 vertices whose largest weight is not hand/palm is 0 to 17 percent, all thumb at k4.

Verdicts:
- R: not thumb-dominant vertices. Thumb vertices are 0 to 17 percent of area at k4..6 (0 at k5) and leaving them out moves W by at most .001. The bulge is hand/palm vertices the step does move, but only 54 source vertices (the coarse Blender mesh); the probe reads the inflated, refined mesh, and the realised drop is smaller than the f asked: W4 .107 to .103 (asked .098), W5 .115 to .107 (asked .102), W6 .111 to .105 (asked .105, met). So the inflate/refine added width beyond what a lateral scale of the source mesh removes at k4, k5.
- L: same: thumb share 0 to 19 percent, W unchanged by dropping it (k1 .077 to .069 is thumb-dominant, a wrist slab outside 4..6); the same shortfall (W4 .107 to .103, W5 .115 to .107). Same cause as R, not thumb vertices.
