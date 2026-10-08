---
paths:
  - "scripts/player/arms/arm_bulk.gd"
  - "scripts/player/arms/arm_claw.gd"
  - "scripts/player/arms/arm_finger*.gd"
  - "scripts/player/arms/arm_knuckles.gd"
  - "scripts/player/arms/arm_muscle.gd"
  - "scripts/player/arms/arm_skin_*.gd"
  - "scripts/player/arms/arm_materials.gd"
  - "scripts/player/arms/arm_refine.gd"
  - "scripts/player/arms/arm_rig.gd"
  - "scripts/player/arms/arm_parts.gd"
  - "scripts/player/arms/arms_builder.gd"
  - "scripts/player/arms/viewmodel_fov.gd"
  - "scenes/player/*.gdshader"
  - "scenes/player/*.gdshaderinc"
  - "scripts/combat/gun_viewmodel.gd"
  - "scripts/debug/debug_arms_hands.gd"
  - "scripts/debug/debug_arms_wrist.gd"
  - "scripts/debug/debug_arms_frame.gd"
  - "scripts/debug/debug_arms_dump.gd"
  - "scripts/debug/debug_arms_cam.gd"
  - "tools/stipple.py"
---

# Art style: the first-person arms (mesh and skin)

The general 3D rules are in `art-3d.md`; motion, grip, dressing and
inspect are in `art-arms-pose.md`.

