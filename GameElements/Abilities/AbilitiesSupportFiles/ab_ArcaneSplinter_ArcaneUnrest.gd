extends Node

@export var BaseAbilityWeaponIndex : int = 1016
@export var AccelerationFromSpeedFactor : float = 0.3
@export var BaseDamageAdd : int = 10
@export var DamageReductionMultiplier : float = 0.5

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseSplinterAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseSplinterAbility == null:
		printerr("ab_ArcaneSplinter_ArcaneUnrest could not find base ArcaneSplinter Ability!")
		return []
	for bestMod in baseSplinterAbility.bestowed_modifiers:
		if bestMod.has_method("emit_fan"):
			# this is one of the SimpleDirectionalEmitter of the original ArcaneSplinter!
			# we directly modify the base values that we need to modify (no Modifier. keep it simple.)
			var fastRaybasedMover = bestMod._bulletPrototype.getChildNodeWithMethod("calculateMotion")
			var applyDamageOnHit = bestMod._bulletPrototype.getChildNodeWithProperty("DamageAmount")
			if fastRaybasedMover == null or applyDamageOnHit == null:
				printerr("ab_ArcaneSplinter_ArcaneUnrest couldn't find the needed components on the bullet it was applied to!")
				return []
			fastRaybasedMover.acceleration = fastRaybasedMover.movementSpeed * AccelerationFromSpeedFactor
			applyDamageOnHit.DamageAmount += BaseDamageAdd
			applyDamageOnHit.DamageChangePerSec *= DamageReductionMultiplier
	
	return []
