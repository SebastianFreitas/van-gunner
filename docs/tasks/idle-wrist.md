# Idle wrist: three wrist moves in the free hand's idle

Owner, 2026-10-03: the idle hands need wrist rotation, matched with the fingers at set
moments, and a longer idle. A wrist bends three ways: **twist** (rotation about the forearm),
**flex/extend** (hand curls down or up) and **deviation** (sideways, thumb-side or pinky-side).
Build one move per step, one thing at a time. Twist runs through the whole idle, flex opens the
routine, deviation closes it.

Answers (owner): the **free left hand only** (`DEF-hand.L`) for now; the gun hand has no wrist
drive because the gun is not attached to the hand (`arm_weave.gd:233`), a later task. The moves
are a **slow keyed routine** with distinct beats, not three blended sines.

Method: `animation-step-back-loop` (`.claude/plans/goblin-weave-research.md:270`, "The method
for any animation"). Record every step as a round in `.claude/plans/idle-wrist-research.md`:
what is worse, why, the fix, the numbers. Read `.claude/rules/art-style.md` lines 110-151
(arms) before a step that changes how the hand looks.

## How this task runs

One step is one context: spec it (grep `docs/PROJECT_MAP.md`, one Explore call for anchors),
hand the code to `implementer`, verify, commit, tick the box, stop with the report. The last
step's commit deletes this file. Report specifics are in CLAUDE.md (a PNG from
`tools/smoke.py --shots` or a `tools/hand_shots.py` view, plus an exact Try line: pin with the
console command `arms weave <t>` (`H` opens the console), no class pick needed for the free
hand beyond the default).

## What exists (anchors, verify before relying)

- `scripts/player/arms/arm_weave.gd` (`ArmWeave`, ~296 lines, already near the 300 target):
  `update(t)` is called each frame from `scripts/combat/gun_viewmodel.gd:285-289`. `w =
  TAU*t/PERIOD`, `PERIOD` 3.6 s. The wrist is one bone, `DEF-hand.L` / `.R` (`:149-155`), driven
  at `:215-223` as `wrist_pose * Quaternion.from_euler(e)` with `e = wrist_base +
  (WRIST_CIRCLE*sin b, WRIST_ROLL*sin(b/2), WRIST_CIRCLE*cos b)`, `b = w*0.8 + phase`:
  x = flex/extend, y = twist about the bone axis, z = sideways. `WRIST_CIRCLE` 8, `WRIST_ROLL` 6,
  `LEFT_WRIST_BASE` zero. Add the routine in a new `RefCounted` helper beside it
  (`arm_wrist_routine.gd`, no `class_name`), not more lines in the core.
- Twist is also shared with the bone `DEF-forearm.001` by `ArmRig` (`TWIST_SHARE` 0.5,
  `arm_rig.gd:9,147`) so the wrist skin is not wrung thin. A large twist here must do the same.
- Other writers on `DEF-hand.L` after the weave: `ArmCreep` (`_creep_l.wrist`, `arm_creep.gd`,
  `STRETCH_WRIST`, `TIC_WRIST`) and `arm_gesture.gd:103,156` (composes on the current pose).
  The routine adds to the weave's rotation before those, so check that the stack still reads.
- Skin: `ArmBulk` / `ArmMuscle` inflate the skin around `DEF-hand` (`arm_bulk.gd:42`); big angles
  can pinch it, judge from stills.
- Pin: `arms weave <t>|off` (`debug_arms_commands.gd:68-76`, `vm.debug_weave_t`). Under
  `SaveSandbox` the weave holds `WEAVE_SANDBOX_T` 1.1 (`gun_viewmodel.gd:32`). The routine must
  be at its start pose (scale 0) at the sandbox hold unless a pin is set, so the smoke shots stay
  `same` and no baseline moves.
- Tools: `tools/anim_series.py --cmd "arms weave {t}" --times 0:10.8:12 --out <scratchpad> --region
  bottom40`, `tools/hand_shots.py` / `arms cam front|side|top|elbow|player`, `tools/pose_sheet.py`.
