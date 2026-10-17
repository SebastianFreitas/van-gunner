# arms-blender-source: Blender glTF round trip (intake, 2026-10-17)

Tested with Blender 5.2.2 LTS headless (`-b --factory-startup --python`), importing
`assets/models/arms/arms.glb` and exporting to the scratchpad with: GLB, export_materials NONE,
no animations, export_def_bones, Y up, normals, UVs, skins, no morph, no extras.

- Import: `ArmL` / `ArmR` (369 verts, 520 polys, 48 vertex groups, `UVMap`, a `custom_normal`
  attribute, an Armature modifier each) under armature `rig` (48 bones). The importer also makes
  an `Icosphere` mesh (bone display shape); it is not exported.
- Export: 62,256 B (original 62,776). Same counts: 51 nodes, 2 meshes, 1 skin, 48 joints,
  13 accessors, 0 materials, 0 animations, no extras or extensions.
- Data: positions and UVs match within 1.2e-6, normals within 3e-4, weights exactly,
  bind matrices within 1.75e-5 (by joint name), node TRS within 7e-6.
- Order changes: vertex order, skin joint order and node order all differ from the original.
  The game looks meshes and bones up by name, but any code that relies on vertex index order
  would see a different mesh; hence the plan's identity-export check (D5) and its fallback of
  patching the original buffers in place.
- `.blend` size for this file: 744 KB uncompressed, 144 KB with `compress=True`.
- Generator string changes from "Khronos glTF Blender I/O v4.2.70" to "v5.2.40".

Scripts used (scratchpad, not the repo): `C:/Users/Traff/AppData/Local/Temp/vg-arms-blender/scripts/`
(`roundtrip.py`, `gltf_dump.py`, `gltf_cmp.py`).
