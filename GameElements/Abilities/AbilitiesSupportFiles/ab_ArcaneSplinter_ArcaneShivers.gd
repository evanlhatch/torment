extends Node

@export var BaseAbilityWeaponIndex : int = 1016
@export var BulletModifierScript : GDScript
@export var EmitCountMultiplier : float = -0.5
@export var SplitStartSpeedMultiplier : float = 0.5

var _splinterEmitModifier : Modifier

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_ArcaneSplinter_ArcaneShivers couldn't find its base ability on the player!")
		return []
	_splinterEmitModifier = Modifier.create("EmitCount", modifiedTarget)
	_splinterEmitModifier.allowCategories(["ArcaneSplinter"])
	_splinterEmitModifier.setMultiplierMod(EmitCountMultiplier)
	modifiedTarget.triggerModifierUpdated("EmitCount")

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("emit_fan"):
			# this is one of the SimpleDirectionalEmitter of the original ArcaneSplinter!
			var modifier = BulletModifierScript.new()
			modifier.SplitStartSpeedMultiplier = SplitStartSpeedMultiplier
			bestMod._bulletPrototype.add_child(modifier)

	return []
