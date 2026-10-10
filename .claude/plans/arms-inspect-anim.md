# arms-inspect-anim

Stage: done
Started: 2026-10-09
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: full
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: C done · 11 asked · ready-gate reviews folded (D29-D39) · missed: which way the tattoo letters run on screen at the main hold (along the forearm vs across it); the 1 % stillness bar against the hold sway (D34 vs D4)
Questions: auto

## Brief (owner's words, verbatim)

need you to make a detailed plan, to fix one of our animations
if you press E and leave it pressed we do a suposedly chekc the arms animation, right now its super fast and its not an animation we just moving the arms assets around, i want a proper guy checking his arms animation, so that the player can check the models, see the tatoo, it should trigger as it does now.

your goal is to make the plan super detailed and stop, leave the execution for another model, when ur done i will /clear and send a prompt to the new model, but on this same worktree to actually realize the plan, you can follow the logic of the current plan, but use your own brain do research, im sure theres somehting better out there.

## Pass test (owner-approved, D12)

- The left arm bends at the elbow: it reads as the goblin lifting his hand to look at it, not an arm sliding across the screen. (Amended D22, D29: the shoulder slides toward the crosshair with the lift and stays through the back-of-hand, palm and tattoo holds, so the whole inspect reads as the hand coming up to the eye; every exit takes it back with the hand.)
- At the main hold the tattoo letters face the camera, large and readable at 1920x1080 (D47: the letters run along the upright forearm and read sideways; accepted, no head-tilt clause) (letter height at least 2.5 % of frame height, measured on the pinned still), just below the HUD crosshair and never under it (D31); the pose holds still enough to study (hand-and-gun region change under 5 % per 0.3 s, D51) from 3.4 to 4.9 s and again after 7.2 s while E stays down (D34).
- Every beat eases into a hold and out of it; no frame-to-frame jump; cancel and release blend back, never snap, except the gun and right hand on a shot: they jump to the aim pose on the shot's frame while the left arm still blends back over 0.15 s (D30).
- Judged on: player view pinned with `arms inspect <t>` at the back-of-hand hold (1.1), the palm hold (2.3), the tattoo hold (4.0), the gun holds (5.5, 6.3) and 0.15 s after a cancel (`arms inspect cancel 0.15`); `tools/anim_series.py --cmd "arms inspect {t}"` over the full pass must print `ANIM SERIES OK`; `arms cam left` and `front` close-ups at the tattoo hold, `arms cam side` at 6.3.

## Scope

- In: `scripts/player/arms/arm_inspect.gd` (rewritten) plus new RefCounted helpers next to it, new `scripts/debug/debug_arms_inspect_px.gd`, the inspect hooks in `scripts/combat/gun_viewmodel.gd` and `scripts/player/fps_player.gd`, `arms inspect` debug hints and `debug_arms_reach_end.gd` pins, one pinned smoke view in `tools/smoke/smoke_shots.gd`, `.claude/rules/art-arms-pose.md` "Gun inspect", `docs/glossary.md`.
- Out (stays exactly as is): everything the Untouchable constraint names, the wrist routine, kick, reload, the HUD, `scenes/player/player.tscn`, materials and lights.

## Current state (explored 2026-10-10; anchors drift, grep the names; "the digest" = `research/arms-inspect-anim-02-geometry.md`)

- Units: rig units, 1 = 18 cm (`gun_viewmodel.gd:11`); camera at origin, −Z forward, +X right; `VIEWMODEL_FOV` 50: frame half-height at depth z is 0.466 z (540 px), half-width 0.829 z (960 px).
- `gun_viewmodel.gd` frame order (:302-334): weave (frozen under SaveSandbox) → kick → `_gesture.apply_bones()` → `_inspect.step(_kick_clock, debug_inspect_t)` → `_apply` (:360): `gun_x = m * insp_r * cant`; the right root rides `gun_x`, the left root gets `insp_l`.
- Left IK: `ArmRig.reach(model, ".L", shoulder, wrist, pole, hand_dir, palm_n)` (`arm_rig.gd:89`): wrist clamped to 0.3..0.98 (a 0.744 + b 0.606); the pole is a direction; the roll is shared with the twist bone (`TWIST_SHARE` 0.5). The builder's `left_reach` dict: pole `LEFT_HANG_POLE`, palm (1, 0, 0); sampler `arm_gesture_channels.gd` (ease in/out/smooth/snap, holds its last key). Fingertip: `DEF-f_middle.03.L` plus meta `fingers.f_middle.tip_len`.
- Tattoo: LEFT forearm band centred 0.235 unit back from the wrist, letter height 1.5 × forearm radius r, on the face toward the camera at rest (`arm_skin_layers.gd:40-89`).
## Open items

