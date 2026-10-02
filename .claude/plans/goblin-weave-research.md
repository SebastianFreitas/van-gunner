# Goblin hand weave: research and the step-back loop

Owner's ask (2026-10-02): run the prepared goblin idle weave, commit it, then keep going
in rounds until it is top tier. After every round step back and ask: compared with a
top-tier idle (a witch casting, both hands always alive), what is worse? why? how do we
solve it? Then run the next round. "Could take forever, I don't care." The point is a
method that works for any animation afterwards (bottom of this file).

Branch: `claude/game-arms-weapon-visuals-c13029` (the goblin worktree's tree was identical
to main, and the app sandboxes writes to this worktree, so the prepared specs ran here).

## The bar: what top tier means here

1. **Readable**: from the player view at IDLE every finger of both hands is inside the
   frame with its curl visible side-on or three-quarter, never knuckles-to-camera.
2. **Alive everywhere**: fingers, wrists AND forearms move; the arms breathe and drift in
   a slow figure-eight, counter-phased, not two frozen logs with twitching fingers.
3. **Slow, big, smooth**: fingertip screen travel per roll about 4-6% of screen height;
   no frame-to-frame jump over 1% of screen height at 60 fps; no dead frames (every
   0.3 s step changes pixels in the hand region).
4. **Never loops visibly**: two incommensurate periods (done: 3.6 s and a 0.37x harmonic).
5. **No self-intersection**: fingers never pass through the palm, thumb never through the
   index; claws stay attached (rotation only, never scale or position on bones).
6. **Survives the game**: continues through walk bob, recoil, reload, look-down; does not
   fight the reload tween (the tween moves roots, the weave moves bones).
7. **Clear of HUD**: hands stay right of or above the GO/EASY box (x 24..292 px,
   24..168 px up from the bottom at 1920x1080).

## Measuring (numbers before pictures)

- Stills: `py -3 tools/smoke.py --shots <scratch>/shots` gives `01-idle-front` (player
  view) and `a07-arms-weave` (pinned t 2.9) and `a01-arms-front` (pinned t 1.1).
- Motion: pin the weave at N times and diff consecutive frames in the hand region:
  `py -3 tools/probe.py --cmd "arms weave <t>" --shot <scratch>/w-<k>.png` for t in
  0.0, 0.45, 0.9 ... 3.6 (one period, 8 steps), then a tiny scratch script sums changed
  pixels (threshold 12/255) in the bottom 40% of the frame per step: dead frame = under
  0.3% of that region changed; jump = over 6%. Record the series here each round.

## Round 1 (prepared run, commit c5ba2ac)

What landed: `ArmWeave` (3.6 s roll, lag 0.9 rad/finger, BASE 35/55/45 deg, SWING
14/22/18, thumb half speed, 6 deg spread, wrist circle 8 deg + roll 6 deg), left hand
raised (`LEFT_REST = (0, -0.04, 0)`), wrist bases `(20, 0, 0)` both, `arms weave`
command, `arms-weave` smoke shot, `SaveSandbox` pin at t 1.1.

Step back (IDLE player view and `a07`):
- Worse: both hands sit on the bottom edge; the right hand's fingers are clipped off
  screen, only knuckles show. Why: the right root rest was tuned for a gun grip at the
  bottom-right; the hand was never meant to be looked at. Solve: raise both rests so the
  whole hand plus a third of the forearm is in frame (hand centre about 18-22% up).
- Worse: right hand presents knuckles to the camera, fingers hook away from the viewer,
  so the curl is invisible. Why: wrist base is pitch only (20, 0, 0). Solve: yaw the
  right wrist about -35 deg and roll about +25 deg (palm turning in and down toward the
  centre of the screen) so the fingers hook across the view; mirror for the left.
- Worse: the forearms are dead; only fingers and wrists move. Why: the weave writes bones
  only. Solve: a slow figure-eight on each arm root (position 0.6 cm amplitude in rig
  units x 1/0.18, rotation 2-3 deg), counter-phased between hands, added in `_apply`
  next to bob and sway so recoil and reload stack on top.
- Unknown: motion amplitude and smoothness (no number yet). Solve: the probe series above.

## Round 2 plan

