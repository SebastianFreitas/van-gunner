"""Light smoothing of a sampled vein path (s, lat, r), so a frame step or a control-point kink never reads as a zigzag."""
from arms_veintrace_gates import _length


def smooth(pts: list, protected: set, passes: int = 3, cols: tuple = (0, 1)) -> None:
    """Binomial 1-2-1 blend of the chosen columns; the ends and the shared points stay put."""
    for _ in range(passes):
        new = [list(p) for p in pts]
        for i in range(1, len(pts) - 1):
            if pts[i][3] in protected:
                continue
            for j in cols:
                new[i][j] = 0.25 * pts[i - 1][j] + 0.5 * pts[i][j] + 0.25 * pts[i + 1][j]
        for p, q in zip(pts, new):
            p[:] = q


def _taper(pts: list, free: tuple) -> None:
    """Free ends fall to .6 of their r over the last 10 % of the path."""
    d = [0.0]
    for a, b in zip(pts, pts[1:]):
        d.append(d[-1] + _length(a, b))
    tot = d[-1]
    for i, p in enumerate(pts):
        if free[0]:
            p[2] *= 0.6 + 0.4 * min(1.0, d[i] / (0.1 * tot))
        if free[1]:
            p[2] *= 0.6 + 0.4 * min(1.0, (tot - d[i]) / (0.1 * tot))
