# Arms dressing research (2026-10-02)

Owner's brief: details on the arms and hands that hide the hand mesh's problems; a bit of
clothing (short sleeves, long rags in the screen corners); the old turned-off dressing was ugly;
the right hand has gun parts going through it. The character: a mega-buff goblin humanoid
dressed as a gangster who is poor and redneck.

## Why the old pass failed
`ArmParts.sleeve/strap/wound/shard/scar` were free cylinders and boxes hung on the elbow-to-wrist
chord, not on the mesh or the bones: they floated, read as box soup, and never followed the hand.

## The method this pass uses
Shrinkwrap bands (`ArmWrap`): sample the inflated arm mesh's own cross-section around a bone at
fractions t, build a hard-edged tube just outside it, attach it to the bone. A band follows the
hand's flat section, overlaps its neighbour across joints, and rides the weave. Small bits (rings'
signets, knots, tape tails, rag segments, chain links) sit on `surface_frame` points of the same
sections, so nothing is placed by guess.

## The bar (checked each round)
1. Hugging: every band's offset is 0.05..0.22 of the bone's mean radius; no piece visibly floats
   in `a01..a04` (one look each, one line each).
2. Gun clear: `arms fit` prints `FIT OK` and `DRESS OK`.
3. Coverage: on both hands the palm, knuckle row and wrist are under a band (glove / boxer's
   wrap / tape); finger `.02`/`.03` and claws stay bare.
4. Readable in play: `01-idle-front` shows the glove, rings, tape and a rag tail on the gun hand,
   and the wrap or chain on the left hand where it is on screen; `shots.py compare before after`
   says `changed` for `01`, `02`, `a01..a06` and `same` for every other view.
5. Dark budget: `01-idle-front` mean within +0.004 of the before capture (`tools/shot_stats.py`).
6. Style: albedo under 0.40 on trims, under 0.25 on the sleeve body; hard edges; seeded.

## Rounds
- Round 1: specs `.claude/specs/1.md` (ArmWrap), `2.md` (ArmDress + materials + builder
  wiring + dead code removal), `3.md` (`arms fit` dress check), plus `4.md` and `5.md` fixing
  `ArmWrap.section` (11 of 15 bands never built: the slab sampler found no vertices because
  the arm mesh is low-poly with rings far apart, and a dominant-bone test dropped twist and
  finger `.01` bones; now summed weights >= 0.35 and per-sector interpolation between the
  nearest ring below and above t). Result: bar 1 fails on the rag tails only: five
  disconnected flat boxes per tail float above the forearm (`a01`, `a04`) and cut into the
  elbow end (`a03`); glove, rings, tape, sleeve hems, boxer's wrap, bandage and chain hug.
  Bar 2: `FIT OK` but `DRESS CLIP 21`, because the AABB overlap test counts every glove band
  on the hand that holds the gun; no visible clip. Bar 3, 6: pass. Bar 4: back and stop views
  also `changed` (the arms are on screen in every first-person view), `a02` `same` under its
  1.0 tolerance. Bar 5: `01-idle-front` mean 0.0611 before, 0.0609 after.
- Round 2: `6.md` rags as connected strips between surface points (knot on the skin, tails
  0.05..0.14 r), `7.md` dress clip test by vertices buried inside a gun part box instead of
  AABB overlap, `8.md` the buried depth on the finger test's scale (0.10 p) with the depth
  printed. Result: bar 1 passes: the tails lie as one strip along each forearm (`a01`,
  `a04`), the left wrap and chain hug (`a03`). Bar 2: `FIT OK`, `DRESS CLIP 1`: the glove's
  palm band reaches 0.16 p into GripCore (24/288 vertices) on the palm side where the palm
  itself presses the grip; nothing shows through the gun in `a01`. Open: trim glove faces
  whose vertices lie inside the gun, or accept the palm side. Thumb band 0.07 p and middle
  ring 0.02 p are under the bar. Bar 5: `01-idle-front` mean 0.0608.
