# monster-arm-interact: phase 1 rounds (baseline)

## Reach numbers (`arms reach`, left root space, rig units, 1 = 18 cm)

k 1.2000 · a 0.7442 · b 0.6058 · R 1.3229 · d 1.3229 · wrist_off 0.01124 · S 0.0000

- Space: all of it in the left root's space (the space of `model.get_parent()`); k is
  |to_rig.basis.x| walked up from the skeleton; the hit is `camera.to_global((0, 0, -0.9))`
  brought into the left root; shoulder is to_rig times the `DEF-upper_arm.L` global pose origin.
- FLAG: S 0.0000 is below 0.10 (no slack: d equals R, the rest wrist sits on the clamp).
- FLAG: wrist_off 0.01124 is not below 0.001 (the rest wrist is not LEFT_SHOWN_WRIST; the
  seed-jittered shoulder plus the 0.98 clamp moved it).

## ANIM SERIES (`arms weave 1.1` pre, 12 steps, region bottom40, defaults)

| kind | duration | verdict | min / max / mean | dead | jumps |
|---|---|---|---|---|---|
| press | 0.40 | JUMPY | 4.40 / 18.92 / 12.16 % | none | 1,2,3,4,5,7,8,9,10,11 |
| knock | 0.62 | JUMPY | 5.04 / 26.80 / 13.84 % | none | 1,2,3,4,6,7,8,9,10,11 |
| push | 0.48 | FLAT+JUMPY | 0.00 / 20.12 / 12.13 % | 5,6 | 1,2,3,4,7,8,9,10,11 |
| pull | 0.52 | JUMPY | 1.12 / 19.37 / 12.80 % | none | 1,2,3,5,6,7,8,9,10,11 |
| slide_open | 0.52 | JUMPY | 1.89 / 22.71 / 14.97 % | none | 1,2,3,5,6,7,8,9,10,11 |
| slide_close | 0.52 | JUMPY | 1.92 / 17.95 / 13.19 % | none | 1,2,3,5,6,7,8,9,10,11 |

Series folders: `%TEMP%\p1\series-<kind>`.

## `arms frame` at each contact pin (`arms gesture <kind> contact`, weave 1.1)

- press (0.12): 15.4% box x 0.17..0.77 y 0.36..1.00 upper 3.0% aim 23.9% BAD aim
- knock (0.14): 19.7% box x 0.03..0.77 y 0.36..1.00 upper 4.7% aim 34.4% BAD aim
- push (0.16): 14.6% box x 0.13..0.77 y 0.38..1.00 upper 2.5% aim 18.2% BAD aim
- pull (0.16): 13.9% box x 0.13..0.77 y 0.41..1.00 upper 2.4% aim 18.6% BAD aim
- slide_open (0.16): 14.0% box x 0.12..0.77 y 0.41..1.00 upper 2.5% aim 19.5% BAD aim
- slide_close (0.16): 14.0% box x 0.12..0.77 y 0.41..1.00 upper 2.5% aim 19.5% BAD aim

## Baseline sets

- Shot set `g00`: `.godot/shots/g00/` (118 views, gitignored).
- Rest dump: `.godot/shots/g00/dump-rest.json` (22 bones R, 22 bones L, palm_len 0.1978;
  `arms weave 1.1`, `arms gesture off`).
- Stills (times 0.07, contact, contact+0.1; series verdict OK, no dead, no jumps):
  - `%TEMP%\p1\stills-press\s-00.png s-01.png s-02.png`
  - `%TEMP%\p1\stills-pull\s-00.png s-01.png s-02.png`
  - `%TEMP%\p1\stills-slide_open\s-00.png s-01.png s-02.png`
- Frame shots: `%TEMP%\p1\frame-<kind>.png`.
- Before stills, read once (press contact): the left claw hand is raised past the crosshair
  in the upper middle, wrist well above and behind the fingers, the forearm a long diagonal
  from the lower left; the fingers hook over empty air, not touching anything.

round 00 · baseline

round 02 · worse: press at contact barely moves (look-judge FAIL twice, lean 0.20 then 0.29; hand ~150 px below, ~120 px left of the crosshair, same size) where g00's slide at least reached the crosshair · why: S = 0 (rest wrist on the reach clamp), so the IK only re-solves the baked pose; a 0.29-unit lean along dir (0.25, 0.22, -0.94) is mostly depth and too small on screen · solve: owner decides (see state Blocker). Numbers: press 0 / off dumps 1e-5 vs rest; arms frame press 0.22 cover 9.4%, box y 0.58..1.00, aim 0.8%; compare g00 g02 arms-g-press changed 3.01; series 0:0.40:12 JUMPY (max 11.1%), 24 steps JUMPY (max 7.98%: changed% saturates, D32); stills %TEMP%/p2/stills-press-fb/s-0{0,1,2}.png.

