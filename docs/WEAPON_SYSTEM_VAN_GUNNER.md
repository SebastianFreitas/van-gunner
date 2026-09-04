# Van-Gunner Weapon Loot System — Implementation Spec

**Status:** Design / handoff only. **Do not invent alternate architectures** that ignore existing van-gunner systems.  
**Audience:** Implementation LLM / engineer.  
**Scope:** Full weapon generation, 2-slot inventory, world grab, bench crafting page, combat integration.  
**Out of scope for this doc:** Writing production code in this chat; changing boon combat specials into gun mods.

---

## 0. One-paragraph product intent

Players find or craft **generated guns** that change *how* the gun shoots (family feel, mag/reload, fire rate, pellets, element tag, utility mods). **Damage numbers do not explode from gun flats.** Baseline damage stays on `GameBalance`; meaningful DPS growth comes from **boons** (and limited `% increased` gun mods). Player holds **exactly 2 weapons**, swaps with **mouse wheel or Q**, grabs weapons from the world like loot, and crafts on a **second bench page** paid in **gold** at **mega-expensive** rates.

---

## 1. Hard design constraints (non-negotiable)

| # | Constraint | Why |
|---|------------|-----|
| C1 | **No flat damage on weapons or weapon mods** | Early-game power spikes; flats stack too hard with boons |
| C2 | **Max 6 mods per gun** | Simpler HUD / tooltips / crafting |
| C3 | **Interior + exterior pools only** | Specials stay as boons (already true in van-gunner) |
| C4 | **Exterior includes Reload Speed + Mag Size** | Mag/reload already exist in combat |
| C5 | **2 weapons max** | Inventory pressure; fits van FPS |
| C6 | **Switch: mouse scroll OR Q** | Q action `use_usable` exists but is unused on player today |
| C7 | **Craft currency = gold (`GameSession.coins`)** | No new `gunParts` currency for v1 |
| C8 | **Craft costs are mega-expensive** | Guns are rare power; bench is a sink, not a farm |
| C9 | **Reuse existing combat stack** | `GunStats`, `GunStatsController`, `GunController`, projectiles, mag/reload, boon hooks |
| C10 | **Do not port HellScape raw damage tables (50–300)** | Van-gunner baseline is ~1.5 dmg @ 1.75 RPS |

### Explicit non-goals

- Do **not** add reserve ammo / ammo pickups.
- Do **not** put Explosion Area / Ignite / Freeze Chance / Poison Rate / Double Damage Chance / etc. on guns — those remain boons.
- Do **not** keep a 4-gun + layout-slot inventory from the source handout; van-gunner is **2 equipped only**.
- Do **not** invent a second damage formula that bypasses `DamageInfo` / `BoonCombat` / `DamageResolver`.
- Do **not** use hitscan for the new system (`HitscanWeapon` is legacy).

---

## 2. What already exists (must reuse)

### 2.1 Combat

| Piece | Path | Notes |
|-------|------|-------|
| `GunStats` | `res://scripts/combat/gun_stats.gd` | fire_rate, damage_per_shot, bullet_speed/weight/size, **reload_speed**, **mag_size**, aim_range, damage_type, bounces |
| `GunStatsController` | `res://scripts/combat/gun_stats_controller.gd` | Rebuilds effective stats from base + `BoonTraits` + temp `StatModifier`s. **Overwrites fire_rate & damage_per_shot from `GameBalance` every rebuild today** — this must be revised carefully (see §6). |
| `GunController` | `res://scripts/combat/gun_controller.gd` | Mag, reload timer, hold-to-fire projectiles, signals `ammo_changed`, `reloading_changed`, `fired` |
| `Projectile` / pool | `res://scripts/combat/projectile.gd`, `projectile_pool.gd` | Bounce, trail, hit pipeline |
| `DamageInfo` / `DamageType` / `DamageResolver` | `scripts/combat/` | Headshots, status, explosions |
| `BoonCombat` | `res://scripts/player/boon_combat.gd` | Spawn + all combat hooks |
| Default stats | `res://resources/combat/default_gun_stats.tres` | Mag defaults live here; DPS knobs owned by balance |
| Balance | `res://resources/balance/game_balance.tres` | `base_damage_per_shot = 1.5`, `base_fire_rate = 1.75` |

