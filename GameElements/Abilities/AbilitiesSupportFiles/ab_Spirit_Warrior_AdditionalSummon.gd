extends Node

@export var BaseAbilityWeaponIndex : int = 1021

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_Spirit_Warrior_AdditionalSummon couldn't find its base ability on the player!")
		return []

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("set_maxActiveSummons") and bestMod._weapon_index == BaseAbilityWeaponIndex:
			bestMod.set_maxActiveSummons(bestMod.MaxActiveSummons + 1)
			break
	return []
