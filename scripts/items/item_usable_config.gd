class_name ItemUsableConfig
extends Resource

## Runtime rules for tools and abilities held in the player's hotbar.
##
## Instant items and boons ignore this resource. Tools and abilities read these
## fields to decide charge consumption, cooldowns, and kill-based recharge.

enum RechargeMode {
	NONE,
	COOLDOWN,
	ON_KILL,
}

## When true each activation spends one charge and the slot empties at zero.
@export var is_consumed_on_use := true
## Maximum charges this slot can hold (also used when stacking duplicate pickups).
@export var max_charges := 1
@export var recharge_mode: RechargeMode = RechargeMode.NONE
## Seconds until charges refill after use when `recharge_mode` is COOLDOWN.
@export var recharge_cooldown_sec := 0.0
## Charges restored per enemy kill when `recharge_mode` is ON_KILL.
@export var recharge_per_kill := 1
