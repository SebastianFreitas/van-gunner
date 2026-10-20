# hands-blender-review research 03: where the width goes (D24, D25), knots (D28)

Gate review round 1 (build 1, 5; design 2; art 1). Source: today's `assets/models/arms/arms.glb` read with stdlib Python (node rest transforms, skin JOINTS/WEIGHTS, the `_shape` / `_wrist` frames re-implemented; W0..8 match `vg-p4/hands_p95.txt` exactly).

## Frame (both hands, rest)
- span (head to finger-root centre) .1568, fore_len .5048; `.01` roots s / lat: index 1.002 / -.0526, middle 1.051 / 0, ring 1.061 / .0507, pinky .885 / .0918 (pinky knuckle sits in slab 7). Shafts (tres): index .0274, middle .0333, ring .0270, pinky .0239. Outer tube edges: index -.080, pinky .116.
- W per side (index / pinky p95), R: .070/.074 .075/.081 .087/.088 .089/.093 .091/.107 .081/.115 .095/.117 .091/.114 .078/.107 (L same from slab 2; L slab 0-1 .062/.079 .070/.077). The combined W is the pinky side diluted by the index side's vertex count, so its "W5 bulge" is partly a counting artifact; the index side dips at slab 5 where the thumb's weights leave.
- Today's flanks already sit at the outer tube edges (.078 vs .080, .114 vs .116): a uniform x1.212 (T8 .120) moves the ring root's skin .011 and the pinky's .019 across their tubes (the build finding holds).

## Anatomy
- ANSUR hand breadth (metacarpale II-V) is about 1.05-1.1x the summed proximal finger breadths: the 2nd and 5th MCP heads and the hypothenar edge stand 0.2-0.45 finger radius past the outer fingers. Chosen 0.3 shaft: pinky side .0918 + 1.3 x .0239 = .123 at slab 7, index side .0526 + 1.3 x .0274 = .088 at slab 8.
- Heberden (DIP) and Bouchard (PIP) nodes, the look of a gnarled old hand, are bony dorsal-lateral swellings either side of the extensor tendon, uneven between fingers; never a full collar.

## Field simulated (flanks only, root lines protected by smoothstep(0.5, 0.875, s), one correction pass)
- palm half .1052 -> .1070 R / .1067 L, `wrist/palm` .746 R / .721 L (today .820 / .790). The rig's root spread and the fixed forearm cap the ratio near .72-.75; T8 .120's .677 / .653 needed the uniform scale.
- Pinky side reached .074 .084 .094 .100 .113 .114 .120 .122 .115 R after one correction: up to .004 off T, jump 1.9, so the fallback may run twice; an exact hit has the ramp's jump 1.45.
- `wrist_step` L: .036 with f held at 1 to s 1/16 then linear to f1 at 1/8; .054 (over 0.05) without the hold. R stays .000.
- Combined W stays non-monotone (W5 .115 > W7 .112), so `growth` gates the pinky side.
