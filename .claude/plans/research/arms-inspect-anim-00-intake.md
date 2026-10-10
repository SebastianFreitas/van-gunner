# arms-inspect-anim: intake research (2026-10-10)

## Why today's inspect reads as "moving the assets around" (from the code)

- `arm_inspect.gd` keys a rigid transform of each arm ROOT (`_about` pivot, pos, euler) and
  `gun_viewmodel.gd:364-365` multiplies it in as `insp_r` / `insp_l`. The whole arm moves as one
  solid about the grip or the resting wrist: the shoulder leaves the body, the elbow never bends.
  A viewer reads that as a prop sliding, not a limb lifting.
- 16 keys over 3.0 s, smoothstep between neighbours, no holds: every key is a travel key, the
  eye never gets a still pose to study (the owner: "super fast"). Nothing holds while E is held.
- Cancel (`play_shot`, `play_gesture`, `play_reload`, `snap_rest`) calls `clear()`: identity in
  one frame, a snap.
- The gesture layer already has what a proper inspect needs: per-channel keys with ease
  (`arm_gesture_channels.gd`), a per-frame `ArmRig.reach` re-solve that keeps the shoulder and
  bends the elbow (`arm_gesture.gd:261-267`), a wrist flex/dev dress and finger curl/spread. It is
  left-arm only; the right arm has no `right_reach` dict and no runtime re-solve
  (`arms_builder.gd:258-264` solves it once onto the gun).

## How shipped inspects are built (industry, own words)

- CS:GO/CS2, MW2019, Apex, Destiny 2, Halo Infinite: a one-shot of 3 to 6 s on a press;
  fire, ADS, reload and sprint cancel it on the first frame, the gun is never "locked"; it is
  cosmetic only. The weapon turns about its own axis near the screen centre so it stays in
  frame; each side is shown with a moving hold (0.6-1.2 s of near-stillness with micro-motion)
  between travels of 0.4-0.8 s.
- Tarkov check-chamber/check-mag: the hand does the work, the gun tilts to make room; the hold
  at the thing to read (the chamber, the mag window) is the longest beat.
- Games that show the player's own arm (Dying Light's forearm, Cyberpunk's cyberarm, Far Cry 3's
  tattoo arm, Dead Space's suit): the arm comes up to the upper-centre third of the frame, the
  hand about a third of the screen height, turns back-of-hand to palm about the forearm axis
  (supination), then the forearm rolls so the thing to read faces the eye; the head/camera does
  not move; a slight dip of the other hand (the weapon) gives room.
- Principles that matter here: anticipation (a small drop or wrist cock 0.1 s before the lift),
  ease out into every hold, ease in out of it, overlapping action (fingers settle 0.1-0.2 s
  after the hand stops), a moving hold (2-3 deg of slow wrist sway, the fingers keep the weave)
  so the pose never freezes, and follow-through on the return.
- Timing rule of thumb: travel beats 0.5-0.8 s; holds 0.8-1.5 s; the main hold (what the
  player came to see) the longest; a full pass 4-6 s. Sources: the two searches below plus
  general knowledge of the listed games; no source gave hard numbers, these are the common
  range.

## Held key: what the options look like

1. One-shot on the press, plays through, release ignored (CS:GO style).
2. Hold-to-view: the sequence plays to its main hold and stays there (micro-motion) while E is
   held; release blends back (0.3 s). Fits the Brief ("press E and leave it pressed ... so the
   player can check the models").
3. Loop while held: the sequence repeats until release (reads mechanical; rejected by research).

## Engine side

- Godot `Tween` (TRANS_*/EASE_*) is for runtime-chosen end values and chains, not for a keyed
  rig with per-channel holds; `AnimationPlayer` tracks need an authored timeline on bones and
  would fight the weave (which writes bones every frame). Our keyed channel sampler
  (`Channels.sample`: in/out/smooth/snap) plus the IK re-solve is the right fit: keys hold their
  last value, holds are two keys with the same v, eases are per segment.
- A right-arm re-solve needs the builder to return a `right_reach` dict (shoulder, elbow,
  wrist, pole, palm, hand_dir in rig space) and an ArmGesture-like `bind_reach` for `.R`; the
  gun then follows the hand (gun = f(wrist)) instead of the hand following the gun.

## Takeaways for the plan

- Replace the root offsets with keyed IK channels per arm; keep `ArmInspect`'s API (`play`,
  `clear`, `is_playing`, `step(now, pinned_t)`, `right_offset`, `left_offset`) so the viewmodel
  hooks stay (both `gun_viewmodel.gd` at 400 and `arms_builder.gd` at 399 lines are at the cap:
  new code goes in new RefCounted helpers).