round 03 · same: gesture keys are six channels (reach, pole, lean, wrist, curl, spread) with eases in/out/smooth/snap, press unchanged · why: refactor (press wrist (-4.8035, -8.8665) = the old euler (-10,0,0) to the 1e-4 dump bound; the other five kinds converted mechanically, lean = 0.25 x |pos|) · solve: none. Numbers: press 0.07/0.22/0.32 dumps vs before max 1e-5; off / press 0 vs rest dump 1e-5; check and smoke CLEAN; compare g02 g03 arms-g-press same, knock/push/pull/slide_open changed (3.4/2.9/2.8/2.8), 08-elevator-stop-back changed 0.351 (tol 0.218, not an arm view); series press JUMPY 1-11, knock/pull 1-4, slide_open 1-4,10,11, slide_close 1-4,10, push FLAT+JUMPY (D34, not a gate); spread sign +1 (index +, ring/pinky -), verified afterwards by numbers (D40): spread (25, 12) at press 0.07 widens the index-pinky .03 joints 0.322 -> 0.392, ring stays between, motion in the palm plane; the 08-elevator-stop-back change was a flake (re-capture g03b vs g02 0.139, same).

round 04 · worse: at 0.12 the hand box top y is 0.59 vs 0.62 at rest (spec wants greater), the wrist cock (-25, 8) lifts the hand while the reach pulls it back · why: flex - is up, the coil reach -0.25 moves the wrist back/down only a little in screen y · solve: none yet, owner to judge. Numbers: nine-time ratio 3.6 (steps 1-3 mean 304 %/s, steps 4-8 mean 1102 %/s), dump off 0, press 0 1e-5, g00 vs g04 only arms-g-* changed.

