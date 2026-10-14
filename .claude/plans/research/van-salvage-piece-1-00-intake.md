# van-salvage-piece-1 · intake digest (2026-10-13)

## The owner's reference image (read once here; nobody opens it again)

`C:/Users/Traff/.claude/projects/C--Users-Traff-Documents-van-gunner/refs/van-salvage-piece-1-ref.webp`:
the player stands in the back room near the bulkhead, looking at the rear doors (the
rust-red stock leaf left of centre, the yellow donor leaf on the right, the pressed
pillars and header of the rear arch between and around them, the hanging RearDoorLamp
can in the ceiling centre). On the player's left (+x, the code's "Left") is the left
wall with the LeftRear side window (wide rounded rectangle, bars, z 3.12..5.56). The red
outline encloses, as one region: **(1) the rear strip of the left wall** from the floor to
the ceiling, from the rear corner (where the wall meets the arch's pillar and ledge)
forward to a line that crosses the side window about a third of the way in from the
window's rear edge (z about 4.9 on the wall; the window's rear third is inside the
outline); **(2) the ceiling's rear corner above it**: from the left wall's top, forward
along a diagonal that goes toward the van's centre and forward (deepest at the wall,
about z 4.2), then across the ceiling just behind the RearDoorLamp (z 4.7; the line dips
round the lamp so the lamp hangs outside the region), ending about above the stock
leaf's centre (x about +0.5 to 0, roughly the van's centreline), at the rear header.
The rear door arch itself, both leaves, the floor, the right wall, the lamp and the
window's sash are outside the outline. The bright wall lamp near the window's top-left
corner (CabEndLamp side, far forward) is outside too.

## What the rear arch is today (the thing to continue)

`rear_door_portal.gd` builds `RearWall/Portal` from `van_rust_steel_material.tres`:
pillars and a header filling the rear wall around the opening (x ±2.7, y 0.02..3.6),
a deep pressed ring (`rear_door_surround.gd` DEPTH 0.3 into the cabin, RING_W 0.16),
a ledge (LEDGE_DEPTH 0.2) stepping out to the side walls and roof, a collar, stamped
pillar pockets (y 1.0..1.6, 0.12 deep, blind holes), a bevelled ramp
(`rear_door_ramp.gd`, BEVEL 0.03) and corner plates; the opening's top corners are
round (`rear_door_flange.gd` RADIUS_TOP 0.375). Portal cabin face z0 = 6.44, deep ring
face 6.14, ledge face 6.24 (LeftHinge z 6.59, leaf depth 0.16 + 0.04 pad). The ledge's
side ends stop at `inner_x_at(0.72) - 0.06`; the cargo (y 0.72) and belt (y 1.52) rails
end at z 6.48 sharing that face; `CoveL` ends at hinge z - 0.163 = 6.427.

## Real vans: what continues from a rear door frame (own words)

- A panel van's rear door frame is one pressed ring; behind it the **rear corner post
  (D-pillar)** is a deep closed box section that runs floor to roof and turns the corner
  into the **cant rail** (the roof-to-wall rail) and the **rear roof bow/header**.
- **Roof bows** are transverse pressed hat sections every 0.6-1.2 m, spot-welded to the
  roof skin; the rearmost is the deepest. Between bows the skin is thin and shows its
  dents from inside. Forum threads on stripped vans (club8090, fordtransit.org) show
  bare inner arches, pillar bottoms and roof bows as the structure you see once the ply
  lining is off.
- The **side wall inner skin** has horizontal swage beads/crash rails at belt height
  and a lower "kick" band; the inner **wheel-arch tub** bulges in low on the wall.
- A donor pillar never matches the host's wall lean: real salvage joins show shim plates,
  stitch welds and raw flame-cut edges, which is what the donor leaf already does
  (`rear_door_donor_*.gd`: shim plates, box-section arms, angle-iron edge welds, uneven
  beads).

## Games (precedents, own words)

- Mad Max (2015) rigs and Rust's armoured vehicles: bolt-on plate volumes that stand
  proud of the body, every join a bead or a bolt row, no feathering between parts.
- Metro Exodus (the Aurora's interior): bare pressed steel, ribs and bows read before
  paint; variety comes from shape and depth, not texture (matches the memory
  "van variety = shape, not skin").

Searches run: "panel van interior bare metal rear corner pillar roof bow wheel arch
inner skin photo" (club8090 / fordtransit threads on inner arches, pillar bottoms, GM
roof-bow bulletins); "kitbashed vehicle interior salvaged panels ... Mad Max Metro
Exodus Rust" (nothing specific; marketplace wreck packs only).

## Lessons from earlier plans

- van-interior-salvage (archived at `archive/van-salvage-kit`): paint caps from the
  art rules kept every donor the same dark wall; flat 2-4 cm patch plates read as
  nothing. This Brief asks for shape only, so the art caps do not narrow it; the
  shape test (same material, still different) is the gate.
- vangapfix: every new face stays 1 cm off a parallel face (FLICKER), a seal overlaps
  5 cm; running phases fix their own audit rows (self-fix ladder, D75).
- No `missed:` line of an earlier plan bears on this Brief (vanfix/vangapfix rows are
  audit rules already in `van-geometry.md`; van-floor's are floor material rows).