- Beats: lift (anticipation + travel), back of hand hold, supinate to palm hold, forearm roll to
  the tattoo (the longest hold, held while E is down), optional gun turn, return.
- Cancel = blend out over 0.15 s, never a snap; fire/reload act at once.
- Measure with `arms inspect <t>` pins, `anim_series.py` (no dead frame, no jump), region
  boxes, a new pinned smoke view, close-up `arms cam` views.

## Sources

- https://bugnet.io/blog/how-to-fix-weapon-inspect-animation-blocking-firing-when-interrupted
  (cancel on fire/ADS/reload at once; inspect is cosmetic)
- https://bmc.thegnomonworkshop.com/workshops/animating-first-third-person-shooter-attacks-for-games
  (weight, overshoot, settle; readable exits and entrances)
- https://www.engadget.com/2012-11-08-infinity-ward-animator-talks-first-person-flourishes.html
  (stylise flourishes for fun over realism)
- https://docs.godotengine.org/en/4.2/classes/class_tween.html and
  https://dev.to/saltmire/tween-vs-animationplayer-in-godot-4-which-to-use-and-when-bpd
  (Tween for runtime values, AnimationPlayer for authored tracks)

## Report (intake job, 2026-10-10)

- Sections changed: Pass test (drafted), Scope, Current state, Option map, Open items,
  Decisions D1-D9 (from code / research / memory), Interview line.
- Review pass (as the implementer): (1) the right-arm re-solve needs a builder dict the code
  does not have: written into Current state as a fact and a phase deliverable, not a question;
  (2) the release-of-E behaviour is a real gap: question; (3) the beat order and whether the gun
  gets a beat: question; (4) the Pass test is drafted, so asked; (5) the tattoo's screen size at
  the hold needs the forearm radius in rig units: marked "→ phase 1 measures" with the rule.
- No second round needed.

## Idea report (idea job, 2026-10-10)

- Sections changed: Initial idea (timeline table + 11 pieces), Interview line, Open items.
- Sources: D1-D12, Brief, code greps: `tools/smoke/smoke_shots.gd:271` (pin loop, `aNN-arms-<pin>`
  naming), `scripts/debug/debug_arms_frame.gd:12-14` (AIM_ZONE), `arm_skin_layers.gd:55-56`
  (tattoo height 1.5 x radius, letters fill it), `arms_builder.gd:253-262` (palm_len x HAND_K).
- Review pass (as the implementer): (1) reach: the left shoulder (-1.35,-1.35,-0.3) with the
  1.27-unit wrist clamp cannot put the wrist in the upper-centre third (about 1.9 units away),
  so D6's framing and the Pass test's fixed shoulder conflict -> Q-B; (2) D10 (hold at the
  tattoo, release = return) and D11 (gun beat after the tattoo) do not say where the gun beat
  sits in a held sequence -> Q-A; (3) the left hand during the gun beat is unsaid -> Q-C;
  (4) gun roll angle: fixed from code (today's RIGHT_KEYS largest roll, read in phase 1);
  (5) hand size and tattoo depth: D6's rule, phase 1 measures (not asked).
- Plan size 18.7 KB of 20 KB; the Option map (about 2.5 KB) is deleted at the ready gate and
  Current state will be cut in Part C.
- Second round: not needed (nothing unbuildable once Q-A/Q-B/Q-C are answered).
