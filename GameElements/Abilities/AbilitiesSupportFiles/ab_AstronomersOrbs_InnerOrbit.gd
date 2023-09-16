extends Node

@export var BaseAbilityWeaponIndex : int = 1001
@export var OrbitSizeMultiplier: float = 0.6
@export var OrbitSpeedMultiplier: float = -1
@export var BaseOrbitSizeMultiplier: float = 1.1

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseOrbsAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseOrbsAbility == null:
		printerr("ab_AstronomersOrbs_InnerOrbit could not find base Astronomers Ability!")
		return []
	for bestMod in baseOrbsAbility.bestowed_modifiers:
		if bestMod.has_method("update_sphere_configuration"):
			# this is the original orbs node! let's duplicate it:
			var orbsDuplicate = bestMod.duplicate()
			# the children (spheres) are duplicated as well, but the
			# new orbs will create their own, when they are attached, so:
			for c in orbsDuplicate.get_children():
				c.queue_free()
			# and set a few parameters:
			orbsDuplicate.BaseOrbitSize *= OrbitSizeMultiplier
			orbsDuplicate.BaseOrbitSpeed *= OrbitSpeedMultiplier
			# the original orbs need their orbit to be pushed outwards:
			bestMod._modifiedOrbitSize.init(bestMod.BaseOrbitSize * BaseOrbitSizeMultiplier, "Range", bestMod._gameObject, Callable())
			
			modifiedTarget.add_child(orbsDuplicate)
			return [orbsDuplicate]
			
	printerr("ab_AstronomersOrbs_InnerOrbit could not find the bestowed base Astronomers Orbs!")
	return []

