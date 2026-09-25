---
paths:
  - "scripts/core/save_manager.gd"
  - "scripts/core/save_sandbox.gd"
  - "scripts/core/session_save.gd"
  - "scripts/core/meta_progression.gd"
  - "scripts/core/skill_tree_registry.gd"
  - "scripts/meta/**"
  - "scripts/ui/main_menu.gd"
  - "scripts/ui/skill_tree_*.gd"
  - "resources/meta/**"
  - "tools/smoke/**"
---

# Saves, meta progression and the schematic

## Files

Run saves are JSON at `user://save_slot_N.json` (slots are 1-based: `SaveManager._valid_slot` accepts 1..`SLOT_COUNT`). Meta progression (Rare Parts, schematic, volumes, equipped class) is `user://meta_progression.json`.

## Invariants

- **Run save version lives only on `SaveManager.SAVE_VERSION`.** `GameSession.to_save_data()` (body in `session_save.gd`) must read that constant. Mismatched slot files are rejected with a warning that names both versions; never fail silently. The main menu must not treat a rejected file as a new run (NEW overwrites).
- **Gold buys at shops and the mechanic. Rare Parts (`MetaProgression.rare_parts`) are a second wallet for the van schematic only:** boss drops, 3 per run max. Never spend gold on schematic nodes.

## Rejected saves used to look like NEW RUN

`load_slot_data()` returns `{}` for version mismatches and corrupt JSON, which made `get_slot_summary()` report `exists: false`; clicking the slot then called `start_new`. Incompatible files now show CAN'T CONTINUE and CONTINUE doesn't overwrite them.

## SaveSandbox

`SaveSandbox.enabled` (a static var read from the `--smoke-sandbox` user arg, because autoload `_ready` runs before any main scene) makes `SaveManager.save_active_session` and `MetaProgression.save_profile` no-ops and makes `load_profile` start from defaults, so the smoke test never touches the player's files or reads their schematic into the fingerprint. It is the only test hook in game code; keep it that way.

## Schematic

`SkillTreeRegistry` scans `res://resources/meta/tree/` with `DirAccess`. Callers preload the script (it's not an autoload and has no `class_name`). `skill_tree_hud.gd` is the UI; node buttons, styles and tooltips are built by `skill_tree_nodes.gd`.

## Smoke test

`py -3 tools/smoke.py` runs `tools/smoke/smoke_test.tscn` headless with the sandbox on. The driver (`smoke_driver.gd`) plays a run, `smoke_route.gd` drives the forks, `smoke_fingerprint.gd` writes the fingerprint, and a save round-trip checks `to_save_data` → `load_from_data` → `to_save_data` reproduces the same dictionary. `--bless` rewrites `fingerprint.baseline.txt`; only bless when a change is meant to alter the fingerprint. `fingerprint_waves` pins `segment_wave_min` and `segment_wave_max` (`WAVE_MIN_PIN` / `WAVE_MAX_PIN`) before planning and restores them after, so the owner's uncommitted balance edit doesn't move the fingerprint and a clean clone (cloud session) reproduces the baseline.
