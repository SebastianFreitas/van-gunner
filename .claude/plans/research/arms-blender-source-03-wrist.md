# arms-blender-source 03: left wrist step toggles (phase 3, blocked)

Measured with `arms hands`, each `ArmBulk.inflate` step off in turn (temporary toggle, reverted). Rows marked suspect gave L == R and likely broke the toggle.

    # Wrist step toggles (arms hands). Columns: step off | L W0 | R W0 | L/R wrist_step | L/R jump
    none      | .060 | .075 | .036/.000 | 3.04/3.18
    refine    | .044 | .071 | .038/.003 | 5.42/7.15
    smooth    | .060 | .076 | .049/.003 | 3.82/3.85
    weld      | .060 | .075 | .036/.003 | 3.04/3.18
    twist     | .060 | .093 | .072/.072 | 4.89/65.5
    handgain  | .080 | .081 | .030/.017 | 6.59/5.23
    thumb     | .060 | .075 | .036/.000 | 3.04/3.26
    knramp    | .060 | .075 | .036/.000 | 3.15/3.18
    dome      | .060 | .075 | .036/.000 | 3.04/3.17
    muscle    | .025 | .025 | .182/.182 | 4.37/4.37 (toggle result suspect: L==R, seam 0)
    vein      | .025 | .025 | .036/.036 | 4.49/4.49 (suspect, same)
    Finding: slab-0 hand-dominant set differs. R edge vert lat -0.0701 is DEF-palm.01.R (w .34, dominant);
    the L mirror (lat -0.0733) is DEF-thumb.01.L (w .46) so _shape excludes it. ArmWeightSmooth off leaves L W0 .060,
    so the thumb.01 vs palm.01 weights differ in the source glb.