- review leftover: the 27 px letter check is loose; phase 1 records the px, nobody tunes it.

## Decisions

- All D1-D39 are folded into Constraints and the phases (`(D<n>)` tags). Owner: D23 phases run as written; D29, D30 (2026-10-10) slide from the lift on, gun snaps on a shot. Reviews: Part B rounds 1-2 D17-D22; Part C round 1 D24-D28; ready gate build 9, design 4, art 3 findings D31-D39. `(auto)` decisions collect here. Phase 1: D40-D42 tuning (ROLL_B4 -45, slide 0.07 less, W4.y 0.086), D43 travel series uniformly JUMPY with no pop (fast real motion, repeatable pins), D44-D46 look fallback (beat 4 hand_dir (0.95, 0.31, 0), W4.y -0.004, own beat 4 shoulder key 0.08 less slide); details in the rounds file.
- D47 (owner, 2026-10-10, phase 1 Q1): accept the tattoo letters along the forearm, reading sideways at the 4.0 hold; Pass test line 2 is judged on facing the camera, size and placement under the crosshair, not on reading without a head tilt. No layout change, the pose stays.
- D49 (auto, phase 3): `arms inspect cancel 0.15` is the end of the 0.15 s blend, so it equals rest by construction (R ratio 100 %); the cancel look is judged on pins 0.04/0.075/0.11 instead, and the R-change ratio is not used (a changed-pixel count saturates mid-blend, 103.8 % at 0.075).
- D50 (auto, phase 3): cancel fallback applied, w eases smoothstep (ease-out read as a gun snap mid-cancel); look check round 2 PASS. Wrist slivers in `arms cam left` 4.0 are already in phase 1's still (not a regression).
- D51 (owner, phase 3 Q2): keep the 1.5 deg hold sway; the stillness bar is every hold step under 5 % of R (was 1 %, D34): the hold still reads as studyable and alive.
- D52 (auto, phase 4): `07-elevator-stop-front` (0.140/0.106 vs p4-a, same 0.068 vs p4-b) and `08-elevator-stop-back` (0.730/0.664 vs p4-b, same vs p4-a) are run-to-run noise at the elevator stop, not the inspect; tolerances left alone (out of Scope).
- D53 (auto, phase 4): `probe.py --shot` renders 1440x720, so the HUD box is counted at x 16..195, y 608..704; the only diff vs `arms inspect off` is a 100 px corner block where the resting gun's edge sits at rest and leaves during the inspect (crop check), so the inspect never enters the box: HUD line passes. Earlier rounds' 0 counts used 1080p coordinates on the 720p image (vacuous).
- D54 (auto, phase 5): `RIGHT_KEYS`/`LEFT_KEYS`/the left pivot already left `arm_inspect.gd` in 6b4a122 (phase 2b); phase 5 archived them verbatim into round 0 and removed only `duration()` (nothing called it). `_right_pivot`/`_about()` stay: they are the live gun turn about the grip. `a19-arms-inspect` compared changed (0.087, then 0.151 vs tol 0.086) while two captures of the same tree differ by as much: render noise, so the 0.086 tolerance (twice one measured noise) is too tight; left as is (D26: TOLERANCE moves only in phase 4).
- D55 (auto, phase 5): the gun series reads JUMPY (dead none) at `--dead 0.0005` where round 4 said FLAT+JUMPY; the holds measure 0.26-0.41 %, and with `--dead 0.003` it reads FLAT+JUMPY on identical numbers, so round 4 ran the default dead; every number is within 0.05 points of round 4: unchanged.
- D48 (auto, phase 2): the right arm re-solves every frame from 0.10 s, the dip included (the plan's every-frame re-solve keeps the shoulder put), so the right arm moves slightly differently in beats 1-4 than in phase 1; the left arm's 4.0 numbers are unchanged.

## Initial idea (Part B; the numbers live in the phases)

Times are seconds after `play_inspect` fires (0.4 s after E goes down). Beat timeline (D3, D11, D14, D29):

| Beat | Start | Travel | Hold | End |
|---|---|---|---|---|
| 1 anticipation dip | 0.00 | 0.10 | 0 | 0.10 |
| 2 lift to back of hand (shoulder slides in) | 0.10 | 0.60 | 0.80 | 1.50 |
| 3 turn to palm | 1.50 | 0.50 | 0.80 | 2.80 |
| 4 roll to the tattoo (main) | 2.80 | 0.60 | 1.50, then waits for E | 4.90 |
| 5 gun turn, left side; left hand half-drops | 4.90 | 0.50 | 0.40 | 5.80 |
| 6 gun turn, right side | 5.80 | 0.50 | 0.40 | 6.70 |
| 7 gun back, hand settles at the tattoo | 6.70 | 0.50 | waits while E is down | 7.20 |
| release return | any | 0.30 | | |
| cancel (shot, reload, gesture) | any | 0.15 (gun at once on a shot) | | |

Pieces (building phase):
1. Trigger as today, plus a release hook (3).
2. Anticipation dip (1 keys it, 3 sets its depth).
3. Lift to the back-of-hand hold with the shoulder slide (1).
4. Turn to the palm hold (1).
5. Roll to the tattoo, the main hold (1, polish 3).
6. Gun dip and cant with the lift (1, 2).
7. Gun turn left then right, the left hand half-drops (2).
8. Held state at the tattoo while E stays down (3).
9. Release and cancel blends (3).
10. Pins, series and the smoke view (1, 3, 4).

## Walk-through

- Pieces 1-10 · That is it · D13-D16

## Constraints (every phase)

- Method (D7): each phase appends one round per commit to the rounds file `research/arms-inspect-anim-01-rounds.md` (`arms inspect <t>` numbers at the pins 1.1, 2.3, 4.0, 5.5, 7.5, the `anim_series` verdict lines, the stills' paths, worse/why/solve); phase 1 first captures `shots.py capture inspect-before` on the untouched tree; every phase compares against it and quotes the rear-door and `a` view diffs; `TOLERANCE` changes only in phase 4 (D26).
- Untouchable (D8): `arms_builder.gd` hand constants and rest posture, the hand design, the weave, the gesture files, the trigger (`fps_player.gd` hold E 0.4 s `INSPECT_HOLD_TIME`). Under `SaveSandbox` the inspect is identity and writes no bone (D7).
- API (D1): `ArmInspect` keeps `play`, `clear`, `is_playing`, `step(now, pinned_t)`, `right_offset`, `left_offset`; the inspect re-solves each frame with `ArmRig.reach`, root offsets only for the gun. `gun_viewmodel.gd` ≤ 400 lines, `arms_builder.gd` < 400: new code goes in RefCounted helpers.
- One owner of the arm bones (D36, `arm_gesture.gd:220-222`): while the inspect plays or blends out nothing else solves the arms; the frame it stops writing (not playing, pin -1, sandbox, blend weight 0) it does one restore solve to the `left_reach`/`right_reach` inputs (the gesture's `_solved` flag), then writes nothing.
- Timing (D3, D4): channels ease `out` into a hold and `in` out of it; fingers lag the hand 0.15 s; every hold carries a wrist sway, 2.5 deg amplitude, 2.2 s period, dev axis; the weave keeps running on the fingers; no frame is ever still.
- Reach (D15, D19, D21, D29, D32): the left shoulder slides from `LEFT_SHOULDER` (-1.35, -1.35, -0.3) 0.98 unit along u = (0.675, 0.675, -0.30) over beat 2's travel to S' = (-0.69, -0.69, -0.59) and stays there through beats 3 and 4 (D29); beat 4 (D31) puts the band centre at B = (0, -0.062, -0.9), 80 px below the crosshair, wrist W4 = B + 0.235 f = (0.03, 0.17, -0.93), slide 0.98 for c 1.171 (elbow 120 deg, D25); the inspect solves with its own pole (0.2, -1, 0), elbow down (D32, digest "Pole"); every exit blends the slide out with the hand. The limb tail is never driven.
- HUD (D6, D27, D32): at the pins a phase judges, `probe.py --shot` stills vs `arms inspect off` show 0 pixels differing by more than 12 inside the GO/EASY box x 24..292, y 912..1056 (`run_hud.tscn:122-136`; a PIL count in the rounds file, `gap_check` counts magenta only); fallback: pole x +0.2, once.
- Series (D33; digest "Series thresholds"): every `anim_series` run adds `--out <scratchpad>/series/<phase>` and `--region 0.2,0.2,1,1` (R: hand, gun, bottom right; GO/EASY outside); a series crossing a hold adds `--dead 0.0005`; the gun window gets `--jump 0.15`. The full bar (`--cmd "arms inspect {t}"`): `--times 0:7.2:37 --dead 0.0005`, the gun window `4.9:7.2:47 --jump 0.15`, the stillness series `3.4:4.9:6` and `7.4:9.0:6` (every step under 5 % of R, D34, D51), the cancel series `--cmd "arms inspect cancel {t}" --times 0:0.15:6`, each OK. A step over the bar more than twice both its neighbours is a pop to fix at its key, anything else is D (auto).
- Hold E (D10, D14): the tattoo hold is the resting view; nothing loops; the gun beat plays once after the tattoo's first 1.50 s.
- Plan rules (D9): `Questions: auto`; a look FAIL gets the phase's fallback once, then the judge again; no invisible polish.

## Progress

| # | Phase | Kind | Needs | Status |
|---|---|---|---|---|
| 1 | Left arm IK path, look proof | code | - | done fe667f8 (look check PASS after D47) |
| 2 | Right arm reach and the gun turn | code | 1 | done 0c75b1d |
| 3 | Dip, lag, sway, release and cancel; mid look check | code | 1, 2 | done 9cf8535 (look PASS; stillness passes D51's 5 % bar) |
| 4 | Smoke view, reach-end pins, full series; last look check | code | 3 | done a82f1cc (last look check PASS) |
| 5 | Delete the old root-offset path, docs | code | 4 | done c7aee00 (5cc3d55 cleanup, round 5 unchanged) |

## Phases

### Phase 1 · Left arm IK path, look proof (pieces 2-6; D1, D3, D6, D10, D21, D29, D31, D32, D37)

Deliverables (two specs; reads to design `arm_gesture.gd:136-195, 229-267`, `arm_inspect.gd`, the digest):
1. New `arm_inspect_solve.gd` (per side: model, suffix, reach dict; `solve(shoulder, wrist, pole, hand_dir, palm_n)` with the gesture's delta save/re-add; `dress(wrist_fd, fingers, spread)` as `_dress` minus the live straighten; `restore()`, D36) and `arm_inspect_keys.gd` (LEFT channels: shoulder, wrist, hand_dir, palm_n (slerped), fingers, spread; beats 1-4).
2. `arm_inspect.gd` adds the IK path (old keys stay until phase 5): `play` runs the timeline and waits at the beat 4 hold; `step` samples, solves, dresses, restores once when it stops; `left_offset` identity; `right_offset` the gun dip (phase 2's keys, D6). The constructor takes `HeldGun.GRIP`, both arm models and `_roots` (`gun_viewmodel.gd:132`; `left_reach` from `_roots`, D28). New `scripts/debug/debug_arms_inspect_px.gd` prints with `arms inspect <t>`: L, tip, hand-centre and band px (`debug_arms_reach_end.gd:_margin`), z, r, elbow deg, palm dot, face dot.

Numbers (digest). Beat 2: W2 = (0, 0, -0.97) − 0.5 L · hand_dir, hand_dir (0.871, 0.490, 0), L = `ArmRig.palm_len(model_l)` × HAND_K; palm_n (0.2, -0.3, -0.93), back of the hand to the eye (D37). Checks at 1.1: hand centre within 60 px of centre; palm dot ≤ -0.8; elbow 60..100. Fallbacks: shift W2 by the miss; add the missing angle to the key; W2.z −0.1 per 10 deg under 60. Beat 3: palm_n turns 180 deg about hand_dir to (0, 0, 1) over 0.50 s, spread opens 0.15 s later; check at 2.3 palm dot ≥ 0.8, same fallback. Beat 4 (D31; B, W4, slide: Reach): palm roll turns the rest tattoo face to the camera. Checks at 4.0: band centre 60..120 px below centre, no letter in x 947..973, y 525..555; face dot ≥ 0.9; elbow 120..140; letters 1.5 r / (0.466 z) × 540 ≥ 27 px; fingertip y ≥ 40 px. Fallbacks: shift W4 by the miss and re-check the elbow (three tries); add the angle to the roll key; 0.05 unit less slide per 5 deg under, more over; hand_dir (0.95, 0.31, 0).

Verification: implementer: `check.py`, `smoke.py` (no view change); `arms inspect` numbers at 1.1, 2.3, 4.0; `anim_series` over the travels only, `--times 0.1:0.7:7`, `1.5:2.0:6`, `2.8:3.4:7`, each OK (D39: holds FLAT until phase 3); rounds 0 (old keys) and 1. `look-judge`: stills 1.1, 2.3, 4.0 and `arms cam left|front` at 4.0, Pass test lines 1 and 2.
Reviewed: Right (D23)
Notes: built fe667f8; look-judge PASS on lines 1 and 2 (session 1, stills `%TEMP%/p1b/`, HEAD 022f946) once D47 accepted the sideways letters. Probe 4.0: band centre 977,746 (206 px below centre, over the 60..120 key; strip top 581 sits 41 px below the crosshair, which the judge passed), elbow 125, face 0.96, palm dot -0.58. Judge watch item: grey letters on yellow, a highlight washes out "LAST".

### Phase 2 · Right arm reach and the gun turn (pieces 6, 7; D2, D6, D11, D14, D16, D17, D29, D38; Needs 1)

Deliverables (two specs; reads to design `arms_builder.gd:252-270, 346-352` and `arm_inspect.gd:12-21`):
1. New `arm_right_reach.gd` (static `inputs(gx, gun_style, shoulder_r) -> Dictionary`: shoulder, wrist = gx × right_wrist_in_gun × HAND_K, pole `RIGHT_POLE`, hand_dir and palm from gx.basis); `arms_builder.gd` calls it for its `ArmRig.reach(model_r, ".R", ...)` and returns the dict as `right_reach` beside `left_reach` (D2).
2. RIGHT channels in `arm_inspect_keys.gd`: the gun pose about `HeldGun.GRIP` as `right_offset()`; the right root rides `gun_x` (`_apply`), so each frame a second solver bound to `.R` and `right_reach` re-solves the right arm (D36) with shoulder = `right_offset().affine_inverse() * right_reach.shoulder`, wrist, hand_dir and palm the build-time values (gun = hand × grip offset, D2). Keys: 0.10..0.70 dip 0.1 unit, cant 10 deg out right, held to 4.90 (D6); beat 5 (4.90, 0.50 s travel, 0.40 hold): the left-side pose of `RIGHT_KEYS` (yaw 70 deg to the eye, grip (-0.25, 0.22, 0.30), D17); beat 6: today's right-side pose (roll 150 deg, D17); beat 7: back to the dip pose over 0.50 s, then the held state (D14). LEFT during beat 5's travel: wrist half-way from W4 to the rest wrist, shoulder half-way back (0.49 unit), palm_n toward the gun grip; beat 7's travel rises back to the beat 4 keys (D16, D29). `debug_arms_inspect_px.gd` adds `rwrist d/R` and the right forearm twist (hand vs `DEF-forearm.R`, deg from rest).

Numbers: the right wrist stays inside reach when |wrist − shoulder'| ≤ 0.98 (a_r + b_r) at every key. Check: `arms inspect 5.5` and `6.3` print `rwrist d/R` ≤ 1.0; fallback: scale the lifted grip offset toward the rest grip by the ratio, D (auto). Twist (D38, digest): check: twist ≤ 90 deg from rest at 5.5 and 6.3; fallback: cap the beat 6 roll at 90 deg of twist, D (auto).

Verification: implementer: `check.py`, `smoke.py`; `arms inspect` numbers at 4.0 (unchanged from phase 1 within 5 px), 5.5, 6.3, 7.5; `anim_series --cmd "arms inspect {t}"` over the travels, `--times 4.9:5.4:6`, `5.8:6.3:6`, `6.7:7.2:6`, each OK (D39); round 2 in the rounds file; one `arms cam side` still at 6.3 read once (shoulder put, forearm girth). `reviewer` over the two specs.
Reviewed: Right (D23)
Notes: built 6b4a122, fixed 0c75b1d (reviewer: the right forearm twist bone built up each frame; now reset). Probe: d/R 0.98 at 5.5 and 6.3 (pass, no fallback), twist from rest 6 / 2 deg (pass), 4.0 L band 977,746 elbow 125 unchanged. Series 4.9:5.4, 5.8:6.3, 6.7:7.2: even steps, no pop (JUMPY at --jump 0.15 recorded). Side still 6.3 `%TEMP%/p2/side/side.png`: shoulder stays put, no forearm pinch. D48.

### Phase 3 · Dip, finger lag, sway, release and cancel; mid look check (pieces 1-5, 8, 9; D3, D4, D5, D10, D30, D35; Needs 1, 2)

Deliverables (two specs; reads to design `arm_inspect_keys.gd` and `fps_player.gd:100-115, 140-165`):
1. `arm_inspect_keys.gd`: beat 1 (0.00..0.10): wrist 0.05 unit down, fingers key 30 (10 deg per joint); finger channels lag the hand's at every beat (Timing, D3); each hold adds the Timing sway (D4, phase continuous across beats) on the keyed wrist flex/dev.
2. `arm_inspect.gd`: a blend weight w on everything the inspect writes (bone deltas, the shoulder slide, `right_offset`): `release(now)` eases w 1 → 0 over 0.30 s (D10), `clear(snap_gun := false)` over 0.15 s (D5); with `snap_gun` (only `play_shot` passes true, D30) `right_offset` is identity and the right solver restores on that frame while the left still blends; `is_playing` stays true until w is 0; a blend-out samples the frozen pose it left, never the next beat. `gun_viewmodel.gd`: `_inspect` is an inert instance until the arms build (drops five null guards, pays for `release_inspect()`); `play_inspect` refuses while reloading, mid-gesture or `is_playing` (blend-outs included); `play_gesture` during a play or blend-out (D35): w switches to the 0.15 s rate, the gesture is queued for the frame w reaches 0, the call returns its contact time plus the blend left (`fps_player.gd:156-160` waits `delay`). `fps_player.gd`: every `interact` release calls `vm.release_inspect()` (`has_method`, a no-op unless playing). `snap_rest`: w = 0 at once, then the restore. Debug: `arms inspect cancel <sec>` (`debug_arms_commands.gd:92`) pins `<sec>` after a `clear()` from the 4.0 s pose; hint `debug_arms_hints.gd:15`.

Numbers: kick and reload cant compose with the blend-out in `_apply`'s order. Check: the cancel series OK (the blend ends at 0.15) and `arms inspect cancel 0.15` shows a pose between the hold and rest (R change 20..80 % of hold-to-rest); fallback: ease mode `smooth` on w, D (auto). Stillness (D34, digest): the stillness series passes; fallback: sway amplitude 1.5 deg, D (auto).

Verification: implementer: `check.py`, `smoke.py`; the full bar (Constraints, D33) OK; round 3 in the rounds file. `look-judge` (mid look check) on the stills 4.0, 5.5, 6.3, `arms inspect cancel 0.15`, `arms cam left` 4.0 and `arms cam side` 6.3, against the Pass test plus "right wrist and forearm keep their girth, no twist pinch" (D38); pictures to the owner.
Reviewed: Right (D23)

Notes: built d1cc449..9cf8535; look-judge round 2 PASS after D50; stillness (re-run in phase 4 at 03cbf01) still-a 3.71/1.03/2.40/4.55/4.66 %, still-b 4.72/4.93/2.64/1.24/4.34 %, under D51's 5 %.

### Phase 4 · Smoke view, reach-end pins, full series; last look check (piece 10; D7, D12, D18, D19; Needs 3)

Deliverables (two specs; reads to design `tools/smoke/smoke_shots.gd:270-285` and `debug_arms_reach_end.gd:15-76`):
1. `smoke_shots.gd`: its own block in `arm_views()` after `arms gesture off` (:285), the last `a` view so no earlier `a%02d-` stem renumbers (outside the pin loop, D18, D26): `arms inspect 4.0`, `_save("arms-inspect", "a")`, `arms inspect off` (the restore, D36). No shot bless: capture twice on the finished tree, `shots.py compare <a> <b> --raw`, write the `aNN-arms-inspect` stem's `TOLERANCE` at twice its noise (floor 0.05, tooling-shots.md "Re-measure").
2. `debug_arms_reach_end.gd`: beside the gesture samples, the inspect pins 1.1, 2.8, 4.0, 5.5, 6.3 (`vm.debug_inspect_t`, reset to -1 after, which triggers the restore), same OK/BAD lines, so `smoke_arms_prints.gd` fails smoke when the left tail's far end shows (D19; the shoulder at z -0.59 puts the tail end near z +0.6, behind the camera).

Verification: implementer: `check.py`, `smoke.py` (with `aNN-arms-inspect` saved, `REACH_END` clean, no BAD), `shots.py compare inspect-before <after>` listing only `aNN-arms-inspect`, the full bar OK, round 4 in the rounds file. `look-judge` (last look check) on the Pass test's full set (its line 4) against its three lines and the girth line (D38); pictures to the owner. A FAIL after one fallback blocks the run.
Reviewed: Right (D23)

Notes: cf68639 (smoke view `a19-arms-inspect`, REACH_END inspect pins 1.1/2.8/4.0/5.5/6.3 behind 0.23/0.23/0.12/0.33/0.33 OK), 6b06f2b (a19 tol 0.086, noise 0.043; compare vs inspect-before: only a19 new, D52), 03cbf01 (round 4 bar = round 3's), a82f1cc (stills `%TEMP%/p4/stills/`, HUD D53). look-judge PASS on all three lines and the girth line (`%TEMP%/p4/look.md`); watch: highlight washes out "LAST", gun buried under hands at 5.5, seam band on the right forearm in cam-left 4.0.

### Phase 5 · Delete the old root-offset path, docs (D1, D8; Needs 4, runs only after phase 4's look check passed)

Deliverables (one spec; reads to design `arm_inspect.gd` and `.claude/rules/art-arms-pose.md:36-40`):
1. `arm_inspect.gd`: remove `RIGHT_KEYS`, `LEFT_KEYS`, `_pose`, the pivots and `duration()` if nothing calls it (grep first); the old key tables go verbatim into the rounds file's round 0 (archive, never delete). `art-arms-pose.md` "Gun inspect" rewritten to the timeline, the slide, the down pole, the band 80 px under the crosshair, release 0.30 s, cancel 0.15 s (gun snaps on a shot), the pins and `cancel <sec>`; `docs/glossary.md`: "check the arms animation" = the gun inspect (`arms inspect`); `py -3 tools/gen_context.py` for the new scripts' rows.

Verification: implementer: `check.py`, `smoke.py` with no view change (`shots.py compare <phase 4's after> <after>` all same, `REACH_END` clean), the full bar unchanged from phase 4's, `wc -l` of `gun_viewmodel.gd` ≤ 400 and `arms_builder.gd` < 400; round 5 (final) in the rounds file. No look check: nothing visible changes.
Reviewed: Right (D23)

## Carry forward

- Phase 1 (fe667f8): the tattoo letters run along the forearm, so at the beat 4 hold (forearm upright) they read rotated 90 deg; the look-judge says only a tattoo layout change fixes it (Q1). Beat 4 now has its own shoulder key `SHOULDER_B4`; beat 2 keeps `SHOULDER_B2` (D46). The px probe prints strip top/bottom. Letter px by the probe formula is ~370-400 (plan expected >= 27; judge sees ~60 px letters): the formula overstates, record only.
