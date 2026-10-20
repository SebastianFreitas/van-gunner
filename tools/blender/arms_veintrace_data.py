"""The owner's fist photo, traced (research 05): per hand the vein polylines as (s_n, n, w).

s_n is s in hand lengths (0 wrist crease, 1 knuckle row, negative up the forearm), n the lateral
position (-1 thumb-side flank, +1 pinky-side flank), w the visible width as a fraction of the
hand width at the knuckle row. A path is (name, points, (start_free, end_free)); a point shared
by two paths is listed with the same (s_n, n) in both, which makes the join exact."""

F_L = (0.88, 0.00)  # L's fork
KNOT_TOP = (-0.03, 0.79)  # R-knot's top, where R-diag starts
FORK_R = (-0.22, 0.68)
F_R = (0.50, -0.26)  # R's hand-back fork: lower and wider than L's

PATHS = {
    "L": [
        ("L-main", [(-1.88, 0.90, 0.030), (-1.47, 0.65, 0.040), (-1.00, 0.30, 0.035),
                    (-0.65, 0.40, 0.035), (-0.29, 0.75, 0.035), (0.00, 0.80, 0.033),
                    (0.30, 0.55, 0.033), (0.65, 0.27, 0.029), F_L + (0.022,)], (1, 0)),
        ("L-Y1", [F_L + (0.015,), (0.96, 0.12, 0.008)], (0, 1)),
        ("L-Y2", [F_L + (0.015,), (0.95, -0.15, 0.008)], (0, 1)),
        ("L-thumbward", [F_L + (0.020,), (0.62, -0.33, 0.016), (0.41, -0.48, 0.012)], (0, 0)),
        ("L-B", [(0.00, 0.80, 0.026), (0.25, 0.88, 0.022), (0.50, 0.80, 0.019),
                 (0.72, 0.66, 0.015), (0.84, 0.62, 0.011)], (0, 1)),
        ("L-B2", [(0.72, 0.66, 0.012), (0.77, 0.85, 0.008)], (0, 1)),
        ("L-C", [(0.14, -0.28, 0.026), (0.28, -0.15, 0.022), (0.50, 0.06, 0.018),
                 (0.65, 0.27, 0.014)], (1, 0)),
        ("L-D", [(0.16, -0.68, 0.024), (0.22, -0.62, 0.020), (0.41, -0.48, 0.014)], (1, 0)),
        ("L-link2", [(0.50, 0.06, 0.012), (0.60, -0.12, 0.011), (0.62, -0.33, 0.012)], (0, 0)),
        ("L-link3", [(0.30, 0.55, 0.014), (0.40, 0.70, 0.013), (0.50, 0.80, 0.014)], (0, 0)),
        ("L-ladderB", [(-1.35, -0.10, 0.040), (-1.88, 0.35, 0.030)], (1, 1)),
    ],
    "R": [
        ("R-knot", [KNOT_TOP + (0.035,), FORK_R + (0.035,), (-0.47, 0.50, 0.030),
                    (-0.92, 0.40, 0.030), (-1.20, 0.46, 0.027), (-1.42, 0.47, 0.025),
                    (-1.58, 0.42, 0.020)], (0, 1)),
        ("R-arm2", [FORK_R + (0.030,), (-0.47, 0.95, 0.025), (-0.80, 0.95, 0.015)], (0, 1)),
        ("R-diag", [KNOT_TOP + (0.028,), (0.00, 0.42, 0.026), (0.19, 0.16, 0.023),
                    (0.36, -0.11, 0.018), F_R + (0.014,)], (0, 0)),
        ("R-Y1", [F_R + (0.012,), (0.68, -0.08, 0.009)], (0, 1)),
        ("R-Y2", [F_R + (0.012,), (0.66, -0.50, 0.009)], (0, 1)),
        ("R-A", [KNOT_TOP + (0.030,), (0.15, 0.85, 0.027), (0.38, 0.72, 0.023),
                 (0.60, 0.58, 0.018), (0.72, 0.54, 0.013)], (0, 1)),
        ("R-B", [(0.19, 0.16, 0.019), (0.40, 0.25, 0.017), (0.60, 0.28, 0.014),
                 (0.66, 0.30, 0.011)], (0, 1)),
        ("R-C", [(0.22, -0.43, 0.026), (0.26, -0.40, 0.022), F_R + (0.016,)], (1, 0)),
        ("R-link1", [(0.00, 0.42, 0.016), (0.20, 0.58, 0.016), (0.38, 0.72, 0.016)], (0, 0)),
        ("R-link2", [(0.40, 0.25, 0.014), (0.39, 0.07, 0.014), (0.36, -0.11, 0.014)], (0, 0)),
        ("R-radial", [(-0.30, -0.62, 0.020), (-0.80, -0.42, 0.020)], (1, 1)),
    ],
}

# (branch, end of the branch that meets the trunk: 0 first or -1 last, trunk)
JOINS = {
    "L": [("L-Y1", 0, "L-main"), ("L-Y2", 0, "L-main"), ("L-thumbward", 0, "L-main"),
          ("L-B", 0, "L-main"), ("L-B2", 0, "L-B"),
          ("L-C", -1, "L-main"), ("L-D", -1, "L-thumbward"),
          ("L-link2", 0, "L-C"), ("L-link2", -1, "L-thumbward"),
          ("L-link3", 0, "L-main"), ("L-link3", -1, "L-B")],
    "R": [("R-arm2", 0, "R-knot"), ("R-diag", 0, "R-knot"),
          ("R-Y1", 0, "R-diag"), ("R-Y2", 0, "R-diag"), ("R-A", 0, "R-knot"),
          ("R-B", 0, "R-diag"), ("R-C", -1, "R-diag"),
          ("R-link1", 0, "R-diag"), ("R-link1", -1, "R-A"),
          ("R-link2", 0, "R-B"), ("R-link2", -1, "R-diag")],
}

# (name, path a, path b, s the rung meets both at, w): a 2-point path between the sampled
# points of a and b nearest that s
RUNGS = {"L": ("L-rung", "L-main", "L-ladderB", -1.3, 0.030),
         "R": ("R-rung", "R-knot", "R-radial", -0.7, 0.018)}

# where one path continues another inside one path (s_n of the join): r may step at most 15 %
CONTINUES = {"L": {"L-main": -1.00}, "R": {"R-knot": -0.22}}