**Reload semantics today:** `GunStats.reload_speed` is **seconds to reload** (duration), applied as timer in `GunController`. Display name in traits says “Reload time”.  
**New exterior mod “Reload Speed” (increased %)** must mean: *faster reloads* → **lower** duration:

```
effective_reload_seconds = base_reload_seconds / (1 + increased_reload_speed_pct / 100)
```

Do **not** add the % onto the seconds field as if longer were better. Document the operator mapping in code comments.

### 2.2 Boons (damage scaling home)

Gun-related trait keys already exist in `BoonTraitKeys`:

- `gun_fire_rate`, `gun_damage_per_shot`, `gun_bullet_speed`, `gun_bullet_weight`, `gun_bullet_size`
- `gun_reload_speed`, `gun_mag_size`, `gun_aim_range`, `gun_explosion_radius`
- `gun_max_bounces`, bounce retention keys

Combat damage scaling boons already exist (`phys_damage_bonus`, fire/cold/poison traits, crit-style headshot behaviors, etc.). **This is intentional:** weapons stay shallow on damage; boons carry the long-term curve.

### 2.3 Economy / bench / loot

| Piece | Path | Role |
|-------|------|------|
| `GameSession` | `scripts/core/game_session.gd` | `coins`, `add_coins` / `spend_coins` |
| `CraftingTable` | `scripts/interactions/crafting_table.gd` | Interact → opens bench; sets loot anchor |
| `BenchScreen` | `scripts/ui/bench_screen.gd` + `scenes/ui/bench_screen.tscn` | Single page today: van stats + gold sink + boon/tool grids |
| `ShopStock` / `ShopOffer` | `scripts/run/shop_*.gd` | Shop sells `ItemDefinition`s for `shop_price` |
| `Pickup` / `LootCollector` | `scripts/items/pickup.gd`, `scripts/core/loot_collector.gd` | Shoot → stash to table → walk collect |
| `FpsPlayer` | `scripts/player/fps_player.gd` | One `weapon: GunController`; Q (`use_usable`) unused |
| Ammo HUD | wired in `scripts/run/van.gd` | `%AmmoLabel`, `%AmmoBar`, `%ReloadLabel` |

### 2.4 Current weapon model

- **One** gun under `Player/Head/Camera3D/Weapon`
- **No** inventory, swap, or generated mods
- Starter feel ≈ balance DPS ~ **2.625** with mag 12 / reload 1.2s

---

## 3. Target player fantasy (acceptance feel)

1. Run starts with **Starter Basic** in slot A; slot B empty (or locked until first pickup — prefer **empty B**).
2. Kill elites / clear rooms → rare **weapon pickup** drops (or shop sells a gun offer).
3. Player **grabs** weapon into empty slot, or is prompted to **replace** if full.
4. Scroll / Q swaps active gun; ammo + reload state **persist per weapon**.
5. Bench → **page 2 Weapons**: inspect mods, pay huge gold to add/remove/reroll carefully.
6. Early game: a shiny A1 shotgun feels different (pellets, mag, slower) but does **not** melt acts because damage is still ~balance + early boons.
7. Late game: stacked **boons** make either gun terrifying; gun mods are spice + identity, not the whole DPS tree.

---

## 4. Data model

### 4.1 New core types (suggested names)

Create resources/scripts under something like:

```
res://scripts/weapons/
  weapon_definition.gd      # family archetype (static catalog entry)
  weapon_instance.gd        # runtime generated gun (type + mods + ammo state)
  weapon_mod.gd             # one rolled mod
  weapon_mod_catalog.gd     # interior/exterior definitions + weights
  weapon_generator.gd       # CreateWeapon(level, ...)
  weapon_inventory.gd       # 2 slots, active index, signals
  weapon_pickup.gd          # world/interact pickup (or extend Pickup)
```

Resources:

```
res://resources/weapons/definitions/   # basic, shotgun, machinegun, sniper + A1 + elemental
res://resources/weapons/mods/          # optional .tres per mod id, or one catalog resource
```

