# vanfix · intake research (2026-09-28)

The brief is two geometry faults, not a look: pieces that do not meet (you
see inside from outside) and pieces that overlap (flicker, clipping). What
the reading says, in our words:

## Z-fighting (flicker between two surfaces)

- Two faces in the same plane with the same depth flicker as the camera
  moves; the depth buffer cannot order them. Godot applies no polygon
  offset by default. Fixes, best first: don't build the second face (one
  owner per plane); move one face off the plane by a real gap (millimetres
  near the camera, more far away, since depth precision falls off with
  distance); for decals that must overlap, push vertices along the normal
  in the shader or order them with `render_priority` on transparent
  materials only. Sources: Godot forum "How to prevent z-fighting when
  plane meshes overlap?" (forum.godotengine.org/t/99474); "Understanding
  render_priority, sorting_offset" (forum.godotengine.org/t/46902);
  bugnet.io "Godot MultiMesh z-fighting between instances".
- Duplicates from a procedural builder (same transform twice, or two
  builders emitting the same panel) are the classic source; the fix is at
  the builder, not in the renderer.

## Holes (seeing inside from outside)

- A closed shell reads as solid only when every edge is shared by two
  faces (watertight/manifold). Single-sided faces vanish from behind with
  back-face culling, so an interior liner seen from outside through a gap
  shows as a hole even when a face "exists". Fixes: make the outer skin
  closed on its own (caps at every opening's reveal, corners, roof edge,
  skirts), or render the specific liner double-sided where the gap is
  structural. Sources: GameDev.net "Backface culling of procedural
  generated terrain"; Unity forum "Procedural meshes and culling issue";
  itch.io devlog "Procedural mesh (or procedural mess?)".

## Clipping of moving parts (window opened, doors)

- A moving part must have its swept volume inside a clear envelope: a
  shutter that slides or hinges needs a pocket or reveal deeper than its
  own thickness, and frames at the corners must be cut to the opening, not
  laid over it. Film/game precedent: hinged car doors in racing games carry
  a door-jamb reveal so the leaf never passes through the body skin.

## What we take

- An audit tool first: a reproducible list of every overlapping pair and
  every open edge, measured, not guessed from screenshots.
- One owner per plane; every other surface on that plane moves off it by
  a set gap or is removed.
- A closed outer skin that owns the silhouette; the liner only faces in.
- Swept volumes checked for doors, windows and shutters in every state.