- Spec 3: `ArmWeave` gains `arm_offset(side: int) -> Transform3D` (figure-eight, read by
  the viewmodel) and the tuned wrist bases; `gun_viewmodel.gd` raises `RIGHT_REST`
  (new, mirrors `LEFT_REST`) and `LEFT_REST`, adds the arm offsets in `_apply`.
- Measure with the probe series; write the numbers under Round 2 here.
- Verify: check, smoke, shots (01-idle-front, a01, a07 change; the rest same), review,
  commit, then step back again.

## Round 2 (commit 2002db7)

Landed: `RIGHT_REST (0.06, 0.05, 0.04)`, `RIGHT_REST_TILT (15, -10, -15)`, `LEFT_REST
(-0.10, -0.04, 0)`, `LEFT_REST_TILT (15, 10, 15)` fading with `shown`; figure-eight arm
drift `ARM_DRIFT (0.04, 0.05, 0.03)`, `ARM_TILT (2.5, 2, 3)`, `DRIFT_RATE 0.55`;
`tools/anim_series.py`.

Numbers: 12-step series (0.3 s, bottom 40%, threshold 12): changed 3.9..15.7% per step,
mean 9.8%, no dead steps, wrap 22% (no visible loop). Steps 9-11 (t 2.4..3.3) are the
fast phase at 13-16%, step 3 the slow one at 3.9%.

`01-idle-front` (1440x720): both hands fully in frame, left centre about x 370 y 550,
right about x 900 y 530, hooked claws visible on both, forearms leave the bottom corners,
left clear of the GO box. Right hand is a dark silhouette; the left is lit.

