extends RefCounted

class_name FastRaybasedMoverSystem

var _movers : Array[FastRaybasedMover]


func RegisterFastRaybasedMover(mover : FastRaybasedMover) -> void:
	_movers.append(mover)

func UnregisterFastRaybasedMover(mover : FastRaybasedMover) -> void:
	_movers.erase(mover)

func updateRayMover(delta):
	for mover in _movers:
		if mover._gameObject == null:
			continue
		
		# --------- inlined from FastRaybasedMover.gd func calculateMotion(delta)!
		# when changes are done to either the original function or here, they have
		# to be transferred over!
		if mover._currentAcceleration > 0:
			mover._currentSpeed += mover._currentAcceleration * delta
		if mover._currentAcceleration < 0:
			var speedBeforePositive := mover._currentSpeed > 0
			mover._currentSpeed += mover._currentAcceleration * delta
			if speedBeforePositive && mover._currentSpeed <= 0:
				mover._emitStopped = true
		if mover._currentSpeed > 0 && mover._randomizedDamping > 0:
			mover._currentSpeed -= mover._currentSpeed * mover._randomizedDamping * delta
			if mover._currentSpeed < 1:
				mover._currentSpeed = 0
				mover._emitStopped = true

		var motion : Vector2 = Vector2.ZERO	
		if mover._currentSpeed != 0:
			motion = (mover._currentDirection + mover._velocity_offset) * mover._currentSpeed * delta
		# -------------------------------
			
		if mover._clearLastHitObjects:
			mover._lastHitObjects.clear()
			mover._clearLastHitObjects = false
		mover._tempHits.clear()

		# bullet.gd uses the Node2Ds scale, so we just apply it to the radius like this:
		var scaledRadius : float = mover.Radius * max(mover.global_scale.x, mover.global_scale.y)
		for pool in mover.HitLocatorPools:
			mover._tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle_motion(pool, mover.global_position, scaledRadius, motion))
		for hitGameObj in mover._tempHits:
			if not mover.allowMultipleHits && hitGameObj in mover._allTimeHitObjects:
				continue
			if hitGameObj in mover._lastHitObjects:
				continue
			mover._lastHitObjects.append(hitGameObj)
		mover.global_position += motion

		for node in mover._lastHitObjects:
			if node == null || node.is_queued_for_deletion():
				continue # do not trigger signals for deleted nodes!
			if not node in mover._currentHitObjects:
				if not node in mover._allTimeHitObjects:
					mover._allTimeHitObjects.append(node)
				mover._currentHitObjects.append(node)
				mover.emit_signal("CollisionStarted", node)
			# else would be CollisionStay...
		for i in range(mover._currentHitObjects.size() - 1, -1, -1):
			var node : GameObject = mover._currentHitObjects[i]
			if node == null || node.is_queued_for_deletion():
				mover._currentHitObjects.remove_at(i)
				continue # do not trigger signals for deleted nodes!
			if not node in mover._lastHitObjects:
				mover.emit_signal("CollisionEnded", node)
				mover._currentHitObjects.remove_at(i)
		mover._clearLastHitObjects = true
		if mover._emitStopped:
			mover.emit_signal("MovementStopped")
			mover._emitStopped = false
