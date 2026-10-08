extends RefCounted
## Places and sizes a side window's IronCross on the street face (outer skin) of the wall.

## Lift off the skin so the bars clear its roll at the window's top edge.
const SKIN_LIFT := 0.012
## How far the bar ends' frame half-size exceeds the window hole.
const PAST_EDGE := 0.01
## How much smaller the straight (clear) part is than the ends' frame.
const CLEAR_INSET := Vector2(0.077, 0.045)
## Depth of the bars' outermost part past their origin: back offset, pipe sleeve diameter and
## 1 cm for the hose clamps.
const DEPTH_M := IronCross.BAR_BACK_Z + 2.0 * IronCross.PIPE_RADIUS + 0.01
## Outermost point of the bars off the liner.
const OUTER_M := VanBodyProfile.WALL_THICKNESS + SKIN_LIFT + DEPTH_M


## Moves `bars` onto the street face at the window's curve and sizes it from the hole.
## `glass_bump` and `iron_inset` are the window's own glass nudge and bar origin offset.
static func place(
	bars: IronCross, walls: VanSideWall, wall_sign: float, x_ref: float, y_hinge: float,
	mid_y: float, glass_bump: float, iron_inset: float
) -> void:
	if bars == null:
		return
	var into_cabin := iron_inset - glass_bump - VanBodyProfile.WALL_THICKNESS - SKIN_LIFT
	var local_x := walls.local_x_on_wall(wall_sign, mid_y, x_ref) - wall_sign * into_cabin
	bars.transform = Transform3D(bars.transform.basis, Vector3(local_x, mid_y - y_hinge, 0.0))
	# Sized from the hole so the hooked ends reach past every edge of the cut.
	bars.frame_half = Vector2(
		VanOpenings.SIDE_WINDOW_HALF_Z + PAST_EDGE, VanOpenings.SIDE_WINDOW_HALF_Y + PAST_EDGE)
	bars.clear_half = bars.frame_half - CLEAR_INSET
	bars.set_street_lit(true)
	bars.follow_side_wall_curve(walls, mid_y)
