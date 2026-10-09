# van-floor · intake research (2026-10-09)

## The owner's two reference photos (described once; do not reopen)

- **1.png (new cargo van, bare interior, looking at a side wall):** a light-grey pressed-steel floor with longitudinal ribs about 10 cm apart, each rib a shallow rounded ridge with flat valleys; rows of small dimples along the panel joins. Where the floor meets the wall there is a row of scalloped, bowl-shaped reliefs (one every ~25 cm) pressed into a raised edge channel, like a run of half-cups along the sill. A rounded wheel-arch hump rises from the floor at the left, smooth and seamless. The wall is a grid of vertical pillars and horizontal rails with slotted holes, plain panels between.
- **2.png (old van, looking out through the open rear doors):** a pale ribbed floor, ribs running front to back, with heavy red-brown rust stains spreading from the right side and pooling in the rib valleys; a raised lipped sill plate across the rear door line; a box-shaped wheel arch on each side with flat tops, stained and chipped; the walls are bare, grey, with pillar grid and small panel dents. The floor reads as one pressed sheet gone rotten in patches, not as separate plates.

## Real cargo van floors (what shapes our geometry)

- Floors are one pressed steel sheet with longitudinal ribs (ridges up, flat valleys) so loads slide; tie-down anchors sit flush in recesses, 3+ inch holes bolted through, some protrude ~1 cm (patents US9308854, US10053024). Take: ribs as low ridges, a few flush recessed rings with bolt heads.
- The side sliding door has a step well: the floor stops short at the door and drops to a sunken sill, with an added trim step reaching ~20 cm into the well (AVC Transit step trim, National Fleet van step). Take: a raised floor that stops before the side door and leaves a well at the old sill level, lipped.
- Sill plates at the rear and side door lines are separate lipped strips bolted over the floor edge (Legend sill sets). Take: lipped sill plates at the rear door, the step well and the riser edge.
- Wheel wells dent first and get boxed in (Legend brochure). Out of this plan (D1).

## Rusted, patched steel floors (how repairs look)

- Real bed-floor repairs are either matching corrugated patch panels welded in (Dorman 999-999) or flat plates "crudely welded over the rusted areas", with the sheet warped by weld heat near the patch and lumpy beads (Pinzgauer forum). Take: patches are flat plates of other floors (their own rib direction and pitch) lying 2-4 cm proud with a lumpy bead around, some cut from ribbed sheet so the ribs of the patch run across the host's; holes under a plate show as dark cavities at the plate's edge.
- Game trim-sheet practice: repeating surface in the material, patches and beads as separate geometry or decals, vertex colour to vary rust per plate (80.lv abandoned bar, polycount). Take: beads and patches are geometry; variation per piece rides in vertex colour.

## One shader, many pieces (Godot)

- MultiMesh gives per-instance colour and `INSTANCE_CUSTOM`, but only for identical meshes; our pieces are all different. Take instead the rear door's own precedent: vertex `COLOR.r` carries a face tag (`rear_door_skin.gd` tag(), crest/valley/edge/cavity), and we add `COLOR.g` as a per-piece seed (0..1) that offsets the noise and shifts the rust/paint mix, so one `ShaderMaterial` covers every floor piece. Triplanar model-space patterns (`van_rust_steel.gdshader`) need no UVs.

Sources: patents.google.com US9308854 and US10053024; campervan-hq.com transit-floor-step-and-trim; newequipment.com van step 55095190; elitetruck.com Legend sill set; faroutride.com floor-removal-ford-transit; lordco/summitracing Dorman 999-999; real4x4forums.com Pinzgauer body tub thread; 80.lv abandoned bar workflow; docs.godotengine.org MultiMesh.
