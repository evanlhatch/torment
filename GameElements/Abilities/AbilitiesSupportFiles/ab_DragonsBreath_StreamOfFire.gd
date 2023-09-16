extends Node

@export var BaseAbilityWeaponIndex : int = 1009
@export var StreamOfFireMoverScene : PackedScene

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	var baseAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseAbility == null:
		printerr("ab_DragonsBreath_StreamOfFire couldn't find its base ability on the player!")
		return []

	for bestMod in baseAbility.bestowed_modifiers:
		if bestMod.has_method("emit_with_passed_time"):
			# this is the SimpleEmitter of the original DragonsBreath!
			# we have to exchange the WallMover on the bullet prototype for our AttachedMover
			var moverReplaced : bool = false
			for i in range(bestMod._bulletPrototype.get_child_count(), 0, -1):
				var bulletChild : Node = bestMod._bulletPrototype.get_child(i-1)
				if bulletChild.has_method("calculateMotion"):
					# this is the WallMover, let's replace it with our own
					bulletChild.queue_free()
					var streamOfFireMover : Node = StreamOfFireMoverScene.instantiate()
					bestMod._bulletPrototype.add_child(streamOfFireMover)
					streamOfFireMover.attachToGameObject(modifiedTarget, streamOfFireMover.OffsetPosition, streamOfFireMover.OffsetDirection)
					moverReplaced = true
				elif bulletChild.has_method("set_orthoPushDirection"):
					# this is the orthogonalpush. it has to be updated constantly now.
					bulletChild.UpdateDirectionConstantly = true
					bulletChild.RotatePushDirection = 0
			if not moverReplaced:
				printerr("ab_DragonsBreath_StreamOfFire could not find the right components on the original DragonsBreath!")
	return []
