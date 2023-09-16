extends RefCounted

class_name TwoDMoverSystem

var _2dMovers : Array[TwoDMover]

func Register2DMover(mover : TwoDMover) -> void:
	_2dMovers.append(mover)

func Unregister2DMover(mover : TwoDMover) -> void:
	_2dMovers.erase(mover)

func update2DMover(delta):
	for mover in _2dMovers:
		for collStarted in mover._collisionsStarted:
			if collStarted != null && !collStarted.is_queued_for_deletion():
				mover.emit_signal("CollisionStarted", collStarted)
		for collEnded in mover._collisionsEnded:
			if collEnded != null && !collEnded.is_queued_for_deletion():
				mover.emit_signal("CollisionEnded", collEnded)
		mover._collisionsStarted.clear()
		mover._collisionsEnded.clear()

		if mover._pushedCounter > 0:
			mover._pushedCounter -= delta
			continue
		var velocityDiff : Vector2 = mover._targetVelocity - mover.linear_velocity
		var velocityDiffLen :float = velocityDiff.length()
		if velocityDiffLen > 0.1:
			#apply_force(velocityDiff / velocityDiffLen * movementForce)
			mover.apply_impulse(velocityDiff / velocityDiffLen * mover.movementForce * delta)