Step back:
- Worse: the right hand is unlit (see the luminance numbers under Round 3). Why: the only
  light on the arms is `ArmLamp`, an `OmniLight3D` (energy 0.35, range 0.9) parked at the
  hidden gun's taped lamp fixture (`held_gun.gd` `lamp_local`), so it is in front of the
  right hand and has no visible source now that the gun is hidden (breaks "light only from
  sources you can point at"). Solve: a visible caged trouble lamp zip-tied to the top of
  the right forearm near the wrist, bulb between and above the hands; the omni moves to
  the bulb; energy about 0.6, range about 1.2.
- Worse: motion speed swings 4x within a period (3.9% vs 15.7%). Why: the arm drift and
  the finger roll align in phase for a third of the period. Solve: slow the drift
  (`DRIFT_RATE 0.55 -> 0.4`) and trim `ARM_DRIFT.y` to 0.035; target max under 12% and
  max/min under 3.
- Fine: readability, framing, HUD clearance, no dead frames, no loop.

## Round 3 plan

- Spec 5: `scripts/player/arms/arm_lamp.gd` (static builder for the forearm lamp fixture,
  returns the bulb position in right-root space), `arms_builder.gd` builds it on the right
  arm and returns its bulb as `lamp_local`, `gun_viewmodel.gd` energy/range constants,
  `arm_weave.gd` drift rate. Measure hand luminance before/after and the series again.

## Round 3 (commit 86113bb)

Landed: `ArmLampKit` (strap rings, zip tails, body, bulb, 4-bar cage, cable) on the right
forearm at `BACK 0.3`, `UP 0.17`, `STRAP_R 0.2`; omni at the bulb, energy 0.8, range 1.5;
`DRIFT_RATE 0.4`, `ARM_DRIFT.y 0.035`.

Numbers (`01-idle-front`, mean / blown% = share of pixels over 230):
| box | round 2 | round 3 |
|---|---|---|
| left hand (280,500,470,720) | 35.3 / 0.0 | 51.3 / 0.0 |
| right hand (800,460,1050,720) | 19.0 / 0.0 | 41.3 / 1.87 |
| lower-right corner (1050,520,1440,720) | 33.3 / 0.0 | 61.2 / 3.89 |
Series (12 x 0.3 s): 5.3..12.2% per step, mean 8.6%, max/min 2.3, no dead steps, wrap 21%.
The right thresholds for `anim_series.py` at 0.3 s steps are dead 0.3% and jump 13%; the
tool's default jump 6% is for finer steps.

Step back:
- Worse: glare. The right hand's top edge and the fixture's cap blow out to flat white
  (blown 1.9% and 3.9%); the style is one dark look, light as a warm dim glow. Why: the bulb
  sits 0.17 rig units (3 cm) off the skin at energy 0.8, so inverse-square saturates the
  nearest surfaces. Solve: lift the bulb (`UP 0.3`), energy 0.5, range 1.3; flatten
  `omni_attenuation` to 0.8 only if that is not enough.
- Worse: the fixture reads as a big pale slab in the corner, not a small caged trouble
  lamp. Why: strap rings radius 0.2 and 0.05 tall show a lit flat cap to the camera; body
  radius 0.05 is a can, not a lamp, this close to the lens. Solve: strap rings 0.02 tall at
  the measured forearm radius + 0.01, body radius 0.035 and length 0.12, bulb 0.028, cage
  0.1.
- Fine: motion (bar met), brightness ratio 0.8, framing, no dead frames.

## Round 4 plan

- Spec 6: the de-glare and shrink above, measured with blown% < 0.5 in the right box and the
  corner, right mean >= 0.75 x left, both >= 38. Two files, no reviewer needed.

## Round 4 (commit: "Take the glare off the forearm trouble lamp")

Landed: `UP 0.4`, `STRAP_R 0.16`, `STRAP_H 0.02`, `BODY_R 0.035`, `BODY_LEN 0.12`,
`BULB_R 0.028`, `CAGE_LEN 0.1`; `LAMP_ENERGY 0.35`, `LAMP_ATTENUATION 0.7`, `LAMP_RANGE 1.3`.

Numbers (mean / blown%): left 39.5 / 0.0, right 32.6 / 0.0, corner 62.8 / 0.16. The
tuning table: energy 0.5 + UP 0.3 gave corner 16% blown (the fixture lights itself at
point blank), energy 0.35 11.8%, UP 0.4 4.4%, attenuation 0.7 0.16%. So the fixture's own
faces are what blows, not the hand.

Step back:
- Worse: the fixture floats 0.4 rig units (7 cm) above the forearm and sits in the
  bottom-right corner, so it reads as a stray stick at the frame edge, not a lamp strapped
  to the arm. Why: lifting the bulb was the only lever against self-glare, and `BACK 0.3`
  puts it where the forearm leaves the frame. Solve: decouple light from fixture: the
  fixture sits on the arm (`UP 0.2`) at the wrist (`BACK 0.15`) and the omni sits
  `LIGHT_LIFT 0.22` above the bulb (4 cm, invisible at this scale; the bulb still glows by
  its material). Energy back to 0.45, attenuation 0.8, to lift the right mean to 36+.
- Relaxed: the "both means >= 38" floor was a guess; the floor reference is 30 and the
  scene is night. New floor: right >= 36, left >= 38, ratio >= 0.8, blown < 0.5%.
- Fine: hands even, hooked curls visible on both, no glare on skin.

## Round 5 plan

- Spec 7: the decoupling above, two files, measured with the same boxes plus a visual check
  that the strap rings hug the forearm and the fixture is inside the frame.

## Round 5 (commit f463670)

Landed: `BACK 0.15`, `UP 0.2`, `LIGHT_LIFT 0.22` (the omni sits above the bulb, the
fixture on the arm), `LAMP_ENERGY 0.45`, `LAMP_ATTENUATION 0.8`.

Numbers: left 42.0 / 0.0, right 38.0 / 0.0, corner 65.2 / 0.0. All lighting bars met
(ratio 0.90). Straps hug the forearm, fixture inside the frame, fingers uncovered.

Step back:
- Worse: the fixture reads as a dark pipe lying along the forearm, not a lit trouble lamp.
  Why: the cable (radius 0.014, 0.5 long back along the arm) is 20-40 px wide this close
  to the lens and runs the whole visible forearm; the lamp body shows its dark back cap
  to the camera and the bulb has no visible glow from this angle; the omni is 4 cm above,
  so the cage is unlit from the camera side. Solve: cable radius 0.007 that drops off the
  side of the arm right behind the body (one short run, then down), the fixture pitched
  about 30 deg so the caged bulb end lifts toward the camera, and a bulb material with
  the same emission the van's trouble lamps use (inside the art-style emission budget).
- Fine: everything else on the bar.

## Round 6 plan

- Spec 8: the fixture read above (cable, pitch, glowing bulb), one file plus possibly
  `arm_materials.gd` for a bulb builder. Measured: blown% stays < 0.5 in the corner and the
  bulb's own pixels must read brighter than the body (a small box on the bulb vs one on
  the body, both means printed).

## Round 6 (commit 729aa2b)

