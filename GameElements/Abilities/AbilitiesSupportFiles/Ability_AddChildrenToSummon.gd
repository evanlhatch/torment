extends Node

@export var BaseAbilityWeaponIndex : int = 1017
@export var SummonerIdentifyingMethodName : String = "summonWasKilled"

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("%s couldn't find its base ability on the player!" % get_parent().name)
		return []
	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method(SummonerIdentifyingMethodName):
			# this is the summoner. we have to add dupes of our children to the currently
			# active summons and also react to new summons being spawned!
			for summonSlot in bestMod._summonSlots:
				if summonSlot.summonGameObject == null || summonSlot.summonGameObject.is_queued_for_deletion():
					continue
				DuplicateChildrenToSummon(summonSlot.summonGameObject)
			bestMod.SummonWasSummoned.connect(DuplicateChildrenToSummon)
			return []

	printerr("%s could not find the bestowed summoner!" % get_parent().name)
	return []

func DuplicateChildrenToSummon(summon:GameObject) -> void:
	for child in get_children():
		var dupe = child.duplicate()
		summon.add_child(dupe)