### 4.2 `WeaponDefinition` (static archetype)

Fields (conceptual):

- `id: StringName` — e.g. `basic`, `shotgun_a1`, `machinegun_a1_fd`
- `display_name`, `description`, `icon` / mesh hint
- `family: enum { BASIC, SHOTGUN, MACHINEGUN, SNIPER }`
- `tier: enum { BASE, A1 }`
- `element: enum { NONE, FIRE, COLD, POISON }` → maps to `DamageType.Type`
- **Identity stats (NOT flat damage):**
  - `fire_rate_mult` (relative to `GameBalance.BASE_FIRE_RATE`)
  - `pellets_per_shot: int`
  - `pellet_spread_degrees: float` (≈5° for multi-pellet)
  - `bullet_speed`
  - `bullet_size` (optional baseline)
  - `max_bounces`
  - `base_mag_size`
  - `base_reload_seconds`
  - `movement_speed_bonus_pct` optional 0 (prefer mods for this)
- `drop_tickets: int` for weighted type bag
- **No `base_damage` field.** Damage always starts from `GameBalance.BASE_DAMAGE_PER_SHOT`.

### 4.3 Van-gunner-tuned family table (replace HellScape numbers)

Tune for current baseline (`BASE_DAMAGE=1.5`, `BASE_FIRE_RATE=1.75`). Values are **relative multipliers / identity**, not absolute DPS bombs.

| Type | fire_rate_mult | pellets | spread | bullet_speed | bounces | mag | reload_s | Notes |
|------|----------------|---------|--------|--------------|---------|-----|----------|-------|
| basic | 1.00 | 1 | 0 | 100 | 1 | 8 | 1.2 | Starter family |
| basic_a1 | 0.85 | 1 | 0 | 130 | 1 | 10 | 1.0 | Punchier cadence feel via mag/reload/speed, not dmg |
| basic_a1_fd/cd/pd | 0.85 | 1 | 0 | 130 | 1 | 10 | 1.0 | Same + element tag |
| shotgun | 0.55 | 8 | ±5 | 70 | 1 | 2 | 1.8 | |
| shotgun_a1 | 0.65 | 10 | ±5 | 70 | 1 | 4 | 1.5 | |
| shotgun_a1_* | 0.65 | 10 | ±5 | 70 | 1 | 4 | 1.5 | Element tag |
| machinegun | 2.20 | 1 | 0 | 90 | 1 | 30 | 2.0 | |
| machinegun_a1 | 1.90 | 1 | 0 | 110 | 1 | 40 | 1.8 | |
| machinegun_a1_fd | 1.90 | 1 | 0 | 110 | 1 | 40 | 1.8 | FIRE tag |
| machinegun_a1_cd | 1.90 | 1 | 0 | 110 | 1 | 40 | 1.8 | COLD tag (**no phys+element double-dip flat**) |
| machinegun_a1_pd | 1.90 | 1 | 0 | 110 | 1 | 40 | 1.8 | POISON tag |
| sniper | 0.35 | 1 | 0 | 180 | 2 | 5 | 2.0 | |
| sniper_a1 | 0.45 | 1 | 0 | 180 | 2 | 6 | 1.6 | |
| sniper_a1_* | 0.45 | 1 | 0 | 180 | 2 | 6 | 1.6 | Element tag |

**Elemental rule for van-gunner:**  
Elemental variants set `GunStats.damage_type` to FIRE/COLD/POISON and **do not** add a second damage channel on the gun. Conversion / bonus phys / etc. remain **boon** territory (`fire_to_phys_ratio`, `phys_damage_bonus`, …).

**A1 power budget:** mag, reload, pellets, bullet speed, slight fire_rate_mult shifts, rarity — **never** “×3 damage”.

### 4.4 Drop ticket bag (keep structure, retune if needed)

Sum example (same shape as handout):

| Type | Tickets |
|------|---------|
| basic | 1000 |
| sniper / machinegun / shotgun | 750 each |
| each `*_a1` (4) | 20 each |
| each elemental A1 (12) | 15 each |

≈7% any A1. Starter create path forces `basic` with **0 mods**.

