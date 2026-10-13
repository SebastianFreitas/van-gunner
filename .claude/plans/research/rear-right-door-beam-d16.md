# rear-right-door-beam: folding the owner's 2026-10-13 answers (apply job)

## Numbering

The caller asked for D16 and D17, but the plan already had auto D16 (beam width 0.175, crest band)
and D17 (own raw-steel grime, rod values) from the phase-1 rebuild, and the state file cites them.
To keep those references valid the new decisions are D18 (beam = bottom beam copy), D19 (judge
Pass test (1) on g48) and D20 (auto: cabin-side depth only). D16 and D17 are marked superseded
where D18 replaces them.

## Sections changed (plan)

- Interview line: 2 blocker answers (D18, D19) and the `missed:` line (new crude beam instead of
  copying the bottom beam).
- Pass test "Judged on": g48 only, g02 context (D19).
- Scope In: `rear_door_donor_beam.gd` gains a shared run helper and `build_edge`; Scope Out: bottom
  beam's look and place stay; the molle panel width may shrink only if it collides.
- Decisions: D16, D17 marked superseded; D18, D19, D20 added (D18 quotes the owner).
- Initial idea: "a copy of the bottom box beam (D18)".
- Constraints: beam material comes from the beam file by construction; compare allows donor-leaf
  views (rear-in plus f04/f05, as phase 1 found); look checks on g48.
- Progress: row 1 `todo (partial df98866)`, rows 2 and 3 renamed, Rests on D18.
- Phase 1 rewritten (2 specs: shared builder plus `build_edge`; edge helper trimmed, straps and
  Handle moved). Phase 2 shrunk to welds at the L joint plus real straps. Phase 3 opens with the
  rod render diagnosis and a shift rule for its old numbers; Grip/Mount/swing bullets collapsed.
- Carry forward: g48, beam face -0.23, x 2.473..2.648; first-build note.
- Size: 19 505 bytes (cap 20 KB); biggest phase 1 and 3 at about 2.38 KB each.

## Sources and working

- `rear_door_donor_beam.gd`: HEIGHT 0.175, LIFT 0.08, TOP = 0.255 (y -1.275 with rect y -1.53),
  END_SET 0.04, CAP_T 0.015 (caps 1 cm larger), BACK_Z = CABIN_Z - 0.06 = -0.23, front
  STREET_HALF + 0.065 = 0.145 (a through box: shows on the street face too), material block
  grime (0.17, 0.17, 0.18) plus shader values, `_corner` diamond beads, `_bolts` hex rows at
  pitch 0.42 on both long faces. `_Welds.add_box(st, size, at, angle)` rotates about z.
- Upright: x = 2.688 - 0.04 - 0.175 .. 2.688 - 0.04 = 2.473..2.648.
- Bend: cut x + y = 2.688 + 1.80 = 4.488; outer END_SET inside: 4.488 - 0.04 x sqrt 2 = 4.431;
  inner 4.431 - 0.175 x sqrt 2 = 4.184; mitre corners (2.648, 1.783), (2.473, 1.711); far end
  highest corner at y 2.01.
- Swing: cap corner (2.653, -0.24) radius 2.664; Handle mount corner (2.6305, -0.275) 2.645;
  both under 2.692.
- Molle panel x1 = 2.688 - MOLLE_SIDE_BEAM 0.25 = 2.438; crest edge 2.468 per Current state,
  0.5 cm off the beam's 2.473: auto shrink (x1 2 cm in, donor only) if it collides.
- Phase 3 shift: rod 2.595 -> 2.5005 (dx -0.0945), z +0.01; guides 2.476..2.525 stay inside the
  beam; Grip 2.5305..2.5905 clears rod edge 2.513 by 1.75 cm. Top keeper x+y 4.22..4.325 sits on
  the bend face (4.184..4.431).

## Review pass findings

1. Cabin-only vs through-box copy (the bottom beam shows on the street face): settled as D20
   (auto) from D2 "from the inside" and Scope Out "the street face"; the cabin view is identical.
   Not asked (Questions: auto, a Recommended-equivalent choice).
2. Two overlapping boxes at the mitre would put two cabin faces at -0.23 on top of each other (an
   audit FLICKER row): phase 1 spec 1 requires a cut mitre with a `_corner` bead (from
   van-geometry Seams constraint).
3. Old D17 found same-as-bottom-beam grime read like the rusty stock leaf: the owner's D18 asks
   for the same look outright, so it stands; noted as a risk for the look-judge, no question.
4. Phase 3's numbers were worked for the 8 cm beam: a shift rule was added rather than re-deriving
   every line (size budget); its stale "4.505 - 2.6195" keeper note is covered by the shift rule
   and the bend face check above.
5. Plan was 20 199 bytes after the fold: trimmed D16's superseded detail and phase 3's Grip, lever
   and swing bullets into one line; now 19 505.

## State file

Status phase-done, Next phase = phase 1 redo per D18 with the first action, Questions none,
Blocker none, Architecture's stand-in line marked as replaced by the redo.
