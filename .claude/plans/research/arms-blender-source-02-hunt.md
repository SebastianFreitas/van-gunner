# arms-blender-source 02: defect hunt triage

Source: `TEMP/vg-p2/hunt2/{posed,rest}/hunt.txt` (commit 66cf90f0, `tools/blender/arms_hunt_bl.py`),
impl notes `TEMP/vg-p2/impl2.md`. TEMP = `C:/Users/Traff/AppData/Local/Temp`.
Slab s: 0 = DEF-hand head (wrist), 1 = DEF-f_middle.01 head (knuckle row), projected on the hand
axis, so forearm and fingertip values shift between poses (posed R elbow s=-1.2, L elbow s=-2.0;
rest elbow s=-3.0). "Bone" is the nearest bone head only (claws often name a palm or other finger).

## Totals (clusters / items)

| kind | posed | rest |
|---|---|---|
| inside_out | 4 / 12 | 4 / 674 |
| inside_out_all | 9 / 14994 (claws) | 10 / 16660 (claws) |
| sliver | 84 / 2409 (claw 10/1679, skin 66/721, fingers 8/9) | 50 / 1774 |
| spike | 66 / 74 (claw 10, fingers 23, skin 33) | 75 / 83 |
| crease | 423 / 1720 (skin 364/1381, fingers 57/311, tail 2/28) | 379 / 965 |
| hole | 48 / 1523 | 48 / 1523 (identical: topology) |
| hole_expected | 12 / 152 | 12 / 152 |
| coincident | 0 | 0 |

Posed has about twice the crease edges of rest (1720 vs 965) and 300 more slivers: the extra is
the posed-only (weight) groups D1, D2, D4 below.

## Defects

Format: id. what | where | pose | near | made by | verdict (confidence)

**Real (visible or likely visible)**

- D1. Elbow fold: skin folds back on itself, 179 deg creases plus a 118-edge 125 deg stepped ridge
  ("sharp stepped ridge across the forearm" in crease_R_skin_0_0) | R_skin and L_skin, DEF-forearm
  (elbow head), R s=-1.15/-1.46/-1.83, L s=-1.44/-1.46/-2.13/-2.28; also R_skin forearm slivers
  s=-1.05..-1.17 (ang 2.4-3.0 deg) | posed only (weight) | elbow, not a vein | glb elbow weights under
  `ArmRig.reach` bend (arm_rig.gd:89-168), girth from the elbow gain lerp (arm_bulk.gd:245-246) |
  real, may sit off-screen; check in a game shot (high that it exists, medium that it shows).
- D2. Right palm crush: 170-180 deg folds and 100+ slivers (ang 2.7) at the heel of the palm | R_skin
  DEF-palm.01..03 / DEF-hand, s=-0.05..0.11 (46 crease clusters/210 edges posed vs 27/50 rest;
  slivers hand 101 + palm.01 57 posed, 0 rest) | posed only on R (weight; the gun grip curl) |
  between the knuckle ridges' heel and the wrist seam | glb palm weights under `ArmRig.curl`
  (arm_rig.gd:172) and the dome/knuckle sculpt (arm_bulk.gd:268-276, arm_knuckles.gd) | real (high).
  hole_R_skin_0_0 shows dark cracks across this palm.
- D3. Skin cracks along veins: long chains of tiny boundary edges | R_skin DEF-hand s=-0.02 590 edges
  perim 0.25; L_skin DEF-hand s=-0.06 203 edges perim 0.17; R_skin DEF-forearm.R s=-1.12 15 edges
  perim 0.20; smaller ones at forearm .001 s=-0.26/-0.34 and L forearm s=-2.19/-1.59 | both
  (topology) | on the authored veins (wrist, back of hand, R forearm) | `ArmVeinRelief._mark`/`_split`
  key edges by vertex index (arm_vein_relief.gd:198-265, `_key` :282): across a UV or hard-normal
  seam the twin edge has other indices, is not split, and a T-junction opens; `ArmWeightSmooth.weld`
  (arm_weight_smooth.gd:116) only merges weights, not indices | real (medium-high; confirm by
  testing the loops for twin positions on a seam).
- D4. Finger joint folds: inner side of curled joints folds through itself (160-179 deg) | R/L_fingers
  .01, .02 and .03 of every digit, s=0.4-1.2 posed (about 30 clusters over 140 deg); rest keeps
  roots and thumb only (L thumb.02 171, R middle.01 177, R thumb.03 173) | mostly posed (weight),
  roots both | knuckle knobs / ring knots | ring weight blend `ArmFingers._ring_weights`
  (arm_fingers.gd:285, applied :252) on curl; root ones from `ArmFingerJoin.fillet`
  (arm_finger_join.gd:93) | real (medium: shows on the palm side of a fist).
- D5. Glb fingertip and finger core poking out: collapsed glb tips (ratio 35-66 slivers, about 40
  per digit, and spikes h1.3-4.2) | R/L_skin DEF-f_*.03 and thumb.03, posed s=0.4-1.4, rest s=1.6-2.0
  | both | inside the tubes; pale shards beside the index and middle claws in hole_R_skin_0_0 |
  TIP_CORE 0.05 and FINGER_CORE 0.55 shrink (arm_bulk.gd:36-40, applied :76-85 and :266) | mostly
  hidden false positive, but the posed shards show (medium).
