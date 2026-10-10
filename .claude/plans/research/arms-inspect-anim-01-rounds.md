# arms-inspect-anim rounds

## Round 0 · old root-offset keys

Capture: `py -3 tools/shots.py capture inspect-before` (126 views, smoke clean, in `.godot/shots/inspect-before`).
Command: `py -3 tools/anim_series.py --cmd "arms inspect {t}" --region 0.2,0.2,1,1 --out <TEMP>/series/p1-r0-<x>`.

- a, `--times 0.1:0.7:7`: ANIM SERIES JUMPY: 1,2,3,4,5,6 (min 14.91%, max 63.71%, mean 31.84%, dead none).
- b, `--times 1.5:2.0:6`: ANIM SERIES JUMPY: 1,2,3,4,5 (min 9.56%, max 35.71%, mean 18.17%, dead none).
- c, `--times 2.8:3.4:7`: ANIM SERIES FLAT+JUMPY (min 0.00%, max 10.81%, mean 4.17%, dead 4,5,6, jumps 1,2).

### Old key tables (archive, removed in 6b4a122)

```gdscript
## Keys of t (s from start), pos (rig-space root offset, virtual metres: camera at origin,
## -Z forward, +X right, +Y up) and rot (degrees: x pitch, y yaw, z roll about the forward axis;
## roll applies first, then pitch, then yaw).
const RIGHT_KEYS: Array[Dictionary] = [
	{&"t": 0.0, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
	{&"t": 0.30, &"pos": Vector3(-0.25, 0.22, 0.30), &"rot": Vector3(0, 70, 0)},  # gun's left side to the eye
	{&"t": 0.50, &"pos": Vector3(-0.25, 0.24, 0.30), &"rot": Vector3(5, 65, 10)},
	{&"t": 0.75, &"pos": Vector3(-0.25, 0.22, 0.30), &"rot": Vector3(0, 70, 150)},  # rolled over: the right side
	{&"t": 0.92, &"pos": Vector3(-0.25, 0.24, 0.30), &"rot": Vector3(5, 65, 140)},
	{&"t": 1.12, &"pos": Vector3(-0.30, 0.10, 0.20), &"rot": Vector3(-30, 45, -50)},  # forearm swept across, inner side up
	{&"t": 1.28, &"pos": Vector3(-0.10, 0.05, 0.12), &"rot": Vector3(-20, 25, 30)},  # rolled back, sweeping out
	{&"t": 1.45, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
]

## Same format as RIGHT_KEYS, for the left arm root.
const LEFT_KEYS: Array[Dictionary] = [
	{&"t": 1.35, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
	{&"t": 1.60, &"pos": Vector3(0.55, 0.45, 0.30), &"rot": Vector3(70, 0, -80)},  # hand up, back of the hand to the eye
	{&"t": 1.80, &"pos": Vector3(0.55, 0.47, 0.30), &"rot": Vector3(70, 5, -70)},
	{&"t": 2.05, &"pos": Vector3(0.55, 0.45, 0.30), &"rot": Vector3(70, 0, 80)},  # turned: the palm
	{&"t": 2.25, &"pos": Vector3(0.55, 0.47, 0.30), &"rot": Vector3(70, -5, 70)},
	{&"t": 2.50, &"pos": Vector3(0.75, 0.25, 0.10), &"rot": Vector3(-10, -45, 80)},  # forearm laid across, inner side up
	{&"t": 2.72, &"pos": Vector3(0.45, 0.25, 0.10), &"rot": Vector3(-10, -45, -80)},  # rolled: the outer forearm and its tattoo
	{&"t": 3.00, &"pos": Vector3(0, 0, 0), &"rot": Vector3(0, 0, 0)},
]
```

## Round 1 · IK path (phase 1)

Smoke clean (`py -3 tools/smoke.py`, VAN AUDIT CLEAN). Capture `p1-after`; `shots.py compare inspect-before p1-after`: SHOTS SAME (126 views); `11-rear-park-stop-back` diff=0.408 tol=0.980, `a01`..`a07` diff 0.001-0.056 tol=1.000, all same.

