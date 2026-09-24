class_name BoonBehaviorContext
extends RefCounted

## Shared payload passed to boon behavior handlers during combat events.

var traits: BoonTraits
var tree: SceneTree
var damage_info: DamageInfo
var target: Node
var status: StatusEffectController
var projectile: Projectile
var bounce_count := 0
var explosion_center := Vector3.ZERO
var explosion_radius := 0.0
var space_state: PhysicsDirectSpaceState3D
var exclude: Array[RID] = []
var velocity: Vector3 = Vector3.ZERO
var enemy: Node
var loot_container: Node
var fire_origin := Vector3.ZERO
var fire_direction := Vector3.FORWARD
var gun_stats: GunStats
var projectile_shooter: CollisionObject3D
var inherited_velocity := Vector3.ZERO
