# FPS arms walk: research and bar

Owner, 2026-10-03: "make it look better when we move, use the arms to give the notion that we
are walking ... some mix between the idle and something else". Answers: the free left hand
swings like a real arm, heavy goblin lumber, start/stop overshoot and strafe lean (no jump
kick, no camera bob).

## Before

`gun_viewmodel.gd` walk bob: one translation (x 0.015 sin p, y 0.02 sin 2p, rig units) shared by
gun and both arms, fixed 8 rad/s clock not tied to steps, no rotation, no lag, no start/stop,
no strafe, idle drift keeps running at full strength underneath. Camera never bobs.

## Research (sources)

- Project Killhouse procedural weapon animations (devunallocated.com): step clock t and 2t,
  figure-8, breathing masked by `1 - speed/threshold`, strafe roll, landing through recoil.
- HL1 view bob tutorial (twhl.info, parts 1 and 2); CS:GO `cl_bob*` cvars.
- David Rosen, GDC 2014 "An Indie Approach to Procedural Animation": phase from distance
  travelled / stride, so the bob never desyncs from the feet.
- Destiny FP animation GDC (gdcvault 1022297), Overwatch FP bootcamp (1024319),
  mocaponline FP animation guide, KINEMATION sway springs.

Takeaways: phase from distance (stride ~0.75 m, cycle = 2 steps); lateral/roll/yaw at the half
rate, dip and pitch at the step rate (figure-8, never a U or |sin|); rotation does the work,
translation small; amplitude follows smoothed speed, frequency never scales with speed; never
reset phase; start/stop through an under-damped spring (lag, then overshoot); strafe roll
toward the move; a free hand swings counter to the legs through its own looser spring; mask
the idle as you move; no camera bob (nausea).

## Design

`scripts/player/arms/arm_walk.gd` (RefCounted helper of `GunViewmodel`): phase, smoothed
amount, strafe lean, a velocity spring (offset = spring velocity - real velocity) for the
start/stop lag and overshoot, and a left-arm swing filtered through its own spring. Rotations
pivot about `HeldGun.GRIP`. The idle arm drift fades to 30% at full walk. Debug:
`arms walk <cycle 0..1> [amount]`, `arms walk start|stop <seconds>`, `arms walk off`.
Smoke saves `a*-arms-walk` at cycle 0.75 (left arm forward peak).

## Bar

1. Idle unchanged: with the walk at rest, every player view and the idle FRAME line are `same`
   as before.
2. Readable: at `arms walk 0.75` the FRAME box x-min is <= 0.15 (left hand in the lower-left)
   and cover is >= 2 points above `arms walk 0.25`.
3. Crosshair clear: aim <= 0.5 and upper <= 10% at every pinned cycle 0, 0.25, 0.5, 0.75.
4. Smooth: `anim_series` over `arms walk {t}` 0:1:16 has no step-to-step change over 2x the
   median (no snap); `arms walk start {t}` 0:1.2:12 shows the lag then one overshoot and settles
   by 1.0 s.
5. Heavy: the rig rolls 3-4 degrees per step and dips on each footfall (one look at the
   player-view still, one line).

## Rounds

(one line per commit: worse / why / solve, with the numbers)
