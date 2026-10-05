# Van Gunner: what every implementer needs

- van-gunner is a Godot 4.7 game written in GDScript.
- Never start the Godot editor or the game with a window (the only
  exception is `tools/smoke.py --shots`, which runs off-screen and quits
  itself), and never run anything that waits for input. Never pass
  `--bless` unless the spec says so.
- `docs/PROJECT_MAP.md` is this project's map (generated). In
  `implementer-wt`, never run `tools/gen_context.py`: the caller
  regenerates the map after merging. The first tool run in a worktree
  copies the main checkout's `.godot/` into it, so it's quick.
- The file guard also refuses edits of existing `id=`, `unique_id=`,
  `uid://` values, and of generated files (it names the generator to run
  instead). After every Write or Edit of a `.gd`, `.tscn` or `.tres`, a
  lint hook (`gd-lint.py`) reports mistakes in the lines you just wrote
  (spaces for indents, untyped `var`s and parameters, missing `->`,
  Godot 3 or Python syntax, a missing `##` summary, duplicate or dangling
  resource ids, unused `ext_resource`s).
- `scenes/van/van_shell.tscn` is 46 KB: grep node names and read about
  40 lines around the hit.
- Never open `*.png`, `*.wav`, `*.ogg`, `*.import`, `.godot/` or
  `__pycache__/`.

## GDScript

- Typed everything: `var x := 0.0`, `func f(a: int) -> void:`.
- Tabs, LF line endings, about 100 columns, two blank lines between
  top-level functions.
- `&"..."` StringName literals for ids, groups, signals and action names.
- `##` doc comments on classes and on non-obvious fields. Comments
  explain why, not what.
- `class_name` on reusable scripts, never on autoloads: an autoload with
  a `class_name` creates a parse cycle.
- Cross-system lookups go through `get_tree().get_first_node_in_group(&"...")`
  and `has_method`, the way the surrounding code does.
- Every script starts with a one-line `##` class summary right after
  `extends` (after `class_name` if that follows); `tools/gen_context.py`
  reads it. Give new scripts one.
- Scripts: under 300 lines is the target, 400 the hard cap. Large node
  scripts are split into a core plus `RefCounted` helpers beside it (e.g.
  `van.gd` + `van_hud.gd`, `travel_controller.gd` + `travel_routes.gd`).
  Helpers take the owner in `_init`, have no `class_name` and no `await`,
  and pass the owner node, never themselves, to other systems. When a
  helper reads its owner through an untyped variable, `:=` can't infer
  the type: give those locals explicit types.
- A Callable does not keep a `RefCounted` alive: `Helper.new(x).build.bind(...)`
  stored for later fails with "call function 'null::build (Callable)' on
  a null instance", because the temporary helper is freed first. Store a
  lambda that creates the helper when it runs, or keep the helper in a
  field.

## Layout

`scripts/acts/` street cards, act deck, REST boon · `scripts/enemies/`
raiders, boss, cabin nav, breach points, encounters · `scripts/travel/`
road, turns, parking, elevator, facades · `scripts/stops/` side-stop
interiors · `scripts/van/` van shell, doors, windows, vitals, van root ·
`scripts/core/` autoload state, saves, balance · `scripts/combat/`,
`scripts/player/`, `scripts/items/`, `scripts/classes/`, `scripts/ui/`,
`scripts/debug/`, `scripts/audio/` · `tools/smoke/` headless smoke test.

## Scenes and resources edited as text

- Never change or renumber existing `id=`, `unique_id=` or `uid://`
  values. New ids must not collide with any id already in the file.
- Removing a node also removes its child nodes, every `[connection]` line
  that names it, and any `ext_resource` nothing else references.
- Moving or deleting a `.gd` moves or deletes its `.gd.uid` too (plain
  `mv` or `rm` both; the caller stages the move). A new script gets its
  `.gd.uid` from the next headless check. Assets move or go together with
  their `.import` files.
- Before deleting a method, grep for its name as `has_method(&"x")`,
  `call("x")`, `call_deferred(&"x")` and `method="x"` as well as direct
  calls and subclasses (`extends <Class>`).

## Verification

The usual commands are the headless check (`py -3 tools/check.py`: import
scan, load of every script and resource, and a debugger pass that fails on
any GDScript warning), the smoke test (`py -3 tools/smoke.py`) and, for
van scene edits, the scene dump (`py -3 tools/scene_dump.py`). The tools
find Godot themselves and wait for each other, so two of them never run
Godot on one folder at once. Report every output line containing
`SCRIPT ERROR`, `Parse Error`, `ERROR:` or a GDScript warning. Say
"clean" only when there are none; the exit code alone is not reliable. In
a cloud session (a Linux container) `py -3` doesn't exist: run the same
commands with `python3`. If a tool reports "No Godot found" there, say so
and stop; don't install anything.
