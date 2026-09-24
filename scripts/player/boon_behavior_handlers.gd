## Concrete boon behavior handlers. Each inner class maps one trait to combat logic.
extends RefCounted


class RicochetStackBehavior extends BoonBehavior:
	func trait_key() -> StringName:
		return BoonTraitKeys.RICOCHET_STACK_POWER

	func on_ricochet(ctx: BoonBehaviorContext) -> void:
		if ctx.damage_info:
			ctx.damage_info.scale_channels(1.0 + float(ctx.bounce_count) * 0.15)
