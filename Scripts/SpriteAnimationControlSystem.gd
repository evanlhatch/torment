extends RefCounted

class_name SpriteAnimationControlSystem

var _spriteAnims : Array[SpriteAnimationControl]

func RegisterSpriteAnim(spriteAnim:SpriteAnimationControl) -> void:
	_spriteAnims.append(spriteAnim)

func UnregisterSpriteAnim(spriteAnim:SpriteAnimationControl) -> void:
	_spriteAnims.erase(spriteAnim)

func updateSpriteAnimationControl(delta):
	for spriteAnim in _spriteAnims:
		spriteAnim._process_animation(delta)
		spriteAnim.update_flash()

		var targetVel : Vector2
		var facingVector : Vector2
		var spriteDirection : Vector2

		if spriteAnim.velocityProvider:
			targetVel = spriteAnim.velocityProvider.get_targetVelocity()
		if spriteAnim.facingProvider:
			facingVector = spriteAnim.facingProvider.get_facingDirection()

		if spriteAnim.animationState == spriteAnim.IdleAnimationName:
			if spriteAnim.DirectionSourceIdle == 0: spriteDirection = targetVel
			else: spriteDirection = facingVector
		elif spriteAnim.animationState == spriteAnim.WalkAnimationName:
			if spriteAnim.DirectionSourceMove == 0: spriteDirection = targetVel
			else: spriteDirection = facingVector
		else:
			spriteDirection = facingVector

		if spriteAnim.velocityProvider:
			var new_movement_state = spriteAnim.velocityProvider.get_velocity().length_squared() >= spriteAnim.WalkAnimationThreshold
			if spriteAnim.UpperBodyLowerBodySetup:
				var facingDir = DirectionsUtil.get_direction_from_vector(spriteAnim.facingProvider.get_facingDirection())
				var velocityDir = DirectionsUtil.get_direction_from_vector(targetVel)
				if (new_movement_state and
					DirectionsUtil.get_angle_between_directions(facingDir, velocityDir) > 90):
					spriteDirection *= -1
					spriteAnim.playsBackwards = true
				else:
					spriteAnim.playsBackwards = false
				spriteAnim.set_sprite_animation_state(
					spriteAnim.WalkAnimationName if new_movement_state else spriteAnim.IdleAnimationName, false)
				spriteAnim.movementState = new_movement_state
			elif new_movement_state != spriteAnim.movementState:
				spriteAnim.set_sprite_animation_state(
					spriteAnim.WalkAnimationName if new_movement_state else spriteAnim.IdleAnimationName, false)
				spriteAnim.movementState = new_movement_state

		spriteAnim.set_sprite_direction(spriteDirection)
