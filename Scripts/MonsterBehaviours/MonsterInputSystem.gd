extends RefCounted

class_name MonsterInputSystem

var _monsters : Array[MonsterInput]

func RegisterMonsterInput(monster : MonsterInput) -> void:
	_monsters.append(monster)

func UnregisterMonsterInput(monster : MonsterInput) -> void:
	_monsters.erase(monster)

func updateMonsterInput(delta):
	for i in range(_monsters.size(), 0, -1):
		var monster := _monsters[i - 1]
		if not is_instance_valid(monster):
			_monsters.remove_at(i)
			continue
		var newInputDir : Vector2 = Vector2.ZERO
		if monster._targetPosProvider != null and not monster._targetPosProvider.is_queued_for_deletion():
			var hasOverridePos : bool = monster._targetOverrideProvider != null and monster._targetOverrideProvider.has_override_target_position()
			var targetPos : Vector2
			if not hasOverridePos:
				targetPos = monster._targetPosProvider.get_worldPosition()
			else:
				targetPos = monster._targetOverrideProvider.get_override_target_position()
			var monsterPos : Vector2 = monster.get_gameobjectWorldPosition()

			if hasOverridePos or monster.MovePattern == 0:
				# linear movement
				newInputDir = targetPos - monsterPos
			elif monster.MovePattern == 1:
				# curved movement
				var target_vector : Vector2 = targetPos - monsterPos
				var curve_factor : float = clamp(
					inverse_lerp(8.0, monster.MovementCurvatureDistance, target_vector.length()),
					0.0, 1.0)
				newInputDir = target_vector.rotated(deg_to_rad(lerp(0.0, monster.MovementCurvatureAngle, curve_factor)))
			elif monster.MovePattern == 2:
				# offset movement
				newInputDir = targetPos - monsterPos + monster.targetOffset
			elif monster.MovePattern == 3:
				# lane movement
				var target_vector : Vector2 = targetPos - monsterPos
				var laneInputDir = monster.LaneDirection * signf(target_vector.dot(monster.LaneDirection))
				if monster.LaneDivergenceMaxRange > 0.0:
					var directionWeight = clampf(inverse_lerp(
						monster.LaneDivergenceMinRange,
						monster.LaneDivergenceMaxRange,
						target_vector.length()), 0.0, 1.0)
					newInputDir = target_vector.slerp(laneInputDir, directionWeight)
				else:
					newInputDir = laneInputDir

			if (newInputDir - monster.targetOffset).length() <= monster.StopWhenInRange:
				if monster.KillSelfWhenInStopRange:
					monster._gameObject.injectEmitSignal("Killed", [monster._gameObject])
					# we also destroy the gameobject!
					monster._gameObject.queue_free()
					continue
				else:
					monster.targetFacingSetter.set_facingDirection(newInputDir)
					newInputDir = Vector2.ZERO
			else:
				newInputDir = newInputDir.normalized()

			if monster.MaxLoiteringDuration > 0.0:
				if monster.loitering_counter == 0.0:
					monster.loitering_counter = randf_range(monster.MinLoiteringDuration, monster.MaxLoiteringDuration)
				elif monster.loitering_counter > 0.0:
					monster.loitering_counter = clamp(monster.loitering_counter - delta, 0.0, 9999.0)
					monster.targetFacingSetter.set_facingDirection(newInputDir)
					newInputDir = Vector2.ZERO
					if monster.loitering_counter == 0.0:
						monster.loitering_counter = -randf_range(monster.MinMotionDuration, monster.MaxMotionDuration)
				elif monster.loitering_counter < 0.0:
					monster.loitering_counter = clamp(monster.loitering_counter + delta, -9999.0, 0.0)

		if newInputDir != monster.input_direction:
			monster.input_direction = newInputDir
			monster.input_dir_changed.emit(monster.input_direction)
			monster.targetDirectionSetter.set_targetDirection(monster.input_direction)
