class_name ClassDefinition
extends Resource

## One player class: a single gun with its base stats. Identity only — damage
## starts from GameBalance.BASE_DAMAGE_PER_SHOT * damage_mult and boons scale it.

## Same members in the same order as the old WeaponDefinition.Family so
## ArmCannonMesh keeps building its four meshes.
enum Family { BASIC, SHOTGUN, MACHINEGUN, SNIPER }

@export var id: StringName = &""
@export var display_name := "Basic"
@export_multiline var description := ""
@export var family: Family = Family.BASIC

@export_group("Gun")
## Relative to GameBalance.BASE_DAMAGE_PER_SHOT. Pellets split the result.
@export var damage_mult := 1.0
## Relative to GameBalance.BASE_FIRE_RATE.
@export var fire_rate_mult := 1.0
@export var pellets_per_shot := 1
@export var pellet_spread_degrees := 0.0
@export var bullet_speed := 100.0
@export var bullet_size := 0.045
@export var max_bounces := 1
@export var base_mag_size := 8
## Seconds to reload (duration). "Reload Speed %" divides this.
@export var base_reload_seconds := 3.0


## Two-letter HUD tag next to the ammo count.
func family_code() -> String:
	match family:
		Family.SHOTGUN:
			return "SG"
		Family.MACHINEGUN:
			return "MG"
		Family.SNIPER:
			return "SN"
		_:
			return "BA"
