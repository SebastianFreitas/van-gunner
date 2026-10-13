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
  - "scripts/player/arms/**"
  - "scripts/debug/debug_gun_commands.gd"
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
read by shade as well as tilt (`vein_shade`, `vein_under`).
Pitfall: a wound is a long ellipse with a dark crust ring, so a big one reads as a pill outline; the old right wound 0 (z 0.049, r 0.047, stretch 1.9) was the owner's wrist pill and is deleted from `arm_skin_fixed.gd`; keep wounds small.
Veins are authored per arm from the owner's arm photos, not noise, each arm its own pattern (no mirroring):
- Data: `resources/arms/vein_set_left.tres` and `vein_set_right.tres` (`ArmVeinSet`: paths of chart x, v, radius; edit the .tres). Chart = `(x, 0.035 * atan2(z, y))` of CUSTOM0; back of hand is +v right, -v left.
- Sampler: `ArmVeinField` (height 0..1, distance), rounded profile, smooth-max join.
- Geometry: `ArmVeinRelief` (run in `ArmBulk.inflate`) refines and raises the skin along the veins.
- Cache: `ArmVeinRelief.apply` stores the finished arrays in `user://arm_vein_cache/<side>_<surface>.bin`, keyed on a hash of the packed vein set, the relief constants (`RELIEF_M`, `TARGET_EDGE`, `NEAR`, `MAX_PASSES`, `TILT_GAIN`, `ArmVeinField.BLEND`) and the incoming mesh arrays; a miss builds (about 0.5 s per arm), a hit loads (about 5 ms). Change a constant outside that list and the cache must be deleted by hand.
- Shading: `arm_vein.gdshaderinc` `vein_field` evaluates the same packed paths per pixel (uniform `vein_pts`, 160 points (`ArmMaterials.VEIN_MAX`; `set_veins` warns if a set packs more), `vein_count`; `ArmMaterials.set_veins` sets them per arm) and `arm_surface.gdshader` adds a fine normal tilt, a flank groove (`vein_shade`), a teal tint scaled by radius (`vein_under`) and a soft crest. No painted key light. `ArmMuscle` gives `DEF-palm*` and `DEF-thumb.01` mask 1.0 so veins reach the hand back.
- Pitfalls: the back-of-hand sign differs per arm; the pixel fade must use the chart's own footprint (`fwidth` of the chart), not rest-chart units; palm bones need the CUSTOM0.w mask; check a vein change by painting the mask red in a temporary shot.
No rig mesh casts a shadow (`ViewmodelFov._walk`, and `ArmSkinMesh.build`
at creation): the shadow pass skips the viewmodel lens, so one would land
off its mesh. The dark patch on the back of the left hand was the dirt
layer, not a cast shadow and not the wound (`sk_dirt` off: hand back 59
to 85; `sk_wounds` off: no change), so `dirt_tone` is lifted and the
dirt mix eased to 0.6: hand back 59 to 75, against 86 with no layers.
White and dark pixels on the arms (owner, 2026-10-05: "these white
pixels"; dashed straight lines and dots along the veins on the left
forearm and wrist) had two causes, both in `arm_surface.gdshader`:
- Dashed lines were false vein-centre pixels from a distance taken as a
  rest-space scale over a CUSTOM0 screen derivative, so the ratio jumped
  on triangle edges. `vein_field` (`arm_vein.gdshaderinc`) now measures
  distance to the per-arm packed paths (`vein_pts`) in chart units, with
  a footprint from `fwidth` of the chart and the palm bones masked in
  via CUSTOM0.w.