- D6. Finger web and root seams: 2-edge holes plus tiny inside-out patches (area 1e-5) | R/L_fingers
  DEF-f_index/middle/ring/pinky.01, s=0.91-1.05 | both | finger roots | `ArmFingerWeb.build`
  (arm_fingers.gd:73, arm_finger_web.gd) and the fillet snap (arm_finger_join.gd:93) leave
  unshared verts | real but tiny (medium).
- D7. L ring finger whole tube inside out | L_fingers DEF-f_ring.01.L s=0.98, 664 faces, area 0.00158
  | rest only | ring root / web | probably one twisted web strip that makes Blender's normal recalc
  flip the connected tube (arm_finger_web.gd), so the true defect is small | not visible in
  rest/inside_out_L_fingers_0_0 (low).

**Likely false positives of the rule**

- F1. All claws inside_out_all (frac 1.00, 1666 faces each) | 9 posed, 10 rest; posed L_claw_ring is
  not flagged | both | `ArmClaw.mesh` winding (arm_claw.gd:95-124, built at arm_rig.gd:258-271) | the
  claw is an open shell (F2), so `recalc_face_normals` has no inside to anchor to, and the posed
  ring claw dropping out shows the heuristic is arbitrary. Check once with a back-face Godot view
  (medium).
- F2. Claw base holes, 34 edges each (perim 0.017-0.036) | every claw, s=0.6-1.4 | both | the root is
  buried in the skin fold by design (BURY, arm_claw.gd:84) | expected (high).
- F3. Claw slivers 94-208 per claw (ang 1.2-1.5, ratio 38-47) and claw spikes h7-11.5 | every claw
  | both | the tip fan onto the apex p2 and the thin edge strips (arm_claw.gd:117-123) | inherent to
  a needle tip (high).
- F4. Tail open end: 14-edge hole perim 0.35-0.37 and 2 creases 82.9 deg | L/R_tail DEF-upper_arm,
  s=-2.28 / -3.31 | both | it sits on the skin's cut shoulder ring (hole_expected, 16 edges,
  perim 0.355/0.371) | `ArmLimbTail.build` top ring (arm_limb_tail.gd:30) | expected, behind the
  camera; the hunt should list it as hole_expected (high).
- F5. Finger tip pole and ring knot spikes h0.6-1.8 | R/L_fingers .03 (pole), .02 and thumb.02
  (knots, h0.74-0.88) | both | `ArmFingerRing.cap` pole (arm_fingers.gd:162, arm_finger_ring.gd:44)
  and sparse knots (arm_finger_ring.gd:21) | intended shape (high).
- F6. Knuckle-row creases 75-98 deg and spikes h0.6 | R/L_skin f_index/middle/ring/pinky.01
  s=0.8-1.0 | both | inside the tube knuckle knobs | glb finger core ramp FINGER_RAMP
  (arm_bulk.gd:42, :266) under `ArmKnuckles.apply` (arm_bulk.gd:275) | hidden (medium).
- F7. Wrist and back-of-hand creases 75-81 deg (hand s=-0.6..0, about 60 clusters each run) and
  R forearm .001 creases/spikes (s=-0.4..-1.0, h0.6) | both | on the vein ridges and the wrist
  seam | `ArmVeinRelief.apply` (arm_bulk.gd:279) and `ArmWristRamp` | intended relief, just over
  CREASE_DEG; only the ones that coincide with D3 matter (medium).
- F8. Thumb creases 112-140 deg | L/R_skin thumb.03 s=0.6-1.2 | both | collapsed glb thumb tip
  (D5 family), hidden in the thumb tube (medium).

## Fix order for phase 3

1. D2 right palm crush (posed, in view while holding the gun).
2. D3 vein seam cracks (dark lines on wrist and back of both hands): make `_split` key edges by
   welded position, or weld seam indices before the split.
3. D5 posed glb tip shards beside the claws: hide or delete the glb `.03` skin rather than shrink it.
4. D4 finger joint inner folds (palm side of the fist).
5. D1 elbow fold, only if a game shot shows it.
6. D6/D7 finger web seams; then tighten the hunt rules for F1, F2, F4 (claws as open shells, tail
   end as expected) so phase 3's re-hunt is quiet.

## Close-ups worth showing the owner

- TEMP/vg-p2/hunt2/posed/hole_R_skin_0_0.png (palm cracks and glb tip shards, D2/D3/D5)
- TEMP/vg-p2/hunt2/posed/crease_R_skin_0_0.png (elbow/forearm stepped ridge, D1)
- TEMP/vg-p2/hunt2/posed/crease_R_fingers_0_0.png (finger joint fold, D4)
- TEMP/vg-p2/hunt2/posed/sliver_R_skin_0_0.png (posed palm or tip slivers, D2/D5)
- TEMP/vg-p2/hunt2/posed/hole_R_skin_1_0.png (R forearm crack, D3)
- TEMP/vg-p2/hunt2/rest/inside_out_L_fingers_0_0.png (L ring tube, D7)

Pictures read here: posed/hole_R_skin_0_0 and rest/inside_out_L_fingers_0_0 only; the others are
picked by cluster rank (index 0 = worst per object), not viewed.