- Checks that must stay green: `arms fit` FIT OK, `arms gear` GEAR OK, `arms thumbs` THUMBS OK,
  `arms touch` not above `TOUCH CHECK 20`.

## The bar (numbers; step 1 may tighten them, never loosen without a note)

- Ranges at the peak of the beat (left hand, degrees from the posed wrist): twist 30 (a third
  to the forearm bone, the rest at the wrist), flex 30 down and 20 up, deviation 20 toward the
  pinky and 12 toward the thumb. The hand must never turn so far it shows a wrung or inverted
  wrist skin in `arms cam elbow` and `arms cam player`.
- Smooth: peak angular speed of the wrist at most 40 deg/s, no jump between two frames above
  1.5 deg, every beat eases in and out (smoothstep envelope), no stop-and-go.
- Matched: a beat's envelope spans exactly one finger roll (`PERIOD`, 3.6 s) and its peak sits
  on the finger roll's crest, so the fingers and wrist move as one gesture.
- Routine: three finger rolls = 10.8 s. Roll 1 flex beat, roll 2 twist-led, roll 3 deviation beat,
  then it repeats. Twist is a slow background drift all 10.8 s, bigger in the middle. Beats are
  not mirrored copies: the left routine may be offset in time from the creep tics but the beats
  never land on a finger tic.
- No visible loop over 10.8 s because the existing circle, drift and creep layers stay on top.
- Survives gameplay: walking, shooting (right hand), reload and the gesture still read; the HUD
  stays clear of the hand at every peak.
- Measured: `anim_series.py` over 12 steps of 0.9 s gives no dead step (0%) and no step above
  the step-1 threshold; a pinned still per beat peak is described in one line each.

## Steps

- [x] 1. **Bar, readout and baseline.** Write `.claude/plans/idle-wrist-research.md` (the bar
  above, round log). Add a debug readout `arms wristang [t]` (in `debug_arms_commands.gd` or a
  small new `debug_arms_wrist.gd`) printing the left wrist's flex, twist and deviation in degrees
  relative to the posed wrist at time `t`, plus the forearm.001 twist. Use it and three
  `hand_shots.py` views to settle, with numbers, which sign of local X is flexion and which of Z
  is toward the thumb on the LEFT rig (the code only says the left rig's Z points the other way,
  `arm_weave.gd:159`), and record the angular-speed measurement of today's wrist circle as the
  "before". No behaviour change; commit the readout and the research file.
- [x] 2. **Twist, always on.** Replace `WRIST_ROLL` 6 sin(b/2) with a slow twist of up to 30
  degrees, split with `DEF-forearm.001`, in the new helper with a seeded phase and a routine
  clock `rt = fposmod(t, 3*PERIOD)` that later steps share. Twist envelope bigger in roll 2.
  Rest at the sandbox hold. Measure the twist range and speed with the readout, judge the skin at
  the extremes (`arms cam elbow`, `player`). Round in the research file; commit.
- [x] 3. **Flex/extend beat in roll 1.** One smoothstep beat over `rt` 0 to `PERIOD`: down to 30
  then back through neutral to 20 up, peak timed on the finger roll's crest. Check the finger
  curl does not collide with the palm at the down peak (`arms touch`). Round; commit.
- [x] 4. **Deviation beat in roll 3.** Same shape, sideways, 20 toward the pinky, 12 toward the
  thumb, closing the routine so roll 3 hands back to roll 1 without a seam (check the wrap with
  `anim_series.py` across 10.8 s to 12 s). Round; commit.
- [ ] 5. **Stack and gameplay pass.** Run the routine under walk, shoot, reload, the left-hand
  gesture and `arms inspect`; fix any stack clash (creep tics at a beat peak, gesture on top of
  a flex). Full series, `arms fit` / `gear` / `thumbs` / `touch`, `tools/smoke.py` and
  `--shots`, `gen_context.py`. Final round written up, **delete this file in this commit**.

Later (not this task): the gun hand's wrist, which needs the gun to follow it.
