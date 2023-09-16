extends Node

@export var BaseAbilityWeaponIndex : int = 1015
@export var AllOtherRingBladeWeaponIndices : Array[int] = [1015, 1215]
@export var PiercingBladesScene : PackedScene

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var allRingBladeEmitters : Array[Node] = []
	var duplicatedEmitters : Array[Node] = []
	for weaponIndex in AllOtherRingBladeWeaponIndices:
		var otherRingbladeAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(weaponIndex)
		if otherRingbladeAbility == null:
			if weaponIndex == BaseAbilityWeaponIndex:
				printerr("ab_RingBlades upgrade was aquired without having the base ability!")
			continue
		
		for bestMod in otherRingbladeAbility.bestowed_modifiers:
			if bestMod.has_method("emit_with_passed_time"):
				allRingBladeEmitters.append(bestMod)
				if weaponIndex == BaseAbilityWeaponIndex:
					# this is one of the SimpleDirectionalEmitter of the original RingBlades!
					# we duplicate each of them, but give them a different blades scene.
					var emitterDuplicate := bestMod.duplicate()
					emitterDuplicate.EmitScene = PiercingBladesScene
					# use add_sibling, so that the duplicates are always intertwined with
					# the existing emitters
					bestMod.add_sibling(emitterDuplicate)
					duplicatedEmitters.append(emitterDuplicate)
					allRingBladeEmitters.append(emitterDuplicate)
	
	# now we have to update the timing of all emitters, so that they are evenly spaced.
	var nextEmitTimer : float = allRingBladeEmitters[0]._emit_timer
	var offsetPerTimer : float = allRingBladeEmitters[0].EmitEverySeconds / allRingBladeEmitters.size()
	for ringBladeEmitter in allRingBladeEmitters:
		ringBladeEmitter._emit_timer = nextEmitTimer
		nextEmitTimer += offsetPerTimer
	
	return duplicatedEmitters