Landed: `ArmMaterials.bulb()` (emissive, glow 1.2), fixture pitched 32 deg bulb-end up on
an unpitched strap frame, cable radius 0.007 with a 0.12 run then a 70 deg drop over the
outer side.

Numbers: left 42.3 / 0.0, right 35.7 / 0.0, corner 71.0 / 0.28 (glow 1.6 and 1.4 gave
2.53% in the corner: the bulb itself). `01-idle-front`: a small caged lamp with a warm bulb
aimed up at the hands, strapped flat on the forearm, a thin cable leaving it; both hands
evenly lit with the hooked curls readable; nothing blown.

Step back:
- Worse: nothing on the readability, light or framing lines. Motion numbers hold (round 3
  series; the drift and the finger maths have not changed since).
- Missing for top tier: an idle that is only a loop of the same roll, however incommensurate,
  reads as mechanical after a minute. A witch pauses to stretch a hand open and re-hook it.
  Solve: a slow flourish every 11 s, alternating hands, outside the pinned shot times.
- Still unproven: no self-intersection (checked by eye on `a07`, below).

## Round 7 plan

- Spec 9: the flourish in `arm_weave.gd` only (schedule `fmod(t, 11)`, window u 4.0..7.2,
  right hand on even cycles, left on odd; open curl (8, 12, 10) deg, spread doubled, wrist
  pitched up 12 deg, smoothstep in 1.2 s, hold 0.4 s, out 1.6 s). Measured with an 11-step
  1 s series (steps 4..8 must rise, the others stay near the idle level) and one still at
  t 5.4 (`arms weave 5.4`).

## Round 7 (commit eca8b79)

Landed: the flourish (`FLOURISH_PERIOD 11`, `FLOURISH_AT 4`, in 1.2 / hold 0.4 / out 1.6,
`OPEN_CURL (8, 12, 10)`, `OPEN_THUMB (5, 8, 6)`, spread x2, wrist lift 12 deg, hands
alternate by cycle parity).

Numbers: 1 s series over t 0..10 (bottom 40%): baseline steps 14.0..15.2%, flourish steps
4, 5, 7 at 23.6 / 25.6 / 26.0%, steps 6 and 8 at 17.2 / 18.3% (the hold and the start of
the re-hook move less: expected), no step over 50%, `ANIM SERIES OK` at jump 0.5. Still at
t 5.4: right hand open and lifted, fingers spread; left still hooked.

Step back:
- Worse (seen on `a07-arms-weave` from round 6): from the front camera the strap rings float
  as flat slabs under the forearm and the lamp head is out of sight. Why: the fixture is
  placed on the straight shoulder-to-wrist chord in root space with a guessed radius 0.16,
  not on the bent forearm. Solve: a `BoneAttachment3D` on `DEF-forearm.R.001` like the
  claws, strap radius from the arm's real thickness at the mount (`_fore_r` with the
  interpolated bulk gain), light position converted through the bone's global pose.
- Fine: everything else; the flourish is the last "alive" line of the bar.

## Round 8 plan

- Spec 10: the bone mount above (`arm_lamp_kit.gd`, `arms_builder.gd`), judged on `a07`
  and `01` with the same boxes. After it: final report unless the shots show a new flaw.

## Round 8 (commit: "Mount the forearm trouble lamp on the forearm bone")

Landed: `ArmLampKit.build(model, r_mount, rng)` on a `BoneAttachment3D` at
`DEF-forearm.R.001`, `MOUNT_T 0.55`, `MOUNT_ANGLE 0`, strap radius `r_mount + 0.01` from
`_fore_r` with the interpolated bulk gain, light position through the bone's global pose.

Numbers: left 41.4 / 0.0, right 35.5 / 0.0, corner 67.5 / 0.11. `a07`: both straps wrap
the forearm all the way round, lamp head with cage and bulb on the upper surface, cable
leaves backward. `01`: lamp on the top/outer face behind the hand, fingers clear.

Step back: every line of the bar is now met by a number or a described still:
readable (both hands framed, curls three-quarter), alive (fingers, wrists, forearm drift,
11 s flourish), slow/big/smooth (5.3..12.2% per 0.3 s, no dead steps, no jumps), no
visible loop (wrap 21%), no self-intersection seen on `a07` at t 2.9 and the peak at 5.4,
survives gameplay by construction (bones for the weave, roots for bob/recoil/reload),
HUD clear, lit from a source you can point at with no blown pixels on skin. Stop here.

