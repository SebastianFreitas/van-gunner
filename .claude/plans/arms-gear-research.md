# Arms gear dress: research and rounds

Owner (2026-10-02): replace the "absolute crap" hand dressing (kept as `arms dress rags`) with
skin layers and objects that hold up under any animation. After round 2 the owner cut the
objects: "the ring is awful, just remove it, and all that trash on the right hand remove it,
the sleeve is enough, put sleeve on both arms" (the spiked band went too).

## The bar

- Player view (`01-idle-front`): no bolt-on clutter on the hands; the left-forearm van-name
  tattoo reads; mean brightness at most +0.004 over the clean tree.
- Sleeves read as loose torn T-shirt sleeves on the upper arms with an open hem, not as a ball
  or sack, from the side, top and elbow debug views; no see-through faces.
- `arms gear` = `GEAR OK` (no own-bone skin through a sleeve in any weave, kick or reload pose);
  `arms fit` = `FIT OK`; check, smoke and van audit clean; exterior views `same`.
- Every review round ends `REVIEW CLEAN` before landing.

## Rounds

| Round | Change | Measure |
|---|---|---|
| 1 (`fb8559c`) | sleeve, straps, spiked band, thumb ring, skin-layer shader pass, cloth shader | `GEAR CLIP 664` (mostly checker faults) |
| 1 fixes (`1bb3a54`) | linear skin colours, facing at build time, torn holes, own-bone checker | `GEAR CLIP 20` (worst 0.22 r) |
| 2 (owner cut) | straps, band, ring deleted; sleeve on both arms | `GEAR CLIP 20`; sleeve reads as a red ball under the elbow; tattoo off-screen |
| 2 fixes | sleeve stops at `DEF-upper_arm.001` t 0.80, hem flare 0.10-0.40 r; tattoo moved to forearm t 0.80 to forearm.001 t 0.65 | `GEAR CLIP 9` (worst 0.17 r); "THE LAST RUN" reads in `01-idle-front` |
| 3 | hem at t 0.72, hem rings (s >= 0.7) drop forearm weights; checker skips the pulled-back hem slab and counts upper-arm skin only | `GEAR OK`, `FIT OK`, `REVIEW CLEAN`; `01-idle-front` mean 0.0588 vs 0.0608 before |

## What did not work

- Raising the hem's minimum gap (0.06 to 0.16-0.22 r) changed nothing: the hem offset (about
  0.33 r plus folds) already exceeds it. The clips came from elbow skin the cloth weights
  followed, not from a thin gap.
- Sweeping the hem end 0.68-0.80 moved clip counts between 0 and 4 without converging; the
  last clip was lower-forearm skin, outside the cloth by design once the sleeve ended above
  the elbow.