### 4.5 `WeaponMod` (runtime)

- `grade: enum { INTERIOR, EXTERIOR }` — **no SPECIAL**
- `mod_id: int` (unique within grade)
- `display_name`
- `operator: enum { INCREASED }` — **plus/flat removed from weapon mods**
- `value: float` (rolled %)
- `tier: int` (for display / craft cost scaling)

**Duplicate rule:** same `grade + mod_id` cannot appear twice on one gun.

### 4.6 Mod catalog (PORT TARGET, van-gunner rules)

#### Grade roll weights

Start `{ interior: 200, exterior: 200 }`.  
After each roll of a grade, that grade’s weight **−100** (bias toward the other).  
No special grade.

#### Mod count weights (1–6 only)

Replace 1–8 table with 1–6:

Suggested tickets: `{700, 900, 900, 700, 400, 80}`  
Approx: ~19% / 24% / 24% / 19% / 11% / 2%

Hard clamp: `mod_count = clamp(rolled, 1, 6)` for non-starter; starter = 0.

#### Tier scaling (keep handout idea)

On generate, if `weapon_level > 2`, use `level/2` as tier pool depth (level 10 → tiers 1..5).

```
tier = 1 + weighted_pick(1..level_cap)   # descending weight preferred
range_width = (upper - lower) * tier
value = random_in [lower + range_width, upper + range_width]
```

#### Interior (damage-adjacent) — **NO FLAT**

| ID | Name | Bounds (% increased) | Weight | Notes |
|----|------|----------------------|--------|-------|
| 1 | Physical Damage | 2–5 | 1 | `% increased` only |
| 2 | Critical Damage | 2–5 | 1 | Apply as headshot / crit multiplier bump — map onto existing headshot pipeline, **not** a new crit system unless already present |
| 3 | Fire Damage | 2–5 | 1 | `% increased` fire (boon handlers already understand fire) |
| 4 | Cold Damage | 2–5 | 1 | `% increased` cold |
| 5 | Poison Damage | 2–5 | 1 | `% increased` poison |

**Removed vs source handout:** flat `+N` Fire/Cold/Poison/Physical. Those are the early-game breakers.

Implementation note: “% increased Fire Damage” should multiply fire portion / fire-tagged hits via traits or a small weapon-mod application layer — **never** `damage_per_shot += N`.

If mapping five elemental % mods is awkward on day one, **minimum viable interior** is:

- Physical Damage %  
- Critical Damage %  

…and add elemental % in a follow-up. Prefer full five if boon damage channels already split cleanly.

#### Exterior (utility) — includes new mag/reload

| ID | Name | Bounds | Weight | Effect |
|----|------|--------|--------|--------|
| 1 | Movement Speed | 1–3 % | 3 | Player move speed while this gun **active** |
| 2 | Ricochets | 1–6 % | 3 | Prefer mapping to `max_bounces` chance/extra — or `%` toward bounce count via `round(base * (1+pct/100))` |
| 3 | Fire Rate | 1–3 % | 2 | `fire_rate *= (1+pct/100)` |
| 4 | Bullet Speed | 2–5 % | 3 | |
| 5 | Bullet Size | 1–5 % | 3 | |
| 6 | **Reload Speed** | 2–5 % | 3 | **NEW** — reduces reload seconds |
| 7 | **Mag Size** | 2–5 % | 3 | **NEW** — `mag = max(1, round(base * (1+pct/100)))` |

`ExteriorWeight = {3,3,2,3,3,3,3}`

### 4.7 `WeaponInstance` (runtime state)

Must serialize for run save if `GameSession` already persists mid-run:

- `definition_id`
- `weapon_level` (used for generate/craft costs)
- `mods: Array[WeaponMod]`
- `grade_weights` leftover (optional, for craft add-mod bias)
- `current_ammo: int`
- `is_reloading` / `reload_ends_at_msec` (persist across swap)
- `uid` for UI / save

### 4.8 Effective combat stats pipeline (critical)

**Goal:** Weapon defines identity; boons define scale; balance defines floor.

Suggested rebuild order in `GunStatsController` (or a new `WeaponStatsBuilder` called by it):

