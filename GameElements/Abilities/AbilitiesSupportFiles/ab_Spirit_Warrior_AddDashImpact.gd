extends Node

@export var BaseAbilityWeaponIndex : int = 1021
@export var ChangeSummonScene : PackedScene

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_Spirit_Warrior_DashImpact couldn't find its base ability on the player!")
		return []

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("set_maxActiveSummons") and bestMod._weapon_index == BaseAbilityWeaponIndex:
			bestMod.SummonScenes[0] = ChangeSummonScene
			break
	return []
