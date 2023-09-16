extends Node

@export var BaseAbilityWeaponIndex : int = 1017
@export var EmitterIdentifyingMethodName : String = "emit_with_passed_time"

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("%s couldn't find its base ability on the player!" % get_parent().name)
		return []
	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method(EmitterIdentifyingMethodName):
			# this is the emitter. we'll add a duplicate of our children
			for child in get_children():
				var dupe = child.duplicate()
				bestMod._bulletPrototype.add_child(dupe)
	return []
