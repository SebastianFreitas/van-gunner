# Van Gunner: what the reviewer checks besides the spec

van-gunner is a Godot 4.7 game in GDScript. Besides the shared checks:

1. Scene and resource text: no existing `id=`, `unique_id=` or `uid://`
   changed; new ids don't collide; a removed node took its children, its
   `[connection]` lines and unreferenced `ext_resource`s with it; a moved
   or deleted `.gd` moved or deleted its `.gd.uid`.
2. A deleted or renamed method has no callers left: grep
   `has_method(&"x")`, `call("x")`, `call_deferred(&"x")`, `method="x"`
   in `.tscn`, direct calls, and subclasses.
3. GDScript: typed declarations, `->` on functions, `class_name` never on
   an autoload, helpers (`RefCounted` beside a core) have no `class_name`
   and no `await`, scripts under 400 lines.
4. Project invariants: one damage number (`BASE_DAMAGE_PER_SHOT *
   damage_mult`, scaled once by `gun_damage_per_shot`); shotgun pellets
   split damage; Explosive, Poison and Cold Rounds are bullet boons, not
   damage types; one projectile gun per class; gold buys at shops and the
   mechanic, Rare Parts buy schematic nodes only; van speed changes only
   through schematic nodes; the run save version lives only on
   `SaveManager.SAVE_VERSION`; `is_elite` is explicit; player HP and van
   hull are both fail conditions; `SaveSandbox` is the only test hook in
   game code (`tools/` is not game code); facade placements pass
   `FacadeKeepOut.allows`.

Never open `*.png`, `*.wav`, `*.ogg`, `*.import` or `.godot/`.