Probe lines (`INSPECT_PX L`):
- 1.1: wrist 800,606 tip 1178,493 hand 960,546 band 848,887 z 0.955 r 0.202 letter 367.6 px elbow 86 deg palm_dot -0.95 face_dot 0.79
- 2.3: wrist 800,606 tip 1284,73 hand 929,491 band 848,887 z 0.955 r 0.202 letter 367.6 px elbow 86 deg palm_dot 0.96 face_dot -0.57
- 4.0: wrist 1043,334 tip 1583,330 hand 1205,223 band 998,633 z 0.878 r 0.202 letter 399.7 px elbow 122 deg palm_dot -0.51 face_dot 0.96
- Letter px 370-400 by the probe formula (plan wanted >= 27): recorded only.

Fallbacks the tuner applied:
- D40 (auto): `ROLL_B4_DEG` -> -45, face 0.43 -> 0.95.
- D41 (auto): shoulder slide 0.07 less, S' (-0.737, -0.737, -0.569), elbow 113 -> 125.
- D42 (auto): `WRIST_B4.y` 0.113 -> 0.086, band y 596 -> 633.

HUD counts 0/0/0.

Series (`--region 0.2,0.2,1,1`, jump bar 0.06):
- a `0.1:0.7:7`: JUMPY 1-6, min 15.71%, max 24.98%, mean 21.19% (round 0: max 63.71%).
- b `1.5:2.0:6`: JUMPY 1-5, min 15.24%, max 22.97%, mean 17.99%.
- c `2.8:3.4:7`: JUMPY 1-6, min 19.07%, max 25.98%, mean 23.23% (round 0 had dead 4,5,6; none now).
- D (auto): every step is over the 0.06 bar, but steps are uniform (no step more than twice both neighbours), so no pop and no key edit. Doubled steps (14/12/14) once: min 11.16/5.20/12.42%, max 19.03/20.31/20.64%, still uniform. The bar is a fast-motion bar, not a pop.

Stills (not opened): `C:/Users/Traff/AppData/Local/Temp/p1/stills/insp-1.1.png`, `insp-2.3.png`, `insp-4.0.png`, and `.../stills/cam/left.png`, `front.png` (at 4.0).

- Worse: nothing measures worse than round 0; every series is no longer flat and its max step fell from 63.71% to 25.98%. The tip at 2.3 sits at y 73 (near the top edge), unjudged by eye; the band at 4.0 is at y 633.
- Why: the series bar (0.06) is below the natural per-step motion of a 0.1 s inspect, so JUMPY stays even with a smooth path.
- Solve: later phases judge by pop (a step more than twice both neighbours) and the look-judge stills, not by the JUMPY verdict.

- Round 1 repeatability (spec p1-5): no per-run or per-frame state found, no code change. `arms inspect 3.6` twice: 0 px (0.000%) differ; with 120 frames instead of 10: 329 px (0.025%); 3.6 vs 4.0: 110 px (0.008%); at 3.0 twice 0.008%, 10 vs 120 frames 0.059% (settling only, no growth). Cause of JUMPY: real motion, not noise: the keys move fast (the roll 180 to -45 over 2.8..3.4 peaks near 750 deg/s, so 0.0075 s at t 3.0 is 3.3% of the region), and 2.8:3.4:7 ends at 3.314, short of the hold at 3.40. Hold steps: 3.450->3.525 is 0.01%.
- Verdicts r1b: a (0.1:0.7:7) JUMPY min 15.76% max 24.94%; b (1.5:2.0:6) JUMPY min 15.24% max 22.98%; c (2.8:3.4:7) JUMPY min 19.08% max 25.98%. Probes unchanged: 1.1 hand (960,546) elbow 86 palm -0.95; 2.3 palm 0.96; 4.0 band (998,633) elbow 122 face 0.96.

### Look fallback