1. Start from `GameBalance.BASE_DAMAGE_PER_SHOT` and `BASE_FIRE_RATE`.
2. Apply **active weapon definition** identity:
   - `fire_rate = BASE_FIRE_RATE * definition.fire_rate_mult`
   - `damage_per_shot = BASE_DAMAGE_PER_SHOT` (**no definition flat**)
   - mag / reload / bullet_* / bounces / damage_type / pellets from definition
3. Apply **weapon mods** (increased % only) onto the appropriate fields / trait mirrors.
4. Apply **run boons** (`BoonTraits` gun_* and combat damage handlers) — **this is the long-term DPS curve**.
5. Apply temporary `StatModifier`s (stim tools).
6. Clamp as today.

**Pellets:** `GunController.try_fire` must spawn `pellets_per_shot` projectiles with spread. Damage per pellet = `damage_per_shot` (full) **or** split — **choose one and document**:

- **Recommended for no early spike:** each pellet deals `damage_per_shot` *only if* shotgun family fire_rate/mag already tax DPS; OR better: `damage_per_pellet = damage_per_shot / pellets` so shotgun is coverage, not ×8 damage.  
- **Mandatory:** shotgun must not be ×8 effective DPS vs basic at equal mods. Prefer **damage split across pellets**.

Approx DPS for balance checks:

```
dps ≈ (damage_per_shot) * fire_rate * (1 if pellets split else pellets)
```

With pellet split, shotgun DPS ≈ same order as basic before mods/boons.

---

## 5. Inventory & input

### 5.1 `WeaponInventory` (player component)

- Slots: **exactly 2** (`Array[WeaponInstance]` size 2, nullable)
- `active_index: int` 0 or 1
- Signals:
  - `loadout_changed`
  - `active_weapon_changed(index, instance)`
  - `weapon_pickup_rejected(reason)` // full, etc.

API:

- `get_active() -> WeaponInstance`
- `try_add(instance) -> enum { STORED, REPLACED, REJECTED }`
- `replace_slot(index, instance) -> old_instance` (old becomes world drop)
- `swap_active()` / `cycle_active(dir: int)`
- `drop_active()` optional

**Starter:** slot 0 = generated starter basic (0 mods, level = run start level or fixed 1); slot 1 = `null`.

### 5.2 Switching

| Input | Behavior |
|-------|----------|
| Mouse wheel up/down | Cycle active weapon (skip empty slots) |
| Q (`use_usable` action) | Swap to other slot if occupied; if empty, no-op |

Implementation notes:

- Handle in `FpsPlayer` `_unhandled_input` / `_input` when mouse captured and bench closed.
- On swap:
  1. Save ammo/reload state into leaving `WeaponInstance`
  2. Push new instance into `GunStatsController` / rebuild
  3. Restore ammo/reload into `GunController`
  4. Brief swap lock (100–150ms) optional to prevent scroll spam fire bugs
- Update ammo HUD from active gun signals (reconnect or multiplex).

**Do not** bind weapon switch to 1–4 (those are tools).

### 5.3 World grab / inventory UX

Weapons are loot, parallel to items but **not** `ItemKind` unless you extend the enum.

**Recommended:** new `WeaponPickup` (or `Pickup` variant with `weapon_instance` payload):

1. Drop near corpse / shop spawn / reward.
2. **Shoot** to stash toward van loot anchor (reuse `LootCollector` pattern) **or** allow direct interact — match existing item feel: shoot-to-stash then walk-collect is consistent.
3. On collect:
   - If empty slot → auto-equip into empty slot; toast “Picked up {name}”.
   - If both full → open **quick swap prompt** (simple UI): show both current guns + new gun; click one to replace (replaced gun dropped as pickup). Esc cancels (leave weapon on ground/table).
4. Never silent-destroy a gun.

**Shop:** extend shop to sometimes stock a `WeaponOffer` (separate from item offers) priced in gold. Price formula:

```
base = max(80, mods.size() * max(1, level) * 25 + rarity_premium)
price = rng(base, base * 2)   # already expensive vs typical boon shop prices
```

A1 / elemental: add large premium (+150–400).

