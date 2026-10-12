# railgun-redesign · intake research (2026-10-12)

## The reference picture, in words (read once; nobody needs to open it again)

`refs/railgun-ref.webp` is the Halo 4 UNSC ARC-920 railgun, seen from its right side, muzzle to
the right, on a white background. Piece by piece:

- **Rails.** Two long parallel rails run from the receiver's front to the muzzle, both ending
  flush at the same tip, about 55 % of the gun's length. They are not equal: the **upper rail**
  is a tall, deep slab (roughly twice the lower one's height), flat-topped, with one long
  shallow recessed groove along its side and a stepped chamfer at the rear; the **lower rail**
  is thinner, with a toothed accessory rail (picatinny teeth) along its top edge, a chamfered
  underside and a small square shoe at its front. The gap between the rails is open along the
  full rail length; the receiver's front face is the only bridge. The tips are cut square with
  a 45 degree chamfer on the outer corners, no muzzle brake, no bore ring.
- **Receiver.** A boxy slab, flat top, about as tall as both rails and the gap together. Its
  side is panelled: rectangular recessed plates with 45 degree corner cuts, a thin raised
  rail across the middle, a few small slots and a short dark window near the front. A raised
  block on top near the rear (where a carry handle would be) has three triangular cut-outs in
  a row; that block and the front of the top step down toward the muzzle in two chamfers.
- **Top.** Flat, the raised triangle block the only bump; a small grey insignia on the flank.
- **Muzzle end.** The two rail tips, square, with a dark bore line between them; nothing else.
- **Stock end.** A short, blocky stock: a dark angled block behind the receiver with a black
  rubber butt pad, lower than the receiver's top, about one grip-length long. The black
  polymer pistol grip has a closed trigger guard and a flat trigger, and its rear merges into
  the stock's lower edge (one dark piece).
- **Panel language.** Everything is a box with 45 degree corner chamfers and stepped
  offsets; recesses are shallow (a few mm) and long; seams are straight; no cylinders anywhere
  except the trigger pin. Details repeat: long groove, stepped chamfer, rectangular slot.
- **Colour and wear.** Desaturated gunmetal grey-silver with lighter worn edges and darker
  steel in the recesses; grip, stock pad and the inner lower rail are black; one small
  orange accent (a latch) ahead of the trigger guard. Clean factory wear, no rust.

What we take: the silhouette (two flush rails over an open gap, slab receiver, flat top,
stubby stock), the chamfer-and-step panel language, and the unequal rail sections. What we do
not take: the colour (ours stays rust and scavenged, D4) and the insignia.

## Precedents (own words)

- **Halo ARC-920** (above): two parallel conducting rails, a power cell, a charge-up before
  the shot; glowing rings form around the rails while charging. Source:
  https://www.halopedia.org/ARC-920_railgun. Lesson: the "charge" is the gun's one animated
  moment; our `RailGlow` flare on `shot` already plays that beat.
- **Quake / Doom railguns**: a long thin barrel with a spinning or sliding rear section and
  a visible glowing core; the moving part is at the rear where the player sees it.
- **Mass Effect / District 9 scavenged weapons**: panels that do not match, bolted plates,
  wires over the body, a few parts clearly from another gun. Ours already has this layer
  (`RailgunJunk`, `RailgunWear`: tape, welds, bolt pits, loose bolt, hang plate, cable sag).
  Lesson from our own rounds (art-arms.md): junk flush on flat faces reads; upright add-ons
  and words do not.

## Animating a code-built viewmodel in Godot 4 (own words)

- A Node3D rotates and moves about its own origin, so a moving part is an empty `Node3D`
  pivot placed at the hinge or slide line with the part's meshes as children, offset from it.
  Static parts stay direct children of `Body` as today.
- `AnimationPlayer` as a child of `Body` with `root_node` `..` (the Body): tracks address
  parts by relative path (`Breech:position`, `VentL:rotation`). Animations can be built in
  code (`Animation.new()`, `add_track`, `track_insert_key`) and added with
  `add_animation_library`, so a procedural gun keeps its seeded build and still animates.
- Pivots cost nothing when idle, so rigging now and animating later is cheap; renaming or
  re-parenting later costs a re-fit of every system that looks parts up by name (`RailGlow`
  binds `GapGlow` and `Lamp%d` by direct child name, `rail_glow.gd:81,86`; `GunSockets.all`
  and the `gun report` walk direct children, `gun_sockets.gd:118`,
  `debug_gun_commands.gd:118`; `GunSockets.mesh_boxes` recurses, `gun_sockets.gd:82`).
- The gun's existing motion (shot kick, reload slaps, inspect turn about the grip,
  `arm_inspect.gd:4`) moves the whole `Gun` root; a part animation sits under `Body` and
  stacks on top without touching the arm keys.
- Godot docs on pivot-and-AnimationPlayer structure:
  https://docs.godotengine.org/en/4.3/getting_started/first_3d_game/09.adding_animations.html