One owner exception (2026-10-01): the first-person arms are the CC0
low-poly rigged model `assets/models/arms/arms.glb`, posed by `ArmRig`
and skinned only with the grime shader as `material_override` (no bitmap).
Its claw-nails (`ArmClaw`) are smooth-shaded, 12-segment arcs that hug
the fingertip from the tube's own recorded rings (`tip_rings`), sunk 3 %
into the skin so they never float, then taper to a point curving 15-30
degrees toward the pad (owner, 2026-10-03: the old 6-sided horns floated
and looked too low-poly).
Knuckles (owner, 2026-10-04, third pass: finger-tube knobs read first as a
row of teeth, then as round lumps; wanted an old labourer's muscular hand):
the knuckle is the palm's own skin. `ArmKnuckles.apply` (run in
`ArmBulk.inflate` before `ArmMuscle`) lifts the back of the palm into a ridge
at each `.01` head (`PEAK` 0.15 mean head spacing, about 0.25 finger radius)
and sinks a groove midway between heads (`GROOVE` 0.16), both running back
three quarters of the palm bone and thinning to a 0.35 tendon line. The
finger tubes carry no ball: `ArmFingers` root knob 1.0 r on the axis, shaft
knobs 1.07 r2 and 1.06 r3, and a squarer bony ring (lateral squash 0.86,
diagonals pushed out 1.10, pad 0.80). The ridge, the two knobs and the
ring knots were trimmed on 2026-10-05 (`PEAK` from 0.18, knobs from 1.12
and 1.10, `KNOT` 0.30 to 0.22: the owner found the joint bumps "a bit
extreme", and minor, so the trim is small). Thumbs take the same bony ring,
lumps, knots and sag (owner, 2026-10-04) but keep their own radii and
profiles, so grip and pose are untouched. Both hands share the code.
Knuckle creases and back-of-hand tendons are shading only (owner's
reference: stacked wrinkle folds, tendons fanning from the wrist):
`arm_skin_folds.gdshaderinc` adds a signed relief to `skin_height` from
rest-space joints and cords that `ArmSkinFolds.apply` sets per arm with
no rng draw; it never reaches vertex(), so it cannot cover a claw. Veins
read by shade as well as tilt (`vein_shade`, `vein_wrist`, `vein_wrap`).
No rig mesh casts a shadow (`ViewmodelFov._walk`, and `ArmSkinMesh.build`
at creation): the shadow pass skips the viewmodel lens, so one would land
off its mesh. The dark patch on the back of the left hand was the dirt
layer, not a cast shadow and not the wound (`sk_dirt` off: hand back 59
to 85; `sk_wounds` off: no change), so `dirt_tone` is lifted and the
dirt mix eased to 0.6: hand back 59 to 75, against 86 with no layers.
White and dark pixels on the arms (owner, 2026-10-05: "these white
pixels"; dashed straight lines and dots along the veins on the left
forearm and wrist) had two causes, both in `arm_surface.gdshader`:
- Dashed lines were false vein-centre pixels. `vein_field` took the
  distance as `abs(v) * fw / fwidth(v)`, a rest-space scale over a
  CUSTOM0 screen derivative, so the ratio jumped on triangle edges. It
  now uses the noise-space distance `abs(v) / |grad|` from the analytic
  gradient of `noise21g`: vein-paint outliers (tilts off) wrist/forearm
  1288/645 down to 140/119, and the vein paint stays as strong.
- Dots along the vein borders were the vein tilt's sub-pixel slope. The
  vein slope is damped by its own per-pixel change (`VEIN_TILT_DAMP`
  200), which keeps 0.96/0.91 (wrist) and 1.00/0.96 (forearm) of the
  tilt shading.
Light/dim outlier pixels counted on the skin only (views `arms cam
orbit 0 70 0.2 left` and `0.4 left`)
went from wrist 503/705 and forearm 218/363 to 333/278 and 183/178.
The floor with both tilts off is 265/49 and 126/67. What is left is
the skin tilt's wrinkle grain in shadowed patches, kept on purpose:
damping the skin tilt the same way removes about half its shading
(s5 to s10 kept 0.62 to 0.74). `MAX_SKIN_TILT` and `tilt_normal`'s
`det` divide, NaN return and footprint fade (`TILT_FOOT_MIN` 0.02 to
`TILT_FOOT_FULL` 0.10) stay as guards only. Judge by the skin-masked
counts: a whole-image count in these views holds about 2500 HUD-text
and sleeve-cuff pixels.
Wrist (owner, 2026-10-05: the hand looked "glued to the wrist", the
join "a bit thinner"): the forearm necks to `ArmBulk.WRIST_END_GAIN`
1.30 (was 1.45), and the hand side starts at that same girth by
construction: `DEF-hand`, the palm bones and the thumb root start at
`WRIST_END_GAIN / HAND_SCALE` and swell to full over `HAND_RAMP_END`
0.45 of the bone, so no step is left where the 1.47 hand
(`ArmBulk.HAND_SCALE`, which `ArmsBuilder.HAND_K` reads) meets the
forearm (the step was 1.45 against 2.13).
Thumb root (owner, 2026-10-05: "a piece of skin just in the air coming
out of the root of the thumb"): the thumb tube's head ring was open and
lifted off the palm, so `ArmFingers._shaft_profile` gives the thumb two
more rings behind its head that narrow back into the palm (0.80 r at
0.15 of a bone behind the head, 0.45 r at 0.35): a buried root, like
the fingers'.
Thumb-root hump (owner, 2026-10-08, left hand, thumb straight): it was the coarse blight dome field (`blight_height`, gain 20, accept 0.55 on the hand) in `skin_height`, not mesh, knots or folds (blight off removed it; knots/folds off changed nothing); the hand's coarse term is now halved (`mix(1.0, 0.5, hand)`), so never raise coarse blight gain on the hand without a straight-thumb shot.
One fixed hand (owner, 2026-10-05): skin tone, scars, wounds and dirt
hash from ArmsBuilder.HAND_LOOK_SEED, never the van seed. Muscle lumps,
the shoulder offset and each finger's sideways crook hash from
HAND_SHAPE_SEED 1337, the seed the posture and the claws were tuned
under, for every van seed. Never change it or swap the crook for a
table: seed 7 with a hand-picked table turned the left hand 1.7 degrees
and moved its fingertips sideways up to 0.015, a posture change the
owner forbids. The skin shader's `seed_offset` is shape too: it places
the wart domes `arm_surface.gdshader` lifts out of the skin along the
normals (and shifts the veins and grime mottle), so the builder sets it
to the constant `HAND_SKIN_OFFSET` 91.165, seed 1337's draw. On seed 7's
2.32 the domes sat on the index, middle and ring fingertips and swelled
them over the claws (crop pixels differing from the pre-branch shot:
8693 of 40000, 290 with the constant) while the finger mesh, bones and
claw boxes were equal: a swallowed claw can be shader lift, so compare
the material's uniforms as well as the mesh. Only the thumb claw grows
out of a cuticle fold: its tube's dorsal skin swells CUTICLE_H 1.20 just
behind the nail root and drops onto the plate. The four fingers have no
fold (owner, 2026-10-05: the nails were "swallowed by the finger", only
a tip showed; "the nails were kinda fine"): a finger claw rises out of
the skin from tip-bone t .36 to .60 (ArmClaw.BED_FROM), so a fold at .48
stood above its root. Any skin fold must end behind the claw root and
never rise above the claw; check claw top minus skin top, not the look
from far away. Only the tattoo text and the cloth still follow the van.
Fingers (owner, 2026-10-04: joints read as a line, "each bone a piece
instead of a hand"; wanted gnarled, tree-like, saggy old meat): each finger
is one gnarled tube with no pinch at the joints (end rings `.78` and `.92`
stay near knob radius, `_ring_weights` blends 0.3/0.7). Lumps are sharp
knots, never round blobs (owner, 2026-10-04: "very round"): a slight
`LUMP_RING` 0.03 wobble plus sparse single-vertex `KNOT` peaks (noise above
`KNOT_SPARSE`, crowded toward the joints; hashed by finger, bone, ring and
sector, no rng draws) and a palm-side `SAG`. The skin shader's `skin_bump`
is cone cell-noise knots (`knot_height`, flat skin between, hard base
crease). Keep them rare and uneven, never a grid (owner: "looks like a
pattern"): 18% of cells, a radius and height per knot, and an fbm warp in
`knot_at`. Mesh `KNOT_SPARSE` 0.88. Plus fine wrinkle fbm in rest space, on skin only, never nails or
other materials. Thumbs get the same knots and sag.

Viewmodel scale and lens:

Viewmodel surfaces under 0.4 m from the camera on the 0.18-scaled arms
rig are the one exception: grain about 60/m virtual, mottle about 6/m,
ribs 2..3 cm, with the same albedo, roughness and metallic budget.
The arms draw through their own 50 degree lens (`GunViewmodel.VIEWMODEL_FOV`,
`scenes/player/viewmodel_fov.gdshaderinc`): the include must keep the signs
of `PROJECTION_MATRIX[0][0]` and `[1][1]` (Godot Vulkan bakes a Y flip in, so
[1][1] is negative); a positive focal term drew the arms rotated 180 degrees
while `arms frame` (Godot-native `fov_override`) still counted them right.
After any lens change, Read one player-view shot.
