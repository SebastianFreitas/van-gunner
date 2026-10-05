---
paths:
  - "tools/gen_enemy_sprites.py"
  - "tools/anim_series.py"
  - "scenes/enemies/**"
  - "scripts/enemies/window_raider_anim.gd"
---

# Art style: the loper (door and window raider)

The pixel-art rules it follows are in `art-pixel.md`.

**Creepy, not cute** (owner, 2026-10-01, second pass): the raiders are Darkest
Dungeon dark, never bright or rounded. The door raider is a humanoid gone
feral, the loper: a 64 x 80 frame (1.54 x 1.92 m, claws on the van floor) on a
832 x 640 sheet (row 0 the thirteen-frame run; row 1 a five-frame front-on jump take-off (the run's rising half, pushed further), frames J0-J3 keep a claw row on the floor row and J4 is airborne; row 2 a four-frame latch, clip `latch`: reach, impact, pull in, cling; row 3 an eight-frame front-on wall crawl, clip `climb`, diagonal pairs (left fore paw with right hind foot, then the mirror), never flipped; row 4 a six-frame bar rake, clip `rake`, a window loper's swing at the bars (ready, wind-up, strike, impact at frame 3, recoil, recover); row 5 a six-frame on-foot claw swipe, clip `swipe`, inside the van (left paw braced on the floor, legs planted, right paw rears up and strikes down across the body at the viewer, impact at frame 3); row 6 a five-frame climb in over the sill, clip `enter`, played while a window loper is ENTERING (6 fps, holds the last frame); row 7 a six-frame missed jump, clip `tumble` (knocked back in the air, slam on the road, tuck, upside-down roll via the `rot` quarter-turn pose key, push up, rise into the run), played while a loper shot mid-jump is KNOCKED; animation is frame-swapping on one sheet,
never a node tween: a bounding charge seen from the front at 18 fps, crouch,
push, paws-rise, lift-off, tip-over, kick, fall, drop, reach, rump-down, land,
gather; the kick, fall and drop frames are airborne, the kick 4 px off the floor
and the hindquarters over the skull, a two-lobed rump with a tail-bone stub
standing above the dropped hump and both hind feet sole-on at the top corners
with the claws up, while every other frame keeps a claw row on the floor row;
the hump may rise at most 5 px since its top knob is on row 5, the head drops
up to 13 px on the kick, and the jaw and strands trail the bob),
a hyena-ape hunched so the skull hangs forward from a furred ruff below one
furred mantle (shoulders, neck and spine hump in a single polygon, bone spine
knobs poking through), in a mangy soot-black coat (sRGB 42,34,28 fur, 25,21,18
shadow, 64,53,42 highlight, bare skin patches), never balls joined by
ellipses: tapered limbs with fur sleeves and hip tufts, a furred rump, and hair
tufts on every edge that trail the bob by a frame and flare on landing; arms
longer than the legs with the claws on the floor, a torn shoulder and blood
down the belly. The head is the feral face (owner, 2026-10-03, every run frame,
`draw_feral_head`): a long angular skull, never round, under a matted hair cap,
a hard V brow over slanted black sockets with red eyes (sRGB 214,30,22, one
255,214,120 hot pixel each), a bare nasal pit, and a maw split into the cheeks
with red gums, tapered hooked fangs (two long upper canines, never even human
teeth) and a hanging pointed jaw with its fangs up. Corpse grey-green skin
(sRGB 72,78,68 base, 42,46,40 shadow, 104,110,96 highlight), so the body reads
as a shape the dark swallows. The one exception is the face, so the player
finds the head hitbox: pale rim pixels (sRGB 176,172,150, mid 134,132,114) only
on the face's edges that face the upper-left light (left temple and cheek, the
jaw's left edge), about 20 pixels; never a pale fill, never on the chin or the
right side, and no marks under the eyes (they read as blushing).
Asymmetry (the tilted head, one arm lower, uneven teeth) is what keeps a
sprite from reading as cute. The loper is also the window raider
(the first-pass crawler was retired, 2026-10-03). It is drawn by `tools/gen_enemy_sprites.py`
(19 flat colours, outlined, lit from the upper left) and shown at
`pixel_size 0.024`, `texture_filter 0`, `alpha_cut 1`; re-run the script
after changing a colour or a shape, never paint over the PNGs.