- Dots along the vein borders were the vein tilt's sub-pixel slope; the
  shader still fades the tilt where the pixel footprint collapses (see
  the footprint comments in `arm_surface.gdshader`).
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
and (before the sleeve was removed) sleeve-cuff pixels.
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
Thumb-root hump (owner, 2026-10-08, left hand, thumb straight): the mesh, not shading. `DEF-thumb.01`'s flat gain 1.5 met the thumb tube's 1.0 in a step at the joint, which a straight thumb shows as a hump (bent hides it); `ArmBulk` now eases thumb.01 from 1.5 to 1.0 over its far 60 percent. The hand's blight halving was reverted (owner: the skin must stay spiky and coarse); the straight-thumb spike itself is not found yet (mesh outlier scan shows none, 2026-10-08). Lead: a thumb.01 weight cliff on the wrist side of the root (b1151 0.84, b190 0.70 beside 0.9 forearm/palm verts rose 6 to 8 mm straight versus default); `ArmWeightSmooth` (run in `ArmBulk.inflate` after the refine) relaxes the thumb weight over those verts and weights only, so the skin stays coarse. Real cause of the dark knob in `arms cam side` (owner circle, left hand; the side cam frames the left hand there): not mesh. Elimination, changed pixels in the crop: arm skin hidden 9080, hand blight tilt off (`blight_gain`/`hand_blight_gain` 0) 5002, `skin_bump` 0 5168, muscle off 4668, finger tubes 2765, `blight_lift` 0 461, ArmWeightSmooth off 340, knuckles 59, claws/sleeve 0 (the sleeve is removed since 2026-10-09, archived at tag `archive/arm-sleeve`). The knob is the shader's screen-space blight tilt (`arm_surface.gdshader`, skin_bump block) going black on the shaded flank; the hand now keeps 40 percent of that tilt (the geometric blight lift is untouched).
One fixed hand (owner, 2026-10-05): skin tone, scars, wounds and dirt
hash from ArmsBuilder.HAND_LOOK_SEED, never the van seed. Muscle lumps,
the shoulder offset and each finger's sideways crook hash from
HAND_SHAPE_SEED 1337, the seed the posture and the claws were tuned
under, for every van seed. Never change it or swap the crook for a
table: seed 7 with a hand-picked table turned the left hand 1.7 degrees
and moved its fingertips sideways up to 0.015, a posture change the
owner forbids. The skin shader's `seed_offset` is shape too: it places
the wart domes `arm_surface.gdshader` lifts out of the skin along the
normals (and shifts the grime mottle; the veins no longer move with it), so the builder sets it
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
from far away. Only the tattoo text still follows the van.
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

Limb tail (spec 2, 2026-10-09): `ArmLimbTail` adds a 4-unit bare limb per arm behind the glb's cut shoulder ring (same radii, sinew bulge, taper, capped), skinned wholly to `DEF-upper_arm`, with the arm's own skin material, so a shoulder lunge never shows an end.

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

## The railgun

