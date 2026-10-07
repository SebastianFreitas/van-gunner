# Van interior: art brief for the kit (replaces the Design and Kit sections)

## The one-sentence idea
This van was built by survivors out of 2–4 wrecked vans plus whatever scrap they had. They cut out the parts that still worked, welded and bolted them into one functional vehicle, and patched the holes with non-van junk. Every interior surface should make it obvious that the van was assembled from pieces with different origins, by people who needed it to work, not to look nice.

**This matters more than anything else in the plan: it has to look natural and cool.** A technically correct kit that looks like tidy slots filled with random modules is a failure.

## Scope: interior only
This brief covers **only the inside of the van**: floor, inner walls, ceiling, and the inner side of the windows. The exterior is out of scope, will be its own project later, and uses different assets. Don't change any exterior mesh, material or silhouette.

Two things must stay ready for the exterior project:
- **Donor data** (colour, wall style, era) lives in its own seeded data, separate from the interior builder, so the exterior can read the same donors later and match.
- **Windows:** build only the inner side and frame for now, and keep the existing exterior side of each window as it is. Keep the window's generated parameters (source, glazing, cover) in data the exterior can read later.

## Real-world references (look at these, don't invent from nothing)
- **Philippine jeepneys.** Built from surplus army jeeps with locally made bodywork. Mixed sources, one vehicle.
- **Junkyard repairs on work vans.** A white Transit with one red door and a blue rear panel, because the parts came from donor vans of different colours. This is the main look.
- **Improvised armoured trucks** ("technicals") from Syria, Iraq and Ukraine. Steel plates welded on over the original body, slits cut for vision, mesh over windows, plates at different angles and thicknesses.
- **Mad Max: Fury Road vehicles.** Real cars built from several donor cars. Look at how parts from different vehicles are joined.
- **Rat rods and rust-belt repairs.** Patch panels welded over rust holes, visible weld beads, mismatched primer.
- **Inside a bare cargo van** (Sprinter, Transit, Ducato): steel ribs at a regular pitch, top-hat sections, factory holes, a wheel arch box over each axle.

## Core concept: donor vans
Each seed rolls **2–4 donor vans**. A donor has:
- a paint colour (faded, with primer showing through at edges)
- a wall style: smooth with ribs (Sprinter), corrugated (old Citroën H van), ribbed panel (old Transit), or plain flat sheet
- a rib profile and pitch
- an era of fasteners (spot welds and factory rivets vs. crude hand welds)

The van is split into **a few large donor regions** (usually 2–3 along the length, sometimes split left and right as well). Inside a region, everything looks like it came from the same van: same paint, same rib style. **That consistency inside a region is what makes it read as natural.** Change happens mostly at the splice seams between regions.

**Splice seams** are where two donors were cut and joined. There are only 1–3 per van and they are big and crude:
- a thick, irregular weld bead
- an overlap where one skin sits over the other
- a reinforcing strap or channel iron welded across
- the cut doesn't have to be a straight vertical line: it can step or angle

## Layers (build in this order; each layer sits on top of the previous one and overlaps it)
1. **Structure.** Ribs and pillars at the donor's regular pitch. Straight and solid: this is the part that holds the van up.
2. **Donor skin.** The wall, floor and ceiling panels of each donor region, in that donor's colour and style.
   - Floor, left wall, right wall and ceiling are rolled **independently**, with **staggered seams**. If the left wall has a seam at z = 0.4, the right wall's seam is somewhere else. Never ring the room with a seam.
   - The floor is mostly continuous: one or two long runs of plywood, tread plate or the donor floor, or 2–3 big overlapping steel plates.
   - Gaps are allowed. Bare, grimy base metal (the backstop) can show for 10–40 cm where a panel was stripped. Not every square metre needs a piece.
3. **Splice seams.** Between donor regions (see above).
4. **Salvage patches.** Non-van material covering holes and damage: road signs, shipping-container corrugated sheet, a fridge door, a car door panel, chequer plate from a truck bed, chain-link fence, oil drum halves, sheet steel. Placed where damage would be (low on the walls, around wheel arches, near doors), and allowed to cross ribs and seams.
5. **Reinforcement.** Angle iron, scaffold pipe and rebar braces, added where something was cut or where armour is needed. Bolted or welded to the structure.
6. **Long runs and attachments.**
   - Long runs: conduit, cable trays, cargo rails and ceiling light strips run most of the length (for example z -4.0 to 4.0), crossing every seam. They tie the room together lengthwise.
   - Attachments: lockers, drums, hatches, vents and wheel arch boxes (always over the axle) are placed onto the surfaces, bolted on or recessed. They have their own size, span several rib bays, and don't have to tile against anything.
