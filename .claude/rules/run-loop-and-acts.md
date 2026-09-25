---
paths:
  - "scripts/core/game_session.gd"
  - "scripts/core/session_*.gd"
  - "scripts/core/game_balance*.gd"
  - "scripts/acts/**"
  - "scripts/enemies/encounter_*.gd"
  - "scripts/ui/act_reveal_*.gd"
  - "resources/acts/**"
  - "resources/balance/**"
---

# Run loop, acts and street cards

`GameSession.RunPhase` is the single source of truth for what the game is doing. Every system reacts to `phase_changed`; systems don't drive each other directly.

```
IDLE ──(Shift GO / yell let's go)──> TRAVELLING
TRAVELLING ──(act deck empty)──> ACT_REVEAL ──> ROUTE_CHOICE
ROUTE_CHOICE ──(pick a street card)──> TURNING ──> TRAVELLING
  └── PARKING ──> STOP ──> TRAVELLING  (every street has a side stop)
TRAVELLING ──(EncounterDirector timer)──> COMBAT ──> REST
REST ──(boon pick for the committed street card)──> ROUTE_CHOICE
 ...six cards later...
REST ──> BOSS_PICK ──> TRAVELLING ──> COMBAT (boss) ──> REST ──> ACT_REVEAL (next act)
any ──(van hull or player HP hits 0)──> GAME_OVER
```

## Acts

An act is a deck of 6 street cards, 3 BLESSING and 3 DANGER, drawn at a roadside statue (`ACT_REVEAL`) and shown shuffled. At each fork the player sees the top cards face-up (three at a 4-way, two at a T); taking one commits it and leaves the rest in the deck. A committed card:

- applies its `ActCardEffect`s to combat for that street (`ActCardCombat`);
- owes the player a 3-choice boon at the following `REST`;
- if DANGER, bumps the next wave plan (`apply_danger_bump` in `encounter_spawner.gd`, ×1.35 + 1).

When the deck empties, the six cards come back face-down and the player picks `BOSS_CARD_PICK_COUNT` (two) to bind to the act boss; both cards' effects stack on that fight. Beat it and a new deck is drawn.

Default forks are 4-ways. T-junctions are used when fewer than three cards remain, or when **No Through Road** was the previous street: that DANGER card sets `GameSession.pending_narrow_fork`.

## Where the code lives

- `game_session.gd` holds every signal, state field and public method. Save serialization, act deck logic and vital bookkeeping are static helpers in `session_save.gd`, `session_act_deck.gd`, `session_vitals.gd`; each takes the session as its first argument and never names `GameSession` or preloads the autoload.
- `encounter_director.gd` owns the wave `await` chains; `encounter_spawner.gd` spawns and queries raiders.
- `act_deck_controller.gd` drives reveal and boss pick; `act_reveal_panel.gd` is the UI, with card building in `act_reveal_cards.gd`.

## Async sequences are guarded by a counter

`TravelController` and `EncounterDirector` run long `await` chains. Both hold `_sequence_id: int`; every new sequence increments and captures it, then after each `await` checks `if id != _sequence_id: return`. That is how a chill toggle, a phase change or a teardown cancels an in-flight coroutine. Any new `await` chain in those files needs the same guard, or two directors run waves at once. Awaits stay on the node, never in a RefCounted helper.

## Determinism

Act deck shuffles are seeded from `hash([run_seed, run_act, channel])` (`session_act_deck.gd`), so a reload mid-act rebuilds the same deck. Wave composition and spawn jitter use unseeded `randf()`/`randi()` on purpose, so replays aren't identical. Street layout (neighborhood variant, side streets, bay side, auto route pick) draws from `TravelController._rng`, seeded with `run_seed`; facades derive their own per-tile RNG from `hash([run_seed, _segment_index])` and never draw from `_rng`, because every extra draw there shifts the stop and fork sequence. The smoke fingerprint's `[act_deck]` line guards the seeded part.

## Registry

`ActCardRegistry` scans `res://resources/acts/cards/` with `DirAccess`. Packed listings may use `foo.tres.remap`; `list_ids()` strips `.remap` before the `.tres` check. An empty list `push_warning`s rather than failing quietly.

## Deliberate choices: don't change without asking

- **Wave counts in `game_balance.tres` are test values the owner changes freely.** The working tree may hold an uncommitted edit; never stage it. The smoke `[waves]` section pins `segment_wave_min` and `segment_wave_max` while it plans (`WAVE_MIN_PIN` / `WAVE_MAX_PIN` in `smoke_fingerprint.gd`), so an owner edit there never needs a re-bless and a clean clone reproduces the baseline.
- **`GameBalance.get_act(route_step)` and `GameSession.run_act` disagree.** `get_act` is the old three-step pacing model (act 3 from route step 3 on); `run_act` is the deck-based counter (one act = six cards = six route steps). Every balance curve (mob world speed, engagement seconds, expected van upgrade fraction, wave sizing) still reads the old one, so difficulty stops scaling early in act 1. This is an open design question the owner is working on. Do not unify the two, do not rewire `get_act` to take `run_act`, do not add a shim. Raise it and wait.
