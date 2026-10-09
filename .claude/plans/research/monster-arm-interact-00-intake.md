# monster-arm-interact: intake research (2026-10-08)

What we take from each source, in our words. Prior in-repo research that already settles
things: `.claude/plans/arms-actions-research.md` (the layer order and the rule that every
action is a pure function of time with a debug pin), `goblin-weave-research.md` (the bar
and the step-back loop, "The method for any animation"), `idle-wrist-research.md` (the
left wrist's flex and deviation axes: flexion is `-z` on the hand bone, deviation toward
the thumb is `DEV_AXIS` (0.877, 0, 0.480) euler degrees).

## Why today's gesture reads as a drag (from the code)

- The base pose is baked once by `ArmRig.reach` (two-bone IK, `arms_builder.gd:317`) and
  never re-solved. The gesture (`arm_gesture.gd`) only translates the whole left root
  (`left_offset`, a pure position) and post-multiplies a wrist euler and a uniform finger
  curl. Shoulder, elbow and wrist travel together as one rigid stick: no joint angle
  changes, so nothing "extends".
- The travel is large relative to the arm: the press key moves the root by |(0.75, 0.47,
  -0.75)| = 1.16 rig units while the baked shoulder-to-wrist distance is |LEFT_WEAVE_WRIST
  - LEFT_SHOULDER| = |(0.73, 0.83, -0.70)| = 1.31 rig units (`arms_builder.gd:12,23`).
  So the shoulder itself moves nearly a full arm length: the viewer sees the arm slide,
  not reach.
- Every key uses the same `smoothstep` ease between neighbours, so there is no
  anticipation, no overshoot, no lead or lag between root, wrist and fingers: all three
  channels reach their key together.
- `ArmKick` (`arm_kick.gd:5-6`) already shows the project's way to do joint motion: root
  offsets about real pivots (forearm about the elbow, hand about the wrist) with
  per-channel envelopes (delay, attack, tau, omega), so channels lead and lag.

## Animation principles for a reach and grab

Sources: Lynda/LinkedIn "21 Foundations of Animation" (Anticipating a reach; Overshoot and
settle), CG Cookie "10 Tips for First-Person Game Animation", Animation Mentor POV shots
blog, Brian Lemay inbetweening assignment 6a (hand slap), O'Reilly "Animating with
Blender" ch. 11 (reach timing), garagefarm / evl.uic.edu / pixune on follow-through and
overlapping action.

- **Anticipation**: a short pull-back (hand and wrist draw toward the body, fingers curl
  or splay) before the reach telegraphs it. In first person keep it short (the player sees
  it hundreds of times): a few frames, about 0.05-0.08 s, never a flourish.
- **Overlapping action, lead and follow**: the parts start at different times. For a reach
  the shoulder/upper arm commits first, the forearm follows (elbow opens), the wrist leads
  the hand, the fingers trail last. A hand slap exercise orders it elbow, then wrist, then
  fingertips. Heavier parts lag more.
- **Overshoot and settle**: the reach does not stop dead at the target; the elbow goes a
  hair past straight (or the wrist past its cock) and settles back. For a grab, the
  fingers close past the grip and settle.
- **Finger spread during the anticipation and the flight** makes the silhouette readable;
  the clamp on contact sells speed when the digits close staggered (tips first).
- **Follow-through**: on the way back the forearm leads and the hand and fingers trail;
  loose parts (sleeve hem, claws) drag.
- **Predatory grab (creature)**: coil (claws draw in, wrist cocks back), strike (wrist and
  forearm drive, fingers splayed wide, claws forward), snatch (claws snap shut on contact,
  tips arrive first), recoil (a small jerk back as if the prey resisted), settle. The
  "aggressive" read comes from the speed ratio: a slow coil and a strike at least 3x
  faster, then a hard stop, not from large travel.
- **Ease curves**: anticipation ease-in, strike ease-out (fast start, decelerating into
  contact), settle as a damped cosine (what `ArmKick`'s envelopes already do).

## How Godot 4 one-shots are layered

Sources: Godot docs (AnimationTree, AnimationPlayer, SkeletonIK3D, deprecated in 4.3),
tabnews write-up of Godot 4.6's new `IKModifier3D` family (`TwoBoneIK3D`).

- The engine-native way is an AnimationTree OneShot (or additive blend) over an idle
  clip, with a `TwoBoneIK3D` modifier (4.6+) for reaching a target. Our arms do not use
  AnimationPlayer at all: the idle, walk, kick and gestures are code-driven writes to bone
  poses every frame, in a fixed order (`gun_viewmodel.gd:302-328`). Mixing an
  AnimationTree in would fight those writes.
- `SkeletonIK3D` overwrites bone poses through a global override and is deprecated; not a
  fit.
- The project's own two-bone solver `ArmRig.reach` (`arm_rig.gd:89`) is static and pure:
  given shoulder, wrist target, pole, hand direction and palm normal it writes the five
  bone local poses. Called again with the baked inputs it reproduces the baked pose
  exactly, so a gesture that moves only the wrist target (and pole) and returns it to the
  baked point is seamless by construction, with no blend weights.
- Code-driven keyed curves (what `ArmGesture` is) stay the right tool here; what changes
  is *what* the keys drive (joint targets, not a root slide) and *how* the channels are
  timed (per-channel delay and ease, as `ArmKick` does).

## Takeaways for the plan

1. Replace most of the root slide with a real reach: re-solve the left arm's two-bone
   chain every gesture frame toward a wrist target that travels from the baked point to a
   contact point, with the elbow pole swinging so the elbow drops and the upper arm
   rotates; keep a small root push (body lean) of at most about a quarter of the old
   travel.
2. Per-channel timing: shoulder/root first, elbow next, wrist cock leads the hand into
   contact and snaps on contact, fingers splay during the flight and clamp or stab at
   contact, staggered by finger.
3. Anticipation of about 0.05-0.08 s, strike to contact at least 3x faster than the coil,
   overshoot and damped settle (reuse the `ArmKick` envelope shape).
4. Measure with `tools/anim_series.py` (dead/jump thresholds), `arms frame`, and pinned
   stills at coil, contact and settle; one round per commit with worse/why/solve.