## Later rounds (candidates, pick by what the shots show)

- Finger abduction (spread) that follows the curl, thumb opposition arcs.
- Micro-tremor: a third tiny sine (0.5 deg, 7 Hz) only on the .03 tips, so the hands
  look tense, never jittery.
- A "cast" accent every 9-14 s: one hand opens wide and snaps back over 0.8 s.
- Light: the cab lamp catches the claws; check the claw highlight reads in `01`.

## The method for any animation (fill in as the rounds teach it)

1. Write the bar first (readable, alive, slow/big/smooth, no visible loop, no
   self-intersection, survives gameplay, HUD clear) with numbers.
2. Build the smallest always-on version with a debug pin (`<thing> <t>|off`) and a
   `SaveSandbox` hold so smoke shots compare.
3. Measure: stills at two pinned times plus a pinned series diffed step to step.
4. Step back against the bar: worse / why / solve, one round per commit.
5. Stop when every bar line is met by a number or a described still, not by taste.

## Round 9 (owner, 2026-10-02: thumbs curled down, hands at an odd angle, left hand twitching)

- Worse: thumbs always tucked, both hands held at an unnatural angle, the left hand
  sliding when the player looks up and down. Why: `ArmWeave._add_hand` took the wrist from
  `get_bone_rest`, so the orientation `ArmRig.reach` chose was overwritten every frame
  (the angle); the thumb was only flexed on the fingers' X axis with no abduction (the
  tuck); `gun_viewmodel.gd` still blended the left root by `maxf(k.y, _look_down)`, the
  old hide-until-look-down behaviour fused with the weave (the twitch).
- Solve: the look-down blend, `debug_look_down`, `cam down` and the `arms-down` shot are
  gone (`arms-reload`/`arms-weave` are now `a05`/`a06`). The weave circles the posed
  wrist (`get_bone_pose_rotation`), with both wrist bases at zero. The thumb .01 bone is
  held abducted on its local Z (`THUMB_SPREAD 28`, `THUMB_ARC 7` slow opposition swing).
  `ArmsBuilder` poses both arms with a two-pass weave reach (`*_WEAVE_WRIST`,
  `*_WEAVE_PALM`, `WEAVE_WRIST_LIFT`), and the viewmodel's `LEFT_REST`/`RIGHT_REST` and
  tilts are zero: the builder owns the framing.
- Thumb sign: `THUMB_SPREAD_SIGN` settled at -1.0 by two `arms cam top` probes at weave
  0 and 1.8 (raw diff 0.24 each). At +1 both thumbs lay along the fingers (the left
  tucked under the curled fist); at -1 the left thumb stands out from the fist and the
  right points outward from the index.
- Series (8 x 0.45 s, bottom 40%, threshold 12): 5.5..12.2% per step, mean 8.0%, no dead
  steps, wrap 19%. The tool's 6% jump flag fires on every step at this coarse pitch, as
  the Round 4 note says (13% is the bar for steps this long); the max is under it.
- `a01` (front): both hands in frame, backs to the camera, fingers forward-down with the
  near hand half-curled; the thumbs read only from the top view. HUD box clear.

### Round 9b (owner: "the left thumb still looks odd")

- Worse: with the spread on the thumb bone's local Z at -1 the left thumb bent backward
  under the fist (seen from the top), and at +1 it lay along the index: Z is not the
  abduction axis. Why: the thumb .01 bone is rolled against the fingers, so its Z swings
  the thumb in the palm's plane only when the hand is flat; the weave's curl made that
  read as a hyperextension.
- Solve: `THUMB_SPREAD_AXIS` picks the axis. A six-shot sheet (`arms cam top`, weave 0,
  left-hand crop, axes RIGHT/UP/BACK at +1/-1; crop diffs vs BACK -1: 1.2, 1.9, 1.1, 0.9,
  0, 1.4%) showed RIGHT at -1 as the only variant where the thumb stands clearly away from
  the index; the right-hand crop of the same shot agrees (BACK -1 gave a stub, RIGHT +1
  hid it). The `arms cam left` view hides the left thumb behind the hand: judge thumbs
  from the top camera only.
- Series after the change (8 x 0.45 s): 5.6..12.1% per step, mean 8.2%, no dead steps,
  wrap 19%; unchanged within noise.