Brief: `.claude/specs/brief.md`; plan `.claude/plans/railgun-redesign.md`. Built by `RailgunBody` from `RailgunBarrels`, `RailgunReceiver`, `RailgunPivots`, `RailgunCoils`, `RailgunJunk` (+ `RailgunWear`) and `RailGlow`. Units are p (the hand's palm length), y above the guard top `ya`, zf the guard front.

- Composition (D42 look): a boxy panelled `Receiver` (half-width `HW` 0.22p, front face -1.28p = `RAIL_REAR` where the rails start, rear face +0.32p, `rust`): seven top panels (`TopFront`, `VentMid`, `VentEdgeL/R`, `TopMid`, `TopRearL/R`) around two vent openings (dark `VentFloor` plus three steel `VentSlat`s) and a breech channel (`BreechFloor`, `SlugRod` in steel); mismatched flanks (left: dark cut-corner `FlankPlateL`; right: olive `gun_paint` donor `FlankPlateR` with two `PlatePit`s; ribs and hex `RecBolt`s differ per side, the `RecSlot`s match). Behind it the chamfered `Stock` (+ `StockLow`, rust), the rubber `StockPad` (`grip_rubber`, rearmost part) and the `WindowFrame` (steel) round `Lamp0`.
- Rails: two flush rails of `worn_steel`, `LowerBarrel` (`LOW_R` 0.20p) and `UpperBarrel` (`UP_R` 0.32p, 1.6x the lower; both 0.19p half-width) with a `GAP_H` 0.17p open gap, from the receiver front to `ztip` = zf - 2.8p. Lower: `LowerBand1/2` (rust, steel), 32 dark `LowerSlot`s on its top; upper: `UpperBand0/1` (paint, steel) and a dark `UpperGroove` per flank. `GapGlow` (0.03p beam, `ember`) sits in the gap; `muzzle_in_gun` is centred in the gap 0.05p past the tips. `RailgunCoils` floats four square frames with a glowing `Field` disc in the gap (held at t 1.1 under `SaveSandbox`).
- Pivots (`RailgunPivots`, each origin on its hinge or slide line, meshes as children, ready for a later animation): `Breech` (`BreechBlock`, steel) slides +0.30 z later and uncovers the `SlugRod`; `VentL`/`VentR` rotate about Z on their outer long edge (the right flap `heavy_rust`, the left rust with a `VentFlake`); `ChargeCell` (`dull_alu`) rotates about Y on its rear vertical edge, swinging the front out toward the player; its `Lamp1` and two `CellBolt`s ride along and its cables (`CableUpper`, `CableLower`) end in dark holes on the hinge line so a swing leaves their ends put; `CableSag` is taped under the cell.
- Bounding box: tip zf - 2.8p, top ya + 1.07p (upper rail), width about 0.52p (receiver 0.44p plus the `ChargeCell`/`Lamp1` out to x -0.289p and the right `PlatePit`s at +0.23p); sockets, muzzle and the hinges never move, materials follow rng.
- Scale: the body is `MonsterGrip.GUN_K` 1.15 over the hand's `p`; grip, guard and trigger stay at `p` (owner, 2026-10-09).
- Wear homes: soot, rust and the tape band on the receiver and stock are painted by the shader (D42): `arm_wear.gdshaderinc` is included by `arm_surface.gdshader`, off by default (`wear_on` 0, so hands and arms never change), switched on by `ArmMaterials.with_wear(mat, spots, info)` with up to `WEAR_MAX` 6 spot/info entries set in `RailgunReceiver._wear`, each mesh passing its position as `instance uniform wear_origin`. Inside a soot or rust mask specular and metallic go to 0 (tape: specular 0.1, metallic 0). `arm_surface.gdshader` is at its 400-line cap: new shader code goes in the include. Box wear stays in `RailgunWear` (rust patches, flakes, `SplitGap` with three wire wraps, `BandDent`/`BandCurl`, `Scorch*`, `HangPlate`, flush on the rails and bound by their faces) and `RailgunJunk` (weld seams and plates, `PitLower`/`PitUpper`, `LooseBolt`, tape wraps: three on the upper rail, two on the lower). `ArmMaterials` has `heavy_rust` and `scorched_steel`; none of it sits in front of the muzzle or on a socket's snap z. Tread, brackets, chain, padlock and a sprayed word are gone (owner, 2026-10-09: keep the body clean so boons read).
- Sockets (`GunSockets`): Marker3Ds `Socket_<zone>_<letter>` in zones top,
  left, rear, muzzle, under, hang, right, with metas `size` (*p), `normal`,
  `zone`, `used`; `claim(body, zones)` takes the first free socket by zone
  preference. A socket starts inside the mesh it belongs to and snaps out onto
  that mesh's face at build (spec 5: offsets derive from `RailgunBarrels` and `RailgunBody`
  constants: top and muzzle on the upper barrel, left, right, under and hang on the
  lower barrel, `left_a` on the receiver flank, `rear_a`/`rear_b` on the `StockPad` rear face). It snaps to the mesh's bounding box, which is the
  box barrels' own faces now, so start each socket inside the mesh it belongs to.
- A boon gets a visual by a `GunBoonVisuals.REGISTRY` entry (zones plus a
  builder in `GunBoonPieces` that fits the socket's `size`). REGISTRY order is
  the order pieces are built and claim sockets. No glow unless it is a light.
- Glow: `GapGlow`, `Lamp0`, `Lamp1` (the third emissive, on the charge cell) and the coils' `Field` discs are the gun's only emissive parts; `RailGlow` owns the light. Its amber `LampLight` sits just off the stock's rear face at `Lamp0` (range `LAMP_LIGHT_RANGE` 0.50) and reaches the rear sockets; `Lamp1` only flares.
- Future pieces lie horizontal as part of the barrel (poison canister first),
  never upright add-ons; the current three pieces are upright and wait for that.
- Debug: `gun sockets|report|attach` (`debug_gun_commands.gd`). Smoke views
  `a-arms-gun`, `a-arms-gun-sockets`, `a-arms-gun-boons`,
  `a09-arms-gunfront-boons`, `a19-arms-inspect`; the player view sees the stock, receiver top and
  left flank, the inspect roll shows the sides: `py -3 tools/probe.py --cmd "arms inspect 5.4"
  --shot <png>` (left side) and `6.3` (right). Run `gun report` after any body change.
- Lessons: `claim(body, zones: Array[StringName])` is typed, so build zones as
  `Array[StringName]` (an untyped literal fails at runtime). Check sockets with
  `gun report` after any body-shape change (distances and box overlaps). A word
  on the gun, however well drawn, read badly; plain steel reads better.