Spec p1-6. Gesture-interrupt pop: `_inspect.step` now runs above the `_gesture` block in `gun_viewmodel.gd`, so the inspect's one restore no longer overwrites the gesture's first solve; `_apply` still follows and reads this frame's offsets. The probe line gained `strip top/bottom` (band +- half `tat_width` along the forearm, projected).
- D44 (auto): hand_dir at beat 4 -> (0.95, 0.31, 0) (`HAND_DIR_B4`, held at B2 until 2.80).
- D45 (auto): `WRIST_B4.y` 0.086 -> -0.004; strip top 467 -> 581 (needs >= 575), bottom 917.
- D46 (auto): beat 4 shoulder slide 0.08 less (`SHOULDER_B4` (-0.791, -0.791, -0.545), B2 untouched): elbow 112 -> 125.
- Probes after: 1.1 hand (960,546) elbow 86 palm -0.95 (unchanged); 2.3 palm 0.96 (unchanged); 4.0 wrist 1047,449 hand 1225,378 band 977,746 elbow 125 face_dot 0.96 strip 581..917.
- HUD PIL count x 24..292, y 912..1056 vs `arms inspect off`: 1.1 0, 2.3 0, 4.0 0.
- Series c `2.8:3.4:7`: min 18.18%, max 24.79%, mean 22.63%, steps 22.58/18.18/22.67/24.79/24.58/22.97; JUMPY by the bar but uniform, no pop.
- Check CLEAN, smoke CLEAN. Stills refreshed (not opened): `stills/insp-1.1.png`, `insp-2.3.png`, `insp-4.0.png`, `stills/cam/left.png`, `front.png`.

### Phase 1 verdict

- D43 (auto): travel series JUMPY on every step (15-26 % of R per 0.1 s), uniform, no pop; pins repeat (0.000 % same t, 0.008 % inside the hold), so it is real fast motion; per Constraints a non-pop is D (auto).
- Reviewer gap fixed: `_inspect.step` runs before the gesture block (one-frame pop when a gesture interrupts).
- Look-judge 1 FAIL line 2 (sideways strip reaching above the crosshair, claw wrist); fallbacks D44-D46; look-judge 2 FAIL line 2: letters rotated 90 deg along the upright forearm, only a layout change fixes it. Line 1 PASS both times. Reports: %TEMP%/p1/look-judge.md, look-judge-2.md. Run blocked (Q1).


## Round 2 (phase 2)

Probe lines (`INSPECT_PX R`; twist is the change from the rest pose, 0 at t 0.0). Redone in spec p2-4: the right forearm twist is reset each frame (it built up before), and the probe now reads twist from rest; the same t twice gives the same line:
- 4.0: d/R 0.92 twist 0; L band 977,746 elbow 125 deg.
- 5.5: d/R 0.98 twist 6.
- 6.3: d/R 0.98 twist 2 (twice, identical).
- 7.5: d/R 0.92 twist 0.