round 05 · worse: press contact hand reads lifted, not deep (look FAIL twice, fallback between: pole (-1.6,-1,0), recoil -0.16, slam turn 0.4); it settles through the camera; knock rap 2 drifts nearer · why: the D36 ray point at R from the lunging shoulder sits barely deeper than rest (wrist z -0.245 vs -0.226) and the slam frame tips the claws up to the crosshair top (claw y +0.1 over rest); the settle passes near the eye (wrist z -0.125 at 0.32) · solve: owner blocker (strike deeper along the ray, land below the crosshair, or defer the depth read to phase 8). Kept: splayed flight hand (0.17), knock fist, one-joint wrist in hand shots (7/7). Numbers: check and smoke CLEAN, rest dumps 1e-5, g04 vs g05 press 2.12, knock 4.07, push 4.13 changed, all else same; knock rap check step 8 15.37% < mean 20.65% (D42).
round 06 · worse: press and push contact hand read hooked and cocked back, the coil looked like rest, press slumped at 0.32 · why: contact flex 15 to 20 with curl -10, wrist snap ease in, coil reach -0.25 · solve: contact flex 10 and curl 0 held to the settle, wrist snap 0.17 to 0.22, coil reach -0.35 (keys only; look not yet judged)
round 12 · worse: the pull yank reads shallow, the wrist is only 0.10 nearer at 0.36 than at 0.22 (spec 0.25); series JUMPY 1-7, 9-13 (D34, not a gate) · why: pull snatch frame via `Strike.frame` on `_posed == pull` (hand_dir dir + DOWN 0.15 + RIGHT 0.2), keys as 540e078 (coil, splay (14, 7), clamp curl (65, 70, 40) 0.22 to 0.27, yank reach 0.65 at 0.36, release 0.40 to 0.46); the yank ends back near rest depth (-0.232 vs rest -0.226), and the fallback yank reach 0.55 changed z by 0 (-0.2319 both) and cover 22.7% to 22.1% · solve: owner judge; s-0.27 claws read curled over the crosshair, not hidden. Numbers: g06 vs g06b (same code) still differ (12-rear-park-stop-outside 7.27, 07/08/10 0.5 to 0.9), so the stray views are wall-clock flakes, press/push/knock views same; rest dumps off / press 0 vs dump-rest 1e-5; cover pull 0.22 19.7%, 0.36 22.7% (reach 0.55: 22.1%); wrist z 0.22 -0.3353, 0.36 -0.2319.
round 13 · worse: the pull contact frame (0.22) shows the open flight hand, look judge 6/10 on "clamped" · why: the curl clamp only began at 0.22 (flight key at 0.22, clamp at 0.27) so the claws were still splayed as the hand hit · solve: flight key (-20, -20, -15) at 0.19, clamp (65, 70, 40) reached at 0.22 ease in and held to 0.40, spread falls to 0 by 0.22, SNATCH_RIGHT 0.2 to 0.3 (the plan fallback).
round 14 · worse: the `arms frame` box x centre does not move (slide_open 0.26: box x 0.00..0.88 centre 0.44; 0.42: 0.02..0.88 centre 0.45, delta 0.01 vs the 0.12 gate; after both fallbacks, strike 0.90 (a + b) and slide s peak 0.70: 0.26 centre 0.44, 0.42 0.03..0.88 centre 0.455) · why: the box covers both arms and the sweeping forearm (right arm holds the right edge at 0.88), so it cannot see the hand; the 0.42 still shows the hand ~0.19 of the width right of its 0.22 position (x ~680 to ~960 px of 1440); series JUMPY slide_open 1-8, 10-13 and slide_close 1-8, 10-13 (D34, not a gate) · solve: D54 (auto) fallbacks kept; owner judge or measure the hand, not the box.
round 15 · worse: the round 14 box metric was blind to the hand, so both D54 fallbacks (strike 0.90, slide peak 0.70) were applied for nothing · why: the `arms frame` box spans both arms (right edge fixed at 0.88); measured on the left wrist in camera space (probe eval, fov 50, 1440x720): slide_open 0.26 wrist x 0.411 of the width, 0.42 x 0.561, delta 0.150 >= 0.12 with the plan values (strike R, slide peak 0.55) · solve: hand x check; fallbacks reverted, plan values kept; check and smoke CLEAN, series JUMPY 1-8, 10-13 (D34, not a gate).
round 16 · worse: look check FAIL, line 1 5/10 (pull and slide_open bend at the elbow at 0.22, claw high), line 2 4/10 (0.12 still the coil, no splay in flight; press contact bunched), line 3 PASS 7/10 · why: the settle (4824bde) and re-press (65026f1) do not touch the strike; the flight key sits after 0.12 · solve: plan fallback once, coil pole (-1.0, -1.2, 0.6) (8a6f04d; coil 0.13 and strike pole were already in).
round 17 · worse: look check FAIL again, same scores (5/10, 4/10, 7/10), only the coil reads clearer against rest · why: the fallback moves the coil pole, not the contact elbow or the flight timing · solve: none left in the plan; run stopped (Blocker, Q1).
round 18 · worse: pull/slide elbow bend and no flight splay at 0.12, press bunched at contact · why: coil ended 0.13 and spread opened only at 0.19, finger straighten erased the fan · solve: coil keys end 0.10, splay 0.12-0.19 (press/push held to 0.22), straighten keeps the fan; pull/slide already shared press's far-crossing target so no aim change (p8-5)
round 19 · worse: none, cleanup only (phase 9) · why: the root-slide path was already gone after phases 3-8, so only `SLAM` (every kind is a slam kind, `_live` now needs just bound and a hit) and stale header/key docs were left · solve: removed the `SLAM` alias (KINDS is the literal), rewrote the `arm_gesture.gd` header (joint channels drive a per-frame ArmRig.reach re-solve, root only leans), documented the `slide` channel in the keys; arm_gesture.gd 300 to 299, keys 290 to 291; check/smoke CLEAN, 3 dumps diff 0.0, anim_series press/pull JUMPY only, g08 vs g09 arms views same

## Summary (phase 10 close-out)

- Look checks: phase 2 owner-passed as the IK proof (D38); phase 5 line 2 PASS 8/10, lines 1 and 3 held; phase 6 PASS 7/10 after the D53 fallback (clamp 0.19 to 0.22, snatch RIGHT 0.3); phase 8 line 1 accepted by the owner at 7/10 (D60, flat snatch sleeve left as polish).
- Final `arms reach` (phase 1, never re-measured): k 1.2000, a 0.7442, b 0.6058, R 1.3229, d 1.3229, S 0.0000 (rest wrist on the clamp, hence the D30 coil and the 0.29 lean).
- Final durations: press 0.52, push 0.55, knock 0.66, pull 0.65, slide_open 0.71, slide_close 0.71; CONTACT 0.22 for every kind.
- Shot sets: `g00` is the baseline, `g09` the final; stop views 07/08/10/11/12 differ run to run (D61), every `arms-*` view and pose dump matched g08.
- Hand frames: slam 0.4 turn toward up (`SLAM_UP`; the plan's 0.6, cut in round 05), snatch DOWN 0.15 + RIGHT 0.3 with SNATCH_SINK 0.15; the root lean caps at 0.29.
