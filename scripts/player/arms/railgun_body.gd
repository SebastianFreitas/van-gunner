class_name RailgunBody
extends RefCounted
## Held gun body: a long lower barrel, a short fat upper barrel with an open gap between them, and a boxy receiver with a stock behind them, the charge window on the stock.


## Builds barrels + receiver under `body` (the gun's "Body" node, gun space, -Z forward, +Y up).
## `p` is the palm length, `z_front` the trigger guard's front z, `y_axis` = trigger_y + 0.25 p
## (the guard's top). Returns the muzzle point in gun space.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, z_front: float,
		y_axis: float) -> Vector3:
	# Geometry never depends on rng: the aim must not depend on the seed.
	var ya := y_axis
	var muzzle := RailgunBarrels.build(body, p, rng, z_front, ya)
	RailgunReceiver.build(body, p, rng, z_front, ya)
	RailgunPivots.build(body, p, rng, ya)
	RailgunCoils.build(body, p, rng, muzzle.y, z_front - 1.9 * p, 1.28)
	# Sockets snap before the wear exists, so its thin parts never move them.
	GunSockets.place(body, p, z_front, ya)
	RailgunJunk.build(body, p, rng, z_front, ya)
	body.add_child(RailGlow.new())
	body.add_child(GunAttachments.new())
	return muzzle