---

## 6. Required changes to existing gun rebuild behavior

Today `GunStatsController._rebuild` forces:

```
stats.fire_rate = GameBalance.BASE_FIRE_RATE
stats.damage_per_shot = GameBalance.BASE_DAMAGE_PER_SHOT
```

After weapons:

- Keep **damage_per_shot** seeded from balance (good).
- Change **fire_rate** seed to `BASE_FIRE_RATE * active_definition.fire_rate_mult` (not always bare BASE).
- Mag/reload/bullet fields must come from **active WeaponInstance**, not only `default_gun_stats.tres`.
- Boon mults still apply after.

Ensure `base_stats` resource is either replaced per swap or ignored in favor of weapon builder.

---

## 7. Generation API

```
CreateWeapon(level: int, force_definition_id: StringName = &"", force_mod_count: int = -1) -> WeaponInstance
```

Algorithm:

1. Pick definition from ticket bag (or force).
2. If starter / `force_mod_count==0`: return with empty mods.
3. Else roll mod count 1..6 from weights.
4. Init grade weights `{200,200}`.
5. For each mod slot:
   - Pick grade by weight; decrement that grade −100
   - Pick mod id by pool weights excluding duplicates already on gun
   - Roll tier + value
6. Attach `weapon_level = level`

Monster drop:

```
if rng(1,100) > 100 - drop_chance: drop CreateWeapon(monster_level)
```

- Base `drop_chance ≈ 1` (very rare)
- Elite/boss: `+10` (~10%)
- Mission/act multipliers optional via `GameBalance` new fields

Always keep coin drops as they are; weapons are extra-rare spice.

---

## 8. Bench Screen — Page 2 (Weapon Crafting)

### 8.1 UI structure

Extend `BenchScreen` / `bench_screen.tscn`:

- Add **tabs or page toggle** at top: `Overview` | `Weapons`
- Page 1 = current content (van stats, gold, boons/tools)
- Page 2 = weapon crafting

Page 2 layout (keep visual language of bench: accent/muted colors, cell grids, tooltip):

```
[ Slot A card ]     [ Slot B card ]
  icon/name           icon/name
  family / element    ...
  ammo                ...
  mod list (≤6)       mod list

[ Selected weapon detail ]
  Full mod lines with values
  Effective stats preview (fire rate, mag, reload, pellets, type)

[ Actions ]
  Add Random Mod     cost XXXX gold
  Remove Mod…        cost XXXX gold (pick one)
  Reroll One Mod…    optional v1.1
  Destroy Weapon     refund small gold OR none (prefer tiny refund so sink stays harsh)
```

Empty slot shows “Empty — find a gun” CTA.

### 8.2 Gold costs (mega-expensive)

Use gold only. Tune relative to van speed upgrades (50/100/150/200) and shop boon prices — crafting should hurt.

Suggested formulas (level = weapon_level, n = current mod count):

| Action | Cost |
|--------|------|
| Add mod | `80 * (level) * (n + 1) * (1 + times_add_used)` | 
| Remove mod | same as add |
| Remove & keep as “saved mod” | **Skip for v1** (layout inventory cut) |
| Destroy weapon | refund `floor(add_cost_if_empty * 0.25)` or **0** (prefer 0–small) |
| Disassemble to parts | **Skip for v1** (conflicts with 2-slot simplicity) |

Example: level 10, 3 mods, first add: `80 * 10 * 4 = 3200` gold.  
Second add on same gun multiplies by times used → quickly 5k–10k+.

**Guardrails:**

- Cannot add if `mods.size() >= 6`
- Cannot add duplicate grade+id
- Cannot craft on empty slot
- Cannot destroy starter if it is the only gun (or allow but immediately recreate starter — prefer **block destroy on last remaining gun**)

Spend via `GameSession.spend_coins`. Refresh gold label already on bench.

### 8.3 Add-mod behavior

When adding:

1. Use remaining grade weights on the instance (persist weights on instance).
2. Roll grade + mod + tier/value like generate.
3. Append; rebuild active stats if that gun is active.

### 8.4 Binding changes

