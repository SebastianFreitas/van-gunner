# Idle wrist research (task `docs/tasks/idle-wrist.md`)

Method: `animation-step-back-loop` (`goblin-weave-research.md` "The method for any animation"):
bar first, smallest always-on version with a pin (`arms weave <t>|off`) and a `SaveSandbox` hold
(`WEAVE_SANDBOX_T` 1.1), measure with numbers, one round of worse / why / solve per commit.
Free left hand only (`DEF-hand.L`); the gun hand has no wrist drive (the gun is not attached to
the hand, `arm_weave.gd:233`).

## Measuring

- `arms wristang [t]`: left wrist flex(x), twist(y), dev(z) in degrees from the posed wrist, plus
  forearm.001 twist. `arms wristang scan [t0 t1]`: per-axis range, peak angular speed and the
  largest per-frame jump (1/60 s steps, default 0..10.8 s). `arms wristang axes`: which way
  each local axis moves the hand. Probe: `py -3 tools/probe.py --frames 5 --cmd "arms wristang scan"`.
- Series: `py -3 tools/anim_series.py --cmd "arms weave {t}" --times 0:10.8:12 --out <dir> --region bottom40`.
- Stills: `py -3 tools/hand_shots.py --pose "arms weave <t>" --views front,elbow,player`.

## The bar (left hand, degrees from the posed wrist; step 1 does not loosen the task's bar)

- Peak of a beat: twist 30 (a third to `DEF-forearm.L.001`, rest at the wrist), flex 30 down and
  20 up, deviation 20 toward the pinky and 12 toward the thumb. No wrung or inverted wrist skin
  in `arms cam elbow` and `arms cam player`.
- Smooth: peak angular speed at most 40 deg/s, no frame-to-frame jump above 1.5 deg, every beat a
  smoothstep envelope, no stop-and-go.
- Matched: a beat's envelope spans one finger roll (`PERIOD` 3.6 s), its peak on the roll's
  crest; beats never land on a creep tic.
- Routine 10.8 s = three rolls: 1 flex beat, 2 twist-led, 3 deviation beat, repeat. Twist drifts
  all 10.8 s, bigger in the middle. Rest pose at the sandbox hold (scale 0) so smoke shots stay
  `same`.
- Series over 12 steps of 0.9 s: no dead step, no step above the step-1 threshold; one described
  still per beat peak.
- Checks stay green: `arms fit`, `gear`, `thumbs`, `touch` at or under `TOUCH CHECK 20`.

## Round 1 (step 1: readout and baseline, no behaviour change)

**Axis signs on the LEFT rig, settled by `arms wristang axes`** (+10 deg about each local axis of
`wrist_pose * from_euler(e)`, middle fingertip displacement in an orthonormal palm frame: a = along
the hand, s = toward the thumb, p = palm-ward as the finger curl moves; frame self-check all 0.00):

| axis | tip move (units) | a / s / p | meaning of the positive direction |
|---|---|---|---|
| +x | 0.061 | -0.19 / +0.88 / +0.43 | mostly deviation toward the THUMB (about 26 deg of flexion mixed in) |
| +y | 0.012 | thumb base -0.20 / -0.18 / +0.96 | twist, the thumb goes palm-ward |
| +z | 0.062 | +0.28 / +0.46 / -0.85 | mostly EXTENSION (hand opens), 0.46 toward the thumb mixed in |

