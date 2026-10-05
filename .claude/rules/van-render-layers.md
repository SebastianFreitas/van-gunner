---
paths:
  - "scripts/van/**"
  - "scenes/van/**"
  - "scripts/player/fps_player.gd"
---

# Van render layers and light pairing

Van interior and player meshes sit on render layer 2 (`VanLighting.LAYER_VAN_INTERIOR`) so the door-spill lights (cull mask 1) light the corridor through openings without washing the cabin. Set `layers` before `add_child`, as the shell builders do. To change it on a mesh already in the tree, go through `VanLighting.retarget_layers`, which hides the render instance first. Godot 4.7's Forward+ renderer keeps a light↔mesh pairing across a `layers` or `light_cull_mask` change, then skips the unpair once the masks stop overlapping, so when either side is freed (a street lamp culled behind the van) the game crashes right after `BUG, indexing did not unpair geometries from light`. Hiding only the van's own lights is not enough: any world light near the van pairs too.
