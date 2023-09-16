extends Node

@export var BaseAbilityWeaponIndex : int = 1009
@export var StreamOfFireUpgradeWeaponIndex : int = 1209
@export var OrthogonalPushScript : GDScript
@export var PushImpulse : float = 100
@export var BaseDamageMultiplier : float = 1.5

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_DragonsBreath_HeatBlast couldn't find its base ability on the player!")
		return []

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("emit_with_passed_time"):
			var streamOfFireAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(StreamOfFireUpgradeWeaponIndex)
			var hasStreamOfFire : bool = streamOfFireAbility.is_in_group("AcquiredAbilities")
			# this is the SimpleEmitter of the original DragonsBreath!
			var modifier = OrthogonalPushScript.new()
			modifier.set_name("HeatBlast_OrthogonalPusher")
			modifier.PushImpulse = PushImpulse
			modifier.TriggerOnHitSignal = false
			if hasStreamOfFire:
				modifier.UpdateDirectionConstantly = true
				modifier.RotatePushDirection = 0
			modifier.RotatePushDirection = deg_to_rad(20)
			bestMod._bulletPrototype.add_child(modifier)
			modifier.set_push_active(true)
			var applyDamageOnHit = bestMod._bulletPrototype.getChildNodeWithProperty("DamageAmount")
			applyDamageOnHit.DamageAmount *= BaseDamageMultiplier
			return [modifier]

	return []
