extends Node

@export var BaseAbilityWeaponIndex : int = 1010
@export var BulletModifier : PackedScene

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseNeedlesAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseNeedlesAbility == null:
		printerr("ab_PhantomNeedles_PhantomFetter couldn't find its base ability on the player!")
		return []
	for bestMod in baseNeedlesAbility.bestowed_modifiers:
		if bestMod.has_method("emit_with_passed_time"):
			# this is the emitter of the phantomneedles. we'll add our modifier to
			# the bullet prototype gameobject.
			var modifier = BulletModifier.instantiate()
			bestMod._bulletPrototype.add_child(modifier)
			return []

	printerr("ab_PhantomNeedles_PhantomFetter could not find the bestowed needle emitter!")
	return []
