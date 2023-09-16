extends Node

@export var BaseAbilityWeaponIndex : int = 1004
@export var MultiplyBaseDamage : float = 0.4
@export var DamageCategory : String
@export var ApplyEffectScenes : Array[PackedScene]
@export_enum("DontApplyEffects", "EvenlyDistributeStacks", "UseApplyEffectChance") var EffectApplicationType : int
@export var ApplyNumberOfEffectStacks : int = 0
@export var NumberOfStacksModifiedBy : String
@export var ApplyEffectChance : float = 0

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_RadiantAura upgrade could not find the base ability!")
		return []

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("emit"):
			# this is the RadiantAura base emitter node
			var emitterDuplicate := bestMod.duplicate()
			emitterDuplicate.BaseDamage *= MultiplyBaseDamage
			emitterDuplicate.DamageCategories.clear()
			emitterDuplicate.DamageCategories.append(DamageCategory)
			emitterDuplicate.ApplyEffectScenes = ApplyEffectScenes
			emitterDuplicate.EffectApplicationType = EffectApplicationType
			emitterDuplicate.ApplyNumberOfEffectStacks = ApplyNumberOfEffectStacks
			emitterDuplicate.NumberOfStacksModifiedBy = NumberOfStacksModifiedBy
			emitterDuplicate.ApplyEffectChance = ApplyEffectChance

			bestMod.add_sibling(emitterDuplicate)
			emitterDuplicate._timeSinceLastEmit = bestMod._timeSinceLastEmit
			# safeguard: when choosing the upgrade while an emit is in progress
			# this would be messed up
			emitterDuplicate._col1 = bestMod._col1
			emitterDuplicate.rays1.material.set_shader_parameter("modulate_color", bestMod._col1)
			emitterDuplicate._col2 = bestMod._col2
			emitterDuplicate.rays2.material.set_shader_parameter("modulate_color", bestMod._col2)
			return [emitterDuplicate]

	printerr("ab_RadiantAura upgrade was aquired without having the base ability!")
	return []