Checks:
1. d/R at 5.5 and 6.3 is 0.98 and 0.98 (limit 1.0): pass. (The first probe draft mixed skeleton and root units and read 1.4 to 1.9; fixed in the probe.)
2. Twist from rest: 17 deg at 5.5 and 22 deg at 6.3 (limit 90): pass.
3. 4.0 L line band 977,746, elbow 125: unchanged from phase 1, pass.
4. Series (steps are even, none more than twice both neighbours, so no pop; the tool's JUMPY flag fires on every step of a fast beat at --jump 0.15, recorded): 4.9:5.4 steps 28 to 39 percent; 5.8:6.3 18 to 34 percent; 6.7:7.2 39 to 50 percent. Out: %TEMP%/p2/series/a, b, c.
5. Side still `arms inspect 6.3` (%TEMP%/p2/side/side.png): the right shoulder stays put at the lower right and the forearm shows no pinch.

Fallbacks applied: none (keys unchanged).

## Round 3 (phase 3)

p3-1: dip 0.05 unit before the lift; fingers key (30,30,30) spread over 3 joints; sway 2.5 deg failed stillness (7.29 / 7.55 % max), fallback 1.5 deg: still-a steps 3.71/1.03/2.40/4.55/4.66 %, still-b max 4.93 %, both `ANIM SERIES OK` but over the 1 % D34 bar; dip series 0:1.5:16 JUMPY steps 1-8, no pop.
p3-2: `w` ease out, release 0.30 s, cancel 0.15 s, gun snap on a shot, queued gesture; check and smoke clean at 549f1b0.

Measured at 549f1b0 (`--region 0.2,0.2,1,1`, out `%TEMP%/p3/series/<name>`):
- cancel `arms inspect cancel {t}` 0:0.15:6: ANIM SERIES JUMPY 1-5, min 10.00%, max 41.45%, steps 41.45/28.70/19.53/14.23/10.00 falling, no pop.
- full `arms inspect {t}` 0:7.2:37 `--dead 0.0005`: ANIM SERIES JUMPY (20 steps), min 0.57%, max 56.26%, dead none, no pop (holds 0.5-3.4 %, moves 15-56 %).
- gun `arms inspect {t}` 4.9:7.2:47 `--jump 0.15`: ANIM SERIES FLAT+JUMPY, min 0.25%, max 43.66%, dead 18 and 30 (the holds, 0.2-0.3 %), no pop (step 19 is 3.9 % between 0.2 and 13.2).
- Cancel position (R region x 384..1920, y 216..1080, threshold 12): `inspect 4.0` vs `cancel 0.15` 250300 px (18.86 %), vs `inspect off` 250297 px (18.86 %), ratio 100.0 %: FAILS the 20..80 % bar (cancel 0.15 is the end of the 0.15 s blend, so it equals off). Extra: cancel 0.075 vs 4.0 is 103.8 % of the off count.
- HUD PIL count (x 24..292, y 912..1056) at 4.0, 5.5, 6.3 vs off: 0 / 0 / 0.
- Stills (not opened): `%TEMP%/p3/stills/insp-4.0.png`, `insp-5.5.png`, `insp-6.3.png`, `cancel-0.15.png`, `cancel-0.075.png`, `cam-left-4.0.png`, `cam-side-6.3.png`.

- Worse: only the cancel ratio (100 % against 20..80 %); the series and HUD are fine.
- Why: the pinned cancel age 0.15 is the full blend length, so the still is already the rest pose; the bar needs a mid-blend age.
- Solve: measure the ratio at a mid-blend age (about 0.05 to 0.075) or widen the bar; no code change.

Look fallback: W_EASE smooth (D auto). Cancel series 0:0.15:6 `--region 0.2,0.2,1,1`: ANIM SERIES JUMPY 1-5, min 15.26%, max 37.01%, steps 36.67/37.01/30.01/21.60/15.26 falling, no pop. Stills (not opened): `%TEMP%/p3/stills2/cancel-0.075.png`, `cancel-0.04.png`, `cancel-0.11.png`.

## Round 4 (phase 4)

Measured at 6b06f2b (`--region 0.2,0.2,1,1`, out `%TEMP%/p4/series/<name>`), one run each; the numbers match round 3 (phase 4 changed only the smoke and the reach-end check):
- full `arms inspect {t}` 0:7.2:37 `--dead 0.0005`: ANIM SERIES JUMPY (20 steps), min 0.57%, max 56.26%, dead none, no pop in the steps seen (the tail 26-36 and wrap; the head was cut off the output).
- gun `arms inspect {t}` 4.9:7.2:47 `--jump 0.15`: ANIM SERIES FLAT+JUMPY, min 0.25%, max 43.66%, dead 18 and 30 (the holds), no pop in the steps seen (the tail 36-46 and wrap).
- still-a 3.4:4.9:6 `--dead 0.0005`: ANIM SERIES OK, steps 3.71/1.03/2.40/4.55/4.66 %, max 4.66%, under the D51 5 % bar: pass, no pop.
- still-b 7.4:9.0:6 `--dead 0.0005`: ANIM SERIES OK, steps 4.72/4.93/2.64/1.24/4.34 %, max 4.93%, under the 5 % bar: pass, no pop.
- cancel `arms inspect cancel {t}` 0:0.15:6: ANIM SERIES JUMPY 1-5, min 15.28%, max 37.01%, steps 36.67/37.01/30.01/21.61/15.28 falling, no pop.
- The first sequential run of all five timed out at 10 min during still-a; still-a, still-b and cancel were then run once each.

Smoke at cf68639: SMOKE CLEAN, a19-arms-inspect saved, REACH_END inspect pins 1.1/2.8/4.0/5.5/6.3 behind 0.23/0.23/0.12/0.33/0.33 OK (MIN 0.12 at 4.0, under the gesture samples' 0.30 m guide; record only). Shots: a19 tolerance 0.086 (noise 0.043); compare inspect-before vs p4-a/p4-b: only a19 new, plus 07-elevator-stop-front (0.140/0.106 in p4-a, same 0.068 in p4-b) and 08-elevator-stop-back (0.730/0.664 in p4-b, same in p4-a): run-to-run noise at the elevator stop, D52 (auto).

Last look check stills at 03cbf01 (spec p4-4, measurement only, not opened):
- Stills: `C:/Users/Traff/AppData/Local/Temp/p4/stills/` `insp-1.1.png`, `insp-2.3.png`, `insp-4.0.png`, `insp-5.5.png`, `insp-6.3.png`, `cancel-0.04.png`, `cancel-0.075.png`, `cancel-0.11.png`, `cancel-0.15.png`, `cam-left-4.0.png`, `cam-front-4.0.png`, `cam-side-6.3.png`, `rest.png` (`arms inspect off`). Taken with `probe.py --cmd "<line>" --shot <png>` (cam views with `--views left,front` / `side`).
- Size: `probe.py --shot` renders 1440x720 (`--resolution 1440x720`, stretch viewport/expand: viewport 2160x1080, scale 2/3), not 1920x1080. The HUD box x 24..292, y 912..1056 is therefore counted at x 16..195, y 608..704 (left/bottom anchored, scale 2/3), threshold 12 vs `rest.png`.
- HUD (PIL count): 1.1 100, 2.3 100, 4.0 100, 5.5 100, 6.3 100, cancel 0.04 100, 0.075 100, 0.11 590, 0.15 0 (expected 0 each). All 100 px are one block at x 177..195, y 695..704 (the box's bottom-right corner, identical at every hold, so likely the arm/gun edge entering the corner rather than HUD; 0.11 spreads to x 158..195, y 676..704); not looked at, the box mapping is approximate. Not 0.
- Tattoo letter at 4.0: `INSPECT_PX L` letter 401.4 px (wrist 1047,449 band 977,746 elbow 125 deg face_dot 0.96 strip 581..917; record only, the formula overstates); `INSPECT_PX R` d/R 0.92 twist 0.

## Round 5 (phase 5, final)

Measured after 5cc3d55 (`--region 0.2,0.2,1,1`, out `%TEMP%/series/p5-<x>`), one run each, spec p5-2, no code change:
- full `arms inspect {t}` 0:7.2:37 `--dead 0.0005`: ANIM SERIES JUMPY (20 steps), min 0.57%, max 56.26%, mean 17.03%, dead none, no pop. Delta vs round 4: 0.00 / 0.00 points, same step list.
- gun `arms inspect {t}` 4.9:7.2:47 `--jump 0.15` `--dead 0.0005`: ANIM SERIES JUMPY (28 steps), min 0.25%, max 43.66%, mean 18.08%, dead none, no pop. Delta: min/max 0.00 points, but the verdict word differs from round 4 (FLAT+JUMPY): the holds at steps 15-18 and 30-34 measure 0.26-0.41%, above the 0.05% dead bar of `--dead 0.0005`. Rerun with `--dead 0.003`: FLAT+JUMPY, dead 17, 18, 30, the same numbers. So round 4's FLAT+JUMPY most likely came from the 0.003 default, not from a change in the animation.
- still-a 3.4:4.9:6 `--dead 0.0005`: ANIM SERIES OK, steps 3.71/1.03/2.40/4.55/4.66 %, max 4.66%, mean 3.27%, under 5 % (D51): pass. Delta 0.00.
- still-b 7.4:9.0:6 `--dead 0.0005`: ANIM SERIES OK, steps 4.72/4.93/2.64/1.24/4.34 %, max 4.93%, mean 3.57%, under 5 %: pass. Delta 0.00.
- cancel `arms inspect cancel {t}` 0:0.15:6: ANIM SERIES JUMPY 1-5, min 15.26%, max 37.01%, steps 36.67/37.01/30.01/21.58/15.26 falling, no pop. Delta: min 0.02, max 0.00.
- Verdict: unchanged from phase 4 (every number within 0.05 points); the one open item is the gun verdict word, explained above by the dead threshold.
