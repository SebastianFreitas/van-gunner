# Arms actions: how every first-person arm animation fits together

Owner, 2026-10-02: "make the shooting animation better ... take a step back and consider how
this is gonna work". Coming animations: shoot (now), jump, left-hand punch, left-hand interact
(doors, driver, buttons), walk/run. For now only the shot, hands and arm motion only (the gun
just rides along), to feel the impact. Method: `goblin-weave-research.md` "The method for any
animation" (bar with numbers first, debug pin, rounds of worse / why / solve).

## The layers (bottom to top, composed every frame in `GunViewmodel`)

1. **Base pose**, baked once at build: `ArmRig.reach` two-bone IK puts each hand on its target
   (`ArmsBuilder`). Never re-solved per frame today.
2. **Idle** (`ArmWeave.update(t)`): absolute writes to finger and left-wrist bones every frame,
   plus a slow figure-eight drift of each arm root. It is the layer every other layer adds onto.
3. **Locomotion** (`GunViewmodel._motion`): look sway and walk bob on all roots. Walk/run and
   jump/land belong here later: driven by the player's velocity and `is_on_floor()`, continuous,
   never triggered.
4. **Actions** (one small `RefCounted` per action, under `scripts/player/arms/`): fired by an
   event, sampled by time since the event, and returning per-arm root offsets about real joint
   pivots (wrist, elbow) plus additive bone rotations written right after the weave. The shot
   kick (`ArmKick`) is the first; punch and press follow the same shape.
5. **Reload cant** stays its own tween for now; actions are cleared when a reload starts.

Rules every action keeps: a pure function of (time since event, event index), so a debug pin
`arms <action> <t>|off` and the `SaveSandbox` hold make stills repeatable; per-event variety from
a hash of the event index, never a shared RNG; overlapping events add (superposition) with a
soft cap, so held fire never snaps back; bones it touches are either rewritten by the weave every
frame (post-multiply after `update`) or owned by the action (absolute from a cached base).

## Next actions (notes, not built)

- **Interact press (left hand):** one clip for every interactable (door buttons, driver, bench):
  the left hand rises into view, fingers open, pushes toward the screen centre and drops back
  (about 0.35 s), fired from `fps_player.gd` where `interact(self)` is called. Recommended over
  reusing the punch: a fist strike on a "talk to the driver" reads wrong, but the press can share
  the punch's reach code and envelope helpers.
- **Punch (left hand):** needs an input action (none exists: no `melee` in `project.godot`).
  Fast closed-fist jab along the view axis, 0.08 s out, 0.25 s back, shoulder leading.
- **Jump / land:** locomotion layer: arms lag up on take-off, compress down on landing scaled by
  fall speed.
- **Walk / run:** today's bob reads body position; give it a stride phase and a run blend once a
  sprint exists (no sprint action today).

## The bar for the shot kick (round 1)

Measured with the weave pinned (`arms weave 1.1`) and `arms shot <t>` pins, player view, region
`bottom40` (`tools/anim_series.py`).

1. **Reads as impact:** t 0 → peak (0.04 s) changes ≥ 3% of bottom-40% pixels.
2. **Snappy:** the peak lands by 0.05 s; the step diff 0 → 0.03 is the largest of the series.
3. **Recovers with weight:** one small dip past rest (undershoot) around 0.15 s, then settled:
   t 0 vs t 0.4 changes < 0.3% (anim_series dead threshold).
4. **Hand keeps the gun:** at peak (`arms cam side`, `arms shot 0.04`) the grip sits in the palm,
   no gap: the wrist flex turns the gun with the hand.
5. **Both arms feel it:** the left arm jolts later and smaller (visible in the left close-up).
6. **Held fire never snaps:** by construction (superposition plus soft cap), not measured.
7. **HUD clear, no clipping:** the hand never crosses the GO/EASY box (x 24..292, y 24..168 px
   up at 1920x1080) or the near plane at peak.

## Rounds

(one line per round: worse / why / solve, with the numbers)
- **Round 1** (ArmKick built): bar 1 met (rest -> 0.03 s changes 19.5% of bottom-40%); bar 4 met
  (side close-up at 0.04 s: fingers stay wrapped on the grip, muzzle flipped up); bar 2 roughly
  (0 -> 0.03 is 19.5%, but the recovery step 0.045 -> 0.08 is as big, 19.9%); **bar 3 missed**:
  t 0.4 vs settled still changes 1.17% (target < 0.3%). Why: ENV_ARM tau 0.11 and ENV_JITTER tau
  0.10 leave about 4% of the peak at 0.4 s. Solve next: shorter taus on the arm and jitter
  channels, then re-measure; then bars 5 and 7 (left close-up, HUD box at peak).
- **Round 2** (decay taus): worse: shortening only ENV_ARM (0.07) and ENV_JITTER (0.065) left
  bar 3 at 1.15%. Why: round 1's diagnosis was wrong; at 0.4 s the delayed ENV_LEFT (tau 0.12)
  still held about -6% of its peak, ENV_BACK 1.5%, ENV_GRIP 0.9%. Solve: ENV_BACK 0.065,
  ENV_GRIP 0.06, ENV_LEFT 0.06 (peaks and omegas kept): **bar 3 met**, 0.4 -> 10 s is 0.22%
  (steps 19.5 / 10.1 / 20.5 / 17.8 / 4.2 / 2.2%). Bar 5 met: left close-up (`--pre "arms cam
  left"`, separate `--pre` per line, `;` does not chain) changes 3.86% at 0.06 s. Bar 7 met: 0
  hand pixels in the GO/EASY box (HUD is unscaled px: x 24..292, y H-168..H-24) at rest and at
  0.04 s, though the left hand sits right at the box's right edge. Bar 2 still rough: the
  recovery step 0.045 -> 0.08 (20.5%) edges out 0 -> 0.03 (19.5%), the undershoot swing.