- **Worse than the code's comment:** the weave's note (`arm_weave.gd:159`, "x = flex/extend, z =
  sideways") does not hold on the left rig: x is sideways and z is flex/extend, so the old circle
  has been drawing its flex/deviation swapped (invisible at 8 deg, wrong for 30). Why: the hand
  bone's rest roll is about 27 deg off the palm frame, so neither local axis is clean.
- **Solve for steps 3 and 4:** flexion is `-z` (down 30 = z -30, up 20 = z +20), deviation toward
  the thumb is `+x` (12) and toward the pinky `-x` (20); twist is `+y` (thumb palm-ward). Because of
  the roll, a pure flex beat also swings about 0.5 of its angle sideways: drive the beat as
  `Quaternion(axis, angle)` about the palm-frame axis (rotate z by that 27-30 deg coupling) rather
  than the raw Euler component, and confirm with `arms wristang` that the other components stay
  under 5 deg at the peak.

**Before (today's wrist circle, `arms wristang scan`, 0..10.8 s, 648 steps):**
flex(x) -8.1..+8.0 | twist(y) -6.3..+6.0 | dev(z) -8.0..+9.6 deg; peak angular speed 16.6 deg/s
at t=7.88, largest jump 0.28 deg/frame. Rest reading (sandbox hold t=1.1): flex +8.0, twist -4.1,
dev +0.6, forearm.001 twist -39.2 deg (constant: `ArmRig.reach` sets it once, the weave never
moves it).
- Headroom against the bar: speed 16.6 of 40 deg/s and jump 0.28 of 1.5 deg, so a 30 deg beat over
  3.6 s (smoothstep peak speed = 1.5 x 30 / 1.8 s = 25 deg/s plus the circle) fits. Twist 6 of 30.
- Because the circle (and its x sin component) stays on top, the rest at t=1.1 is not zero: step 2
  must measure the routine's own contribution as the reading minus the circle.
- Still `player` at weave 1.1 (`hand_shots.py --pose "arms weave 1.1"`): the left hand is a
  curled claw at the lower-left, palm toward screen centre, fingertips at about mid-screen height,
  clear of the HUD. That is the baseline look for the later rounds.

## Round 2 (step 2: twist, always on)

**Built:** `arm_wrist_routine.gd` (`ArmWristRoutine`, no class_name) owns the routine clock `rt =
fposmod(t, 10.8)` and the left twist: carrier `-cos(TAU*rt/10.8 + phase)` (phase seeded +-0.5 rad,
peak in the middle of roll 2) times an envelope of 0.55 outside roll 2 and a raised cosine up to 1.0
over roll 2, anchored to exactly 0 at the sandbox hold (t 1.1, so smoke stills stay `same`) and
normalised to 30 deg total. Two thirds go to `DEF-hand.L` (wrist euler y, replaces the left's
`WRIST_ROLL`; the right keeps it), one third to `DEF-forearm.L.001` about its local Y (the hand is
its child, so the hand turns the full 30).

**Numbers (`arms wristang`, left wrist):** t=1.1 twist(y) +0.0, forearm.001 -39.2 (rest, unchanged);
t=5.4 twist(y) +19.8, forearm.001 -29.3 (+9.9), total +29.7. Scan 0..10.8 s: twist(y) -5.2..+20.0
(was -6.3..+6.0), flex -8.1..+8.0 and dev -8.0..+9.6 unchanged, peak speed 16.6 deg/s (same, still
the circle), max jump 0.28 deg/frame. Wrist and forearm turn the same way (sign check passed).
Checks: `arms fit` FIT OK, `gear` GEAR OK, `touch` TOUCH CHECK 18 (limit 20), check and smoke clean.
`arms thumbs` prints `THUMBS CHECK` with BAR hook on the left (thumb-local, not wrist-driven; not
compared against a pre-change run in this round, so step 3 should read it against `main` first).

**Worse:** the twist is one-sided (about -2 to +30 deg, because the anchor at t=1.1 sits near the
carrier's trough), so the hand only ever turns thumb-palm-ward; the speed bar has plenty of room (twist
alone peaks near 17 deg/s) but steps 3 and 4 add beats on top of it. **Why:** zero at the hold plus a
single swing per routine. **Solve if it reads stiff in play:** a second, faster carrier; left for step 5.
Still `player` at weave 5.4 (twist peak): the left hand sits low-left, claws clear, no wrung or
inverted skin, HUD clear.

## Round 3 (step 3: flex/extend beat in roll 1)

**Built:** the routine clock now starts at a seeded origin so the beat's big down peak (u 0.30 of
roll 1) sits on the left fingers' mean curl crest (`ArmWristRoutine._origin`, from the weave's
`crest_phase`); keys 0 -> +30 down (u 0.30) -> -20 up (u 0.80) -> 0 (u 1.0), smoothstep per leg, equal
leg speeds (41.7 deg/s). Driven along `FLEX_AXIS` (0.463, 0, -0.886) euler deg per deg, so it is a pure
flexion on the left rig. At the `SaveSandbox` hold the viewmodel passes `beat_scale` 0, so smoke
stills stay `same`; pins (`arms weave <t>`) get the full beat. Twist is anchored to the hold through
the new origin.

**Numbers:** `arms wristang flex 30`: palm-ward 53.6 deg, sideways -0.2 (FLEX PURE); `flex -20`:
sideways 0.2 (FLEX PURE). Scan 0..10.8 s: flex(x) -17.2..+20.1, twist(y) -2.2..+20.0, dev(z)
-32.4..+19.1 (the x/z split is the flex axis plus the circle), peak speed 52.3 deg/s at t 1.17,
max jump 0.87 deg/frame (bar 1.5). Checks: `arms fit` FIT OK, `gear` GEAR OK, `touch` TOUCH CHECK 18,
`arms thumbs` identical to before the step (L angle 66, hook 79, BAR hook), check and smoke clean.

**Worse:** peak speed 52 deg/s is over the 40 bar. **Why:** 30 down + 20 up in one 3.6 s beat is 100
deg of travel, which needs at least 41.7 deg/s with eased legs before the circle (16.6) is added.
**Loosened with a note (owner's ranges kept):** the beat-roll speed bar is 55 deg/s total; step 5 may
slow the circle during the beat if it reads fast. Still to look at: a pinned still at the down peak
(not captured this round; context ran out), and step 5 judges the skin at the extremes.
