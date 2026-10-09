---
paths:
  - "scripts/player/arms/**"
  - "scripts/debug/debug_arms_*.gd"
  - "tools/hand_shots.py"
  - "tools/pose_sheet.py"
---

# Art style: the arms' motion, grip, dressing and inspect

Mesh and skin rules are in `art-arms.md`.

The hands never rest: `ArmWeave` (`scripts/player/arms/arm_weave.gd`)
rolls both hands' fingers index to pinky in hooked witch curls on a 3.6 s
period with a slow second harmonic, wrists circling, both hands
raised in front, palms down and inward; the free left thumb swings out
opposite the index and curls back toward its tip in an open C, as if holding
an invisible can (`LEFT_THUMB_*`, console `arms lthumb` tunes it live); it runs
through idle, walking, shooting and reloading, and holds still at t 1.1 under `SaveSandbox` so shots
compare (`arms weave <s>|off` pins it). With the gun shown the right hand
grips it instead (`ArmWeave._update_grip`: squeeze, trigger lift, thumb
wave), the thumb wrapping the grip's far side under the slide and pointing
forward, a C with the trigger finger (`RIGHT_THUMB_AIM`, `RIGHT_THUMB_CURL`);
`arms fit` prints the thumb's clearance from the gun parts and must say
`FIT OK`. `arms thumbs` prints per hand the thumb's angle to the index,
gap/p, hook, up and fwd against the bars in `debug_arms_thumbs.gd`, then
`THUMBS OK` or `THUMBS CHECK`.
Arm dressing (`ArmsBuilder.dress_style`, console `arms dress bare|rags|none`): `bare` (default) is
monster skin with no cloth, `none` the same without skin layers (owner, 2026-10-09: the T-shirt sleeve, `ArmSleeve` with `arm_cloth.gdshader`,
the `gear` dress and the `arms gear` fit check were removed; archived at git tag `archive/arm-sleeve`).
The skin is painted by the shader alone; no rings, straps, bands or other bolt-ons on the arms (owner,
2026-10-02). `rags` is the old rag and glove dress, opt-in for debugging only. Skin layers
(`ArmSkinLayers`: the van-name tattoo on the LEFT lower forearm, scars, wounds, dirt) run under
`bare` (default) and `rags`, not `none`, and paint in LINEAR colours (the skin albedo is a `source_color` uniform) from
the rest-pose chart in CUSTOM1/CUSTOM2.
Gun inspect (owner 2026-10-03): hold E 0.4 s looking at nothing usable;
`ArmInspect` turns gun and right arm about the grip (left side, rolled to the
right side, forearm sweep and roll), then the left hand up (back, palm,
forearm inner and outer), 3 s, rigid root offsets on top of the weave; shot,
reload and gestures cancel it; identity under SaveSandbox; `arms inspect
<sec|play|off>` pins it.
Interact gesture (`arm_gesture*.gd`, plan monster-arm-interact, 2026-10-09): six keyed
channels (reach, pole, lean, wrist flex/dev, curl, spread, plus `frame` and `slide`) from
`arm_gesture_keys.gd` tables drive a per-frame `ArmRig.reach` re-solve that keeps the
weave's wrist delta; each channel's ends equal the baked inputs, so t 0 and the end are the
weave's own pose and the restore solve changes nothing; the root only leans, at most 0.29
units. Slam (press, push, knock): palm along `dir`, hand_dir turned 0.4 toward up (`SLAM_UP`, cut from 0.6 in round 05) (about 34
deg of extension); snatch (pull, slides): hand_dir `dir` + DOWN 0.15 + RIGHT 0.3 (droop and
cant). Wrist flex/dev use `arm_wrist_routine.gd` FLEX_AXIS/DEV_AXIS; negative flex is
extension, knuckles to camera. The door reacts at `CONTACT` 0.22 for every kind (0.06-0.10 s
later than before); E while a gesture plays starts nothing (no restart snap). Yank sign:
slide_open yanks along rig +x × lat, slide_close along -lat (lat from camera x · van z).
Shoulder lunge numbers: `SHOULDER_LUNGE` 0.75, `FORWARD_LUNGE` 0.45 (was 0.5), `SNATCH_SINK` 0.075
(was 0.15); the hand-to-target distance (`arms reach-end` "hand" lines) rises about 0.018 m per 0.1
of FORWARD_LUNGE removed and halving SHOULDER_LUNGE costs 0.05 m more, so no further cut fits the
0.01 m budget. `arms reach-end` must print every sample OK with MIN behind at least 0.30 m.
Measure each change: `anim_series`, pinned stills (`arms gesture <kind> <t>`), `arms dump`
diffs, `tools/shots.py compare g00 g<NN>`; stop views 07/08/10/11/12 vary run to run.