7. **Fasteners and wear.** Weld beads along patch edges, bolt rows on flanges, rivets in lines. Rust at low edges and around welds, grime on the floor, scuffs at hand height, chipped paint on edges.

## The rule every piece must pass
For every piece the generator places, you must be able to answer: **where did it come from, and why is it here?**
- "Blue donor's wall panel, part of the front region": good.
- "Road sign welded over a rust hole above the wheel arch": good.
- "A ribbed box, because the slot was 1.2 m long": bad.

## Matching rules (what makes it look natural)
- **Big, then medium, then small.** A few large shapes define the space, medium pieces sit on them, small details (bolts, welds) go last. Large pieces cross seams and ribs.
- **Neighbours mostly match.** Within a region, keep material and colour consistent. A change of material needs a visible reason: a seam, a patch, a repair.
- **Overlap, never butt.** Pieces lap over each other and over edges. Nothing sits perfectly flush with its neighbour.
- **Slightly off.** Patches and add-ons get small rotations (1–3°), offsets and uneven gaps. Structure (ribs, pillars) stays straight, which makes the hand-made parts read against it.
- **Varied depth.** Mix thin skins (1–3 cm), medium patches and plates (3–8 cm), and big shapes (up to 25 cm). Not everything at the same depth.
- **Fasteners where a person would put them.** Welds along patch edges, bolts on flanges and brackets, wire lacing on mesh.
- **Wear follows physics.** Rust runs down from welds and collects at the bottom edges. Grime is heaviest on the floor and lower walls.

## What to avoid
- Cutting the van into slices and filling each slice with one module.
- Floor, both walls and ceiling all changing at the same z. A seam that wraps the whole room reads as a modular game asset, however well it's covered.
- Coupling unrelated surfaces: a floor hatch must not decide what the ceiling above it is.
- Long elements (pipes, cables, rails) that stop at a seam.
- The same piece repeating at a regular interval (except ribs).
- Every seam getting the same join treatment.
- Clean, new-looking parts. Nothing in this van is new.

## Windows: generated, not built around
The gameplay contract of each window stays fixed: its mouth position and size, breach points, raider behaviour and keep-out. What you see is generated per seed from salvage, and the window is a piece of the van like any other, not a hole the kit works around.

A window is built from these parts, each rolled per seed:
- **Source:** a donor-van window still in its rubber gasket, with a chunk of the donor's panel (and paint) around it; a bus window with a sliding pane; a car door welded in whole, window and all; a porthole (ship or washing-machine door); a slit cut into armour plate; a plain hole cut with a torch.
- **Glazing:** glass, cracked glass, scratched plexiglass bolted on with big washers, or none.
- **Cover:** steel bars, welded rebar grid, chain-link or expanded mesh, a hinged steel shutter, half boarded up with planks, or nothing.
- **Attachment:** gasket, weld bead around the frame, bolted flange, or a collar plate welded around a bad cut.

Rules:
- The visible opening must stay inside the gameplay mouth, and the frame must cover the edges of the mouth so the street never shows through a gap.
- The window's surround belongs to a donor region or is a patch: it must pass the "where did it come from" test.
- Aim for many combinations. Two windows in the same van can come from different sources.

## Keep from the current plan
Fixed footprint, seeded rng (`rng_for`), determinism across kit additions (`order`, `since_gen`, golden file), the dark backstop behind everything, keep-out (`VanKitKeepOut`) and the 25 cm intrusion limit, the shared grime shader with per-piece `instance uniform` variation, colliders, and the phases and verification steps.

## How a shot is judged
Show the cabin from the rear doors and from the cab. A reviewer who hasn't seen the code should be able to say:
- "the front half came from a different van than the back"
- "that's a road sign, that's a car door, that's a fridge door"
- "someone welded this together to survive"

If the honest reaction is "it's a van with lots of panels", the look isn't done.
