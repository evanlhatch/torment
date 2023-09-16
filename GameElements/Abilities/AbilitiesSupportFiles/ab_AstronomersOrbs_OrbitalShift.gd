extends Node

@export var BaseAbilityWeaponIndex : int = 1001
@export var OrbitEccentricity : float = 100

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	# this will only change the eccentricity of the original
	# astronomers orbs ability!
	# when it should change all: go through all modifierTarget.getChildrenWithMethod("update_sphere_configuration")
	# instead. BUT: when the Inner Orbit upgrade is acquired afterwards, it won't get the eccentricity,
	# so that has to be handled with some kind of signal (probably child added on modifiedTarget)
	
	var baseOrbsAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseOrbsAbility == null:
		printerr("ab_AstronomersOrbs_OrbitalShift could not find base Astronomers Ability!")
		return []
	for bestMod in baseOrbsAbility.bestowed_modifiers:
		if bestMod.has_method("update_sphere_configuration"):
			# this is the original orbs node!
			bestMod._orbitEccentricity = OrbitEccentricity
			return []

	printerr("ab_AstronomersOrbs_InnerOrbit could not find the bestowed base Astronomers Orbs!")
	return []
