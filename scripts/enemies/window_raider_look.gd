extends RefCounted
## Fits the window crawler's sprite, hitboxes and health bar to its lower canvas.
##
## The raider scene's defaults are the fat door beast: an 80 x 72 art-pixel canvas
## with its feet on the van floor and a cylinder body plus a head sphere to match.
## The crawler is an 80 x 48 canvas drawn head-left, so it stays centred on the
## node (at a window the node sits in the opening) and is shifted by a Sprite3D
## offset, which follows the billboard where a node offset would not, so its head
## is over the origin. Both PNGs come from tools/gen_enemy_sprites.py.

## The crawler's head is drawn 16 art pixels left of the canvas centre.
const CRAWLER_HEAD_SHIFT_PX := 16.0
const CRAWLER_BODY_RADIUS := 0.75
const CRAWLER_BODY_HEIGHT := 0.65
const CRAWLER_HEAD_RADIUS := 0.36
## Just above the crawler's 1.15 m canvas.
const CRAWLER_BAR_HEIGHT := 0.9


static func fit_crawler(raider: WindowRaider) -> void:
	raider.sprite.position = Vector3.ZERO
	raider.sprite.offset = Vector2(CRAWLER_HEAD_SHIFT_PX, 0.0)
	# agile_raider.png is a single 80 x 48 frame; the scene's hframes 13 is the loper's sheet.
	raider.sprite.hframes = 1
	var body := CylinderShape3D.new()
	body.radius = CRAWLER_BODY_RADIUS
	body.height = CRAWLER_BODY_HEIGHT
	var body_shape: CollisionShape3D = raider.hitbox.get_node("CollisionShape3D")
	body_shape.shape = body
	body_shape.position = Vector3(0.0, -0.05, 0.0)
	var head := SphereShape3D.new()
	head.radius = CRAWLER_HEAD_RADIUS
	var head_shape: CollisionShape3D = raider.get_node("HeadHitbox/CollisionShape3D")
	head_shape.shape = head
	head_shape.position = Vector3(0.0, -0.05, 0.0)
	raider.health_bar.position.y = CRAWLER_BAR_HEIGHT