`BenchScreen.bind(...)` should also receive `WeaponInventory`.  
`CraftingTable.opened` → van opens bench as today; page defaults to last page or Overview.

---

## 9. HUD / feedback

1. **Ammo HUD** — unchanged format `AMMO cur / max`, but sourced from active weapon; show weapon short name optionally: `BASIC  6 / 8`.
2. **Weapon slots HUD** (new small widget near ammo or item HUD):
   - Two slots; highlight active
   - Icon + 1–2 letter family code
   - Empty slot dashed
3. **Swap toast** optional brief name flash
4. **Pickup prompt** when looking at weapon pickup (“E / walk to take”)

---

## 10. Persistence

If runs save mid-flight (`GameSession` dict):

Serialize per weapon:

```
definition_id, level, mods[{grade,id,value,tier}], ammo, reload_remaining, grade_weights, uid
```

On load: rebuild instances → inventory → apply active to gun controller.

Meta progression: **do not** persist run guns between runs unless explicitly desired later.

---

## 11. File / integration checklist (implementation order)

### Phase A — Data + generate (no inventory UI yet)

1. Add `WeaponDefinition` resources for 4 families × base/A1/elemental.
2. Add mod catalog + `WeaponGenerator`.
3. Unit-testable pure GDScript RNG functions (mod count, grade bias, no flats).
4. Debug command: `give_weapon <id>` / `give_random_weapon` in `debug_commands.gd`.

### Phase B — Stats bridge

1. `WeaponStatsBuilder` → `GunStats`.
2. Wire `GunStatsController` to active instance.
3. Pellet spread in `GunController` / `BoonCombat.spawn_projectile`.
4. Confirm shotgun pellet split prevents ×8 DPS.
5. Confirm elemental only sets `damage_type`.
6. Confirm reload % reduces seconds.

### Phase C — Inventory + input

1. `WeaponInventory` on player.
2. Starter gun seed on run start.
3. Scroll + Q swap; persist ammo.
4. Weapon slots HUD + ammo rename.
5. Block swap during bench / pause / boon choice if those UIs capture mouse.

### Phase D — World / shop acquisition

1. `WeaponPickup` + loot collector path.
2. Full-inventory replace prompt.
3. Elite/boss drop chance hooks in `LootDropComponent` or encounter code.
4. Shop weapon offers.

### Phase E — Bench page 2

1. Tabbed `BenchScreen`.
2. Add/remove mod + destroy with mega gold costs.
3. Effective stats preview.
4. Polish tooltips (reuse `%Tooltip` pattern).

### Phase F — Balance pass

1. Play Act 1 with A1 drop forced — must not trivialize.
2. Play with heavy phys/fire boons — guns should amplify identity, boons dominate curve.
3. Tune drop_chance and craft costs.

---

## 12. Mapping from original handout → this game

| Handout | Van-gunner decision |
|---------|---------------------|
| Flat elemental/phys on guns | **Removed** |
| Special mod grade | **Removed** (boons already cover) |
| gunParts currency | **Gold instead** |
| 1–8 mods | **1–6 mods** |
| 4 guns + layout slots | **2 guns only** |
| Mag/reload systems | **Already exist** — add as exterior mods |
| Damage formula with huge bases | **Balance-seeded tiny bases + boon scale** |
| Crafting add/remove | **Bench page 2, mega expensive** |
| Shop weapons | **Yes, gold, expensive** |
| Monster weapon drops | **Yes, rare** |
| Reload Speed / Mag Size new | **Yes** |
| Switch weapons | **Scroll + Q** |
| Grab inventory | **Yes, with replace prompt when full** |

---

## 13. Damage scaling philosophy (for the implementing LLM)

**Wrong:** A1 sniper with 300 base damage + flat fire mods + phys boons.  
**Right:** All guns ~1.5 baseline damage; sniper fires slow with high bullet speed and small mag; `% increased phys` on gun is a modest multiplier; `more_phys_50` boon is the real spike; fire A1 sniper tags shots FIRE so fire boons wake up.

Pseudo:

```
shot_damage = balance.base_damage
shot_damage *= (1 + weapon_increased_phys_pct/100)   # if applicable to this hit channel
# then BoonCombat.modify_outgoing_damage / elemental handlers
# headshot multipliers from DamageInfo as today
```

