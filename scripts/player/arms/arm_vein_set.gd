class_name ArmVeinSet
extends Resource
## One arm's hand-placed veins: centrelines on the skin chart with a radius per point.

## Chart radius: the around-the-arm angle becomes arc length at about the forearm's radius.
const ARC_R := 0.035
## Radius that maps to height 1.0 (the fattest vein spot).
const MAX_R := 0.006
## Length over which a free end dives under the skin (height to zero, width narrowing).
const FADE_LEN := 0.012
const FREE_START := 1
const FREE_END := 2

## Each path is a point list (x, v, radius) on the chart, wrist to forearm or knuckle to wrist.
@export var paths: Array[PackedVector3Array] = []
## Per path: FREE_START and FREE_END bits for ends that dive under the skin. A cleared end
## joins another vein (smooth Y) or waits for a finger vein (the knuckle stubs).
@export var free_ends: PackedInt32Array = PackedInt32Array()


## Chart point of a CUSTOM0 position (xyz): x along the arm, v = ARC_R * atan2(z, y).
## The back of the hand is +v on the right arm and -v on the left; the palm side is the reverse.
static func chart_of(custom: Vector3) -> Vector2:
	return Vector2(custom.x, ARC_R * atan2(custom.z, custom.y))


## Flat array for the sampler and a shader uniform: (x, v, radius, height scale) per point, the
## ends already eased (extra points inside each free end), paths separated by one
## (0, 0, -1, 0) point. Roughly 110 points per arm.
func pack() -> PackedVector4Array:
	var out := PackedVector4Array()
	for i in paths.size():
		var pts := paths[i]
		if pts.size() < 2:
			continue
		var flags := free_ends[i] if i < free_ends.size() else 0
		var cum := PackedFloat32Array([0.0])
		for k in range(1, pts.size()):
			cum.append(cum[k - 1] + Vector2(pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y).length())
		var total := cum[cum.size() - 1]
		var stops: Array[float] = []
		for c in cum:
			stops.append(c)
		if total > FADE_LEN * 3.0:
			for f in [0.34, 0.67]:
				if flags & FREE_START:
					stops.append(FADE_LEN * f)
				if flags & FREE_END:
					stops.append(total - FADE_LEN * f)
		stops.sort()
		for s in stops:
			var p := _at(pts, cum, s)
			var hf := 1.0
			if flags & FREE_START:
				hf = minf(hf, smoothstep(0.0, FADE_LEN, s))
			if flags & FREE_END:
				hf = minf(hf, smoothstep(0.0, FADE_LEN, total - s))
			out.append(Vector4(p.x, p.y, p.z * (0.4 + 0.6 * hf), hf))
		out.append(Vector4(0.0, 0.0, -1.0, 0.0))
	return out


## Point (x, v, radius) at arc length `s` along a path.
func _at(pts: PackedVector3Array, cum: PackedFloat32Array, s: float) -> Vector3:
	for k in range(1, pts.size()):
		if s <= cum[k] or k == pts.size() - 1:
			var span := maxf(cum[k] - cum[k - 1], 0.00001)
			return pts[k - 1].lerp(pts[k], clampf((s - cum[k - 1]) / span, 0.0, 1.0))
	return pts[0]
