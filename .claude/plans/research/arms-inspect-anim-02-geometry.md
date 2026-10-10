# arms-inspect-anim · ready-gate geometry and series thresholds (2026-10-10)

Worked once for D29-D39; the plan carries only the results. Inputs: a 0.744, b 0.606 (`arms reach`),
`LEFT_SHOULDER` (-1.35, -1.35, -0.3), u = (0.675, 0.675, -0.30) (unit), `LEFT_HANG_POLE` (-1, -0.6, 0.2),
`ArmRig.reach` elbow = s + dh·x + pole⊥·h (`arm_rig.gd:117-126`), VIEWMODEL_FOV 50: half-height 0.466 z
(540 px), half-width 0.829 z (960 px); px(P) = (960 + x/(0.829 z)·960, 540 − y/(0.466 z)·540).

## Crosshair and band target (D31)

`run_hud.tscn:122-136`: `+` Label, font 22, offsets ±13 x ±15 → a 26x30 px box at (960, 540), i.e.
x 947..973, y 525..555. Band centre 80 px below: y = 80/540 × 0.466 × 0.9 = 0.062 unit at z 0.9, so
B = (0, -0.062, -0.9) → px (960, 620). Letters 27 px tall sit at 606..634, clear of the box.

## Band offset correction (build finding 7)

The band centre is 0.235 back from the wrist along the forearm (elbow→wrist), not along the
shoulder→wrist line. At elbow 120 deg (c 1.171) the forearm leaves that line by
acos((b² + c² − a²)/(2bc)) = 33 deg; 0.235 × sin 33 = 0.13 unit = 147 px at z 0.9. With the hang pole
and the on-line wrist (0.16, 0.10, -0.97) the band would land at px (882, 496), 147 px off B.

## Pole (D32)

With the hang pole the beat 4 elbow is (-0.36, -0.13, -0.95) → px (518, 694) and the upper arm runs from
the shoulder px (-389, 1890) to it, crossing x 24..292 at y about 992..1072: through the GO/EASY box.
Pole (0.2, -1, 0): elbow (-0.05, -0.43, -0.86) → px (897, 1119), below the frame; the upper arm never
enters the frame; the forearm enters the bottom edge at x ≈ 902 (beat 4) and 855 (beat 2). Same for
pole (0, -1, 0) (entry 892/836) and (0.4, -1, 0.2) (922/886): the result is not sensitive to the pole's x.

## Beat 4 solve (iterated: W = B + 0.235 f, lunge s for c = 1.171)

s 0.977 → S' (-0.691, -0.691, -0.593); W4 (0.029, 0.169, -0.928) → px (997, 329); elbow
(-0.046, -0.427, -0.855); band lands at px (960, 620) exactly. Hand from W4 along hand_dir (0.871, 0.49, 0):
L 0.35..0.45 unit = 400..500 px, fingertip near (1400, 100): inside the frame, hence the "tip y ≥ 40 px"
check with the flatter hand_dir (0.95, 0.31, 0) as fallback.

## Beats 2-3 with the slide (D29)

Hand centre at the crosshair, wrist depth 0.97 (same as beat 4, no zoom): W2 = (0, 0, -0.97) − 0.5 L
hand_dir. L 0.35 → W2 (-0.152, -0.086, -0.97) → px (778, 642), c 0.893, elbow 82 deg, elbow px
(905, 1361). L 0.45 → (-0.196, -0.110, -0.97), elbow 77 deg. Reach floor 0.3 (a + b) = 0.405: fine.
Unit per px: 0.00084 at z 0.97, 0.00078 at z 0.9.

## Palm keys (D37, art finding 1)

`_frame` (`arm_rig.gd:64-67`) orthogonalises palm_n against hand_dir: the dict's (1, 0, 0) minus its
hand_dir part is (0.49, -0.87, 0), in the screen plane → hand seen edge-on. Beat 2 palm_n
(0.2, -0.3, -0.93) (palm away from the eye, knuckles tipped to the light); beat 3 = its 180 deg turn
about hand_dir ≈ (0, 0, 1). Check: palm dot (palm_n · to-camera) ≤ -0.8 at 1.1, ≥ 0.8 at 2.3.

## Series thresholds (D33, build findings 1, 2, 6, 9)

- `anim_series.py`: `--out` required and outside the repo (:93-99); FLAT when a step changes under
  `--dead` (0.003) of the region, JUMPY over `--jump` (0.06) (:127-128); region `bottom40` or
  `x0,y0,x1,y1` fractions (:34-41). The probe runs `--smoke-sandbox`, so the weave is frozen at
  `WEAVE_SANDBOX_T` (`gun_viewmodel.gd:302-304`): only the inspect moves between frames.
- Region R `0.2,0.2,1,1` = px 384..1920 x 216..1080 (1.33 Mpx): holds the hand (x 700..1400, y 330..690),
  the half-dropped hand during the gun beat and the gun; excludes the GO/EASY box (x ≤ 292).
- Sway 2.5 deg, period 2.2 s: the slowest 0.2 s step (around a peak) turns the hand
  2 × 2.5 × (1 − cos(2π × 0.1/2.2)) ≈ 0.2 deg ≈ 2 px on a 480 px palm ≈ 3 000 px of edge ≈ 0.23 % of R:
  under 0.3 %, hence `--dead 0.0005` (0.05 %, 660 px) for any series crossing a hold. The fastest
  0.3 s step turns 2 × 2.5 × sin(π × 0.3/2.2) = 2.07 deg ≈ 17 px at the tip, 9 px average → about
  13 500 px ≈ 1.0 % of R before the dark-on-dark contrast cut (threshold 12): the 1 % stillness bar is
  borderline, so phase 3's fallback halves the sway to 1.5 deg.
- Gun window: 150 deg over 0.50 s eased is up to 22 deg per 0.05 s step mid-travel; at 0.2 s steps it
  is 30-60 deg and most of the gun's pixels change (JUMPY certain). Hence 0.05 s steps
  (`--times 4.9:7.2:47`) and `--jump 0.15`; a real pop is a step over the bar more than twice both
  neighbours (the per-step lines are printed, :121-124).
- Phases 1 and 2 have no sway, so hold steps are identical frames: series the travels only
  (0.1..0.7, 1.5..2.0, 2.8..3.4; 4.9..5.4, 5.8..6.3, 6.7..7.2). The cancel blend ends at 0.15 s:
  `--times 0:0.15:6`.

## Gesture during the inspect (D35, build finding 4, design finding 3)

`fps_player.gd:140-165`: `delay = vm.play_gesture(...)`, then `_interact_pending` awaits `delay` before
the door reacts. So the viewmodel can return the gesture's contact time plus the inspect's remaining
blend, queue the gesture to start when w reaches 0, and the interaction fires at most 0.15 s late
(0.30 s release blends switch to the 0.15 s rate from their current w). One owner of the bones, the
slide blends out with w, never a one-frame drop.

## Right forearm twist (D38, art finding 2)

`ArmRig.reach` shares the roll about the forearm axis with the twist bone (`TWIST_SHARE` 0.5,
`arm_rig.gd:145-154`): the 150 deg roll with a fixed shoulder and pole lands about 75 deg at the wrist
and 75 on the twist bone. Cap 90 deg at the wrist; fallback caps the beat 6 roll.