Never:

```
shot_damage = definition.flat_damage + sum(flat_mods)
```

---

## 14. Edge cases

- Mag size shrinks below current ammo → clamp ammo (`GunController` already clamps on stats_changed).
- Reload in progress → swap weapon: store remaining time; other gun independent.
- Both slots empty impossible if starter protected.
- Adding mod while gun active → live rebuild mid-bench OK.
- Movement speed mod: apply only while that weapon active (listen to `active_weapon_changed`).
- Bonus projectiles from cold boons: inherit active gun damage_type/stats unless boon says otherwise (keep current `BoonCombat` behavior).
- Grenades / tools unchanged.
- `TimedStatModifierEffect` still stacks on controller after weapon mods.

---

## 15. Telemetry / debug affordances

- Debug overlay: active definition id, mod list, effective mag/reload/fire_rate/damage.
- Console: force drop, force A1, set craft cost multiplier for testing.
- Balance resource fields to add:

```
weapon_drop_chance_base
weapon_drop_chance_elite_bonus
weapon_craft_cost_mult          # global knob for “mega expensive”
weapon_shop_price_mult
weapon_max_mods                 # = 6
```

---

## 16. Acceptance criteria (definition of done)

- [ ] Player holds at most 2 weapons; starter basic present.
- [ ] Scroll and Q swap; ammo/reload persist per gun.
- [ ] Generated guns roll ≤6 mods; interior/exterior only; no specials; no flat damage mods.
- [ ] Exterior can roll Reload Speed and Mag Size; both affect live combat correctly.
- [ ] Elemental variants change damage type only (no flat element packs).
- [ ] Shotgun pellet math does not multiply DPS by pellet count.
- [ ] Weapons drop rarely; shop can sell weapons for high gold.
- [ ] Full inventory prompts replace; replaced gun returns to world.
- [ ] Bench has Weapons page; add/remove mod costs huge gold; cannot exceed 6 mods.
- [ ] Long-term DPS still primarily from boons; Act 1 A1 does not break pacing.
- [ ] Existing boon specials still work with swapped guns.
- [ ] No `gunParts`; all sinks/spends use `GameSession.coins`.

---

## 17. Suggested class responsibilities (for code structure)

| Class | Responsibility |
|-------|----------------|
| `WeaponDefinition` | Static archetype data |
| `WeaponModCatalog` | Pool defs + weights |
| `WeaponGenerator` | Pure create/roll |
| `WeaponInstance` | Owned rolled state + ammo |
| `WeaponInventory` | 2 slots + active |
| `WeaponStatsBuilder` | Instance → `GunStats` |
| `WeaponPickup` | World entity |
| `WeaponReplacePrompt` | UI when full |
| `BenchScreen` | Page 2 crafting |
| `GunController` | Fire/reload; pellet loop |
| `GunStatsController` | Effective stats; listen inventory |
| `FpsPlayer` | Input swap |
| `LootDropComponent` / encounter | Drop rolls |
| `ShopStock` | Occasional weapon offer |

---

## 18. What to implement first if time-boxed

**MVP slice (still “whole system” shaped):**

1. Definitions + generator (no flats, max 6, reload/mag exterior).  
2. Inventory 2 + swap scroll/Q.  
3. Stats bridge + pellet split.  
4. Pickup + replace prompt.  
5. Bench page 2 add/remove with brutal gold costs.  
6. Tiny drop chance on elites + one shop gun.

Defer: saved-mod layout, disassemble, gunParts, specials-on-guns, 8-mod curve, HellScape damage tables.

---

## 19. Reference: original handout deltas summary

Source handout ideas kept: families, A1/elemental rarity, interior/exterior grade bias, weighted mod counts, shop/drop/craft loops, reload/mag exterior, specials-as-boons.  
Source ideas cut/changed: flats, specials, gunParts, 8 mods, 4+layout inventory, absolute high damage bases.

---

*End of spec. Implement against van-gunner paths in §2; when uncertain, prefer existing boon/combat patterns over inventing parallel systems.*
