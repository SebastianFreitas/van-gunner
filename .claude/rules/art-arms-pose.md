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
Arm dressing (`ArmsBuilder.dress_style`, console `arms dress gear|rags|none`):
`gear` (default) is one wrecked T-shirt sleeve on each arm (`ArmSleeve`, a
skinned tube on the upper arm only, hem torn and open just above the elbow at
`DEF-upper_arm.001` t 0.72, hem rings weighted to the upper arm only) plus the
skin layers: the van-name tattoo in faded block letters on the LEFT lower
forearm (where the player camera sees it), scars, wounds, dirt. Owner
(2026-10-02): no rings, straps, bands or other bolt-ons on the arms; "the
sleeve is enough". `rags` is the old rag and glove dress. Skin layers paint
in LINEAR colours (the skin albedo is a `source_color` uniform) from the
rest-pose chart in CUSTOM1/CUSTOM2; cloth tints are `source_color`. Gear is
built after the arms join the camera (facing angles need it). `arms gear`
checks each sleeve's own-bone (upper-arm) skin through every pose and must say
`GEAR OK`.
Gun inspect (owner 2026-10-03): hold E 0.4 s looking at nothing usable;
`ArmInspect` turns gun and right arm about the grip (left side, rolled to the
right side, forearm sweep and roll), then the left hand up (back, palm,
forearm inner and outer), 3 s, rigid root offsets on top of the weave; shot,
reload and gestures cancel it; identity under SaveSandbox; `arms inspect
<sec|play|off>` pins it.
