class_name WeaponDefinition
extends Resource

## Static gun archetype. Identity only — no flat damage (see WEAPON_SYSTEM_VAN_GUNNER.md).

enum Family { BASIC, SHOTGUN, MACHINEGUN, SNIPER }
enum Tier { BASE, A1 }
enum Element { NONE, FIRE, COLD, POISON }

@export var id: StringName = &""
@export var display_name := "Gun"
@export_multiline var description := ""
@export var family: Family = Family.BASIC
@export var tier: Tier = Tier.BASE
@export var element: Element = Element.NONE

@export_group("Identity (not damage)")
## Relative to GameBalance.BASE_FIRE_RATE.
@export var fire_rate_mult := 1.0
@export var pellets_per_shot := 1
@export var pellet_spread_degrees := 0.0
@export var bullet_speed := 100.0
@export var bullet_size := 0.045
@export var max_bounces := 1
@export var base_mag_size := 8
## Seconds to reload (duration). Exterior "Reload Speed %" reduces this.
@export var base_reload_seconds := 3.0
@export var drop_tickets := 1000


func to_damage_type() -> DamageType.Type:
	match element:
		Element.FIRE:
			return DamageType.Type.FIRE
		Element.COLD:
			return DamageType.Type.COLD
		Element.POISON:
			return DamageType.Type.POISON
		_:
			return DamageType.Type.NORMAL


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
