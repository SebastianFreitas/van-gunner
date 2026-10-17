# arms-blender-source: the model in Blender against D13, and monster-hand research (2026-10-17)

Goal (D13): "super buffed up monster hand, creepy with tendons and veins super salient, crooked
fucked up fingers, like a witch".

## The model in Blender (5.2.2 headless, `assets/models/arms/arms.glb` at 35348bd8)

Scripts and renders (scratchpad, not the repo): `C:/Users/Traff/AppData/Local/Temp/vg-arms-blender/scripts/review.py`,
`review_render.py`; PNGs in `C:/Users/Traff/AppData/Local/Temp/vg-arms-blender/review/` (Workbench, ortho,
right arm, wireframe over solid). In-game views (`tools/probe.py --cmd "arms inspect 1.1"` / `"2.4"`,
PROBE CLEAN after `tools/check.py`): `review/game/back.png`, `review/game/palm.png`.

- Counts, `ArmR` (by largest weight): 369 verts, 520 tris, all triangles. Hand (`DEF-hand`, palm
  bones) 69 verts / 92 tris; thumb 37 / 49; fingers 187 / 266; forearm 40 / 57; upper arm 36 / 56.
- Density, mean edge in glb units: fingers 0.026, thumb 0.037, hand 0.044, forearm 0.118, upper
  0.155. The hand from wrist to the middle finger root is 0.165 long, the forearm 0.505: the back of
  the hand is about 15 large triangles, the forearm three rings of about 8 sides.
- No materials, no images; one `UVMap`; a `custom_normal` attribute; `sharp_face`/`sharp_edge`.
- What each render shows (one line each, so nobody opens them again):
  - `hand_back.png`: a slim, human-proportioned mannequin hand; flat back of big triangles, no
    knuckle row, straight evenly spaced fingers, a plain 8-sided wrist ring.
  - `hand_threequarter.png`: the same from the thumb side; thumb a plain tapered prism, palm flat.
  - `hand_side_thumb.png`: the hand is thin in depth (a paddle), the wrist steps out to the palm.
  - `forearm_side.png`: a long, thin, straight forearm tube (3 rings), no muscle at all.
  - `game/back.png`: in game the hand is large and pale under the warm lamp, a broad smooth back
    with faint knuckle bumps, one faint vein line at the wrist, no tendons visible, fingers curled.
  - `game/palm.png`: fingers splayed with long dark curved claws; smooth palm and wrist, tattoo
    on the wrist; no vein or tendon reads.
- So every monster trait on screen today comes from game code at load, not from the glb:
  `ArmBulk` gains (forearm 2.1-2.8, `HAND_SCALE` 1.47), `ArmRefine` (one midpoint split),
  `ArmKnuckles` (ridge `PEAK` 0.24, groove 0.16), `ArmMuscle`, `ArmVeinRelief` (veins as real
  geometry: refines near a vein to 0.003 edges, raises `RELIEF_M` 0.014 mesh units, about 2.8 mm),
  `ArmSkinFolds` (4 back-of-hand tendons and knuckle creases, shading only), the shader's
  `vein_shade` 1.8 / `vein_under` 1.8 (`arm_materials.gd:38-40`). The glb's fingers are shrunk to a
  hidden core (`ArmBulk.FINGER_CORE` 0.55, `TIP_CORE` 0.05) inside code tubes (`ArmFingers`).
- Can the glb carry tendons and veins as geometry? Not at 69 verts: a tendon cord needs about 3
  vertices across and a ring every few mm. Either the hand is remeshed denser in Blender (weights
  repainted on the new points), or the cords go through the code relief that already refines
  adaptively near a path (`ArmVeinRelief`), which is how veins are geometry today.
- Fingers and crook: code only. `ArmFingerProfile.DIGITS` holds a frozen `tip_off` per finger
  (largest about 0.016 m) and `ArmFingers._crook` leans the finger about one joint to land it;
  the hands plan bars `tip_off` within 0.002. `arm_fingers.gd` is at the 400-line cap, so a
  crook change must split it first. `arm_surface.gdshader` is also at 400: shader work goes in
  an include.

## References (what we take, in our words)

- Nosferatu (1922), Count Orlok: long, knobbly, bent fingers with long nails, a bony back of the
  hand; the creepiness is in the silhouette of the fingers more than skin detail. Ours: crooked
  joints and big knuckle knots read in silhouette at inspect distance.
- Pan's Labyrinth, the Pale Man: loose skin over bones, fingers that bend the wrong way at a
  joint. Ours: a sideways kink at one joint and back at the next (zig-zag), tips held in place.
- Hellboy, the Right Hand of Doom: an oversized, heavy hand on a normal arm reads as power.
  Ours: the buff is girth at the knuckle row and palm, not length (bones fix the length).
- The owner's own 2026-10-05 reference (memory hands-one-fixed-design): root-like veins wrapping
  the wrist, tendons fanning over the back of the hand, knobby knuckles with stacked folds, dark
  claws. D13 matches it; the memory added "as thick as our hands" and "a bit looney / silly".
- Polycount, low-poly hand threads ([1](https://polycount.com/discussion/comment/683322),
  [2](https://polycount.com/discussion/comment/1452863)): game hands of 500-850 tris bake veins and
  knuckle wrinkles into a normal map from a sculpt; detail that is subtle in the sculpt vanishes
  in the bake, so salient forms must be exaggerated. Ours: exaggerate (cords and veins several
  mm proud), and note a baked map needs a bitmap, which `art-arms.md` rules out today.
- Witch character thread ([polycount](https://polycount.com/discussion/comment/2770043)): break a
  witch finger into clear sections and soften the nail where it leaves the finger. Ours: the
  claw root work is the hands plan's phase 6; nails otherwise stay.
- Displacement vs normal maps ([Wikipedia](https://en.wikipedia.org/wiki/Displacement_mapping),
  [polycount](https://polycount.com/discussion/comment/2748072)): displacement only moves
  vertices that exist and reads mostly on the outline; normal/bump fakes detail without
  changing the outline. Ours: geometry relief for the cords and the fat veins (outline and light),
  the shader's tilt and groove for the fine detail, as the veins are built today.
- [CG Cookie](https://cgcookie.com/community/6445-sculpting-a-hand-for-a-vr-game-how-much-detail):
  judge hand detail at its real on-screen size and angle. Ours: the owner's inspect views.

## Method options for the plan (geometry, map or shader)

1. Blender for the mass (girth, back slope, knuckle row, wrist), code relief for cords and veins,
   code for the fingers. Keeps the no-bitmap rule; reuses the vein relief machinery.
2. Code only: Blender gives tooling and the smooth widening; gains, relief and shading do the rest.
3. Blender sculpt plus a baked normal map: richest detail, but a bitmap through the grime shader
   (an art-rule exception) and a new texture path.
