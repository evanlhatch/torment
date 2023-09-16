extends Node

@export var BaseAbilityWeaponIndex : int = 1008
@export var AllOtherTransfixionWeaponIndices : Array[int] = [1008, 1108, 1208]
@export var ProjectileScene : PackedScene

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var allAdditionalEmitters : Array[Node] = []
	var duplicatedEmitters : Array[Node] = []
	for weaponIndex in AllOtherTransfixionWeaponIndices:
		var otherTransfixionAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(weaponIndex)
		if otherTransfixionAbility == null:
			if weaponIndex == BaseAbilityWeaponIndex:
				printerr("ab_Transfixion upgrade was aquired without having the base ability!")
			continue

		for bestMod in otherTransfixionAbility.bestowed_modifiers:
			if bestMod.has_method("emit_with_passed_time"):
				if weaponIndex == BaseAbilityWeaponIndex:
					# this is the SimpleEmitter of the original Transfixion!
					# we duplicate it and give it a different projectile.
					var emitterDuplicate := bestMod.duplicate()
					emitterDuplicate.EmitScene = ProjectileScene
					modifiedTarget.add_child(emitterDuplicate)
					emitterDuplicate._emit_timer = bestMod._emit_timer
					emitterDuplicate._emit_overflow = bestMod._emit_overflow
					duplicatedEmitters.append(emitterDuplicate)
					allAdditionalEmitters.append(emitterDuplicate)
				else:
					allAdditionalEmitters.append(bestMod)

	# now we have to update the DirectionalOffset depending on how many additional emitters we have:
	if allAdditionalEmitters.size() == 1:
		allAdditionalEmitters[0].EmissionAngleOffsetToAimDirection = deg_to_rad(180)
	elif allAdditionalEmitters.size() == 2:
		allAdditionalEmitters[0].EmissionAngleOffsetToAimDirection = deg_to_rad(120)
		allAdditionalEmitters[1].EmissionAngleOffsetToAimDirection = deg_to_rad(240)
	else:
		printerr("ab_Transfixion upgrade encountered an unexpected number of addional emitters! Can't set the directions correctly...")

	return duplicatedEmitters
