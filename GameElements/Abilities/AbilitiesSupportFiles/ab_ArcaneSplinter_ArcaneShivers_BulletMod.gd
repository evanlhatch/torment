extends GameObjectComponent

@export var SplitStartSpeedMultiplier : float = 0.5

var _emitCountModifier : Modifier
var _fastRaybasedMover : Node2D

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	_fastRaybasedMover = _gameObject.getChildNodeWithProperty("_currentSpeed")

func _process(delta: float) -> void:
	if _fastRaybasedMover._currentSpeed <= _fastRaybasedMover._currentAcceleration:
		# prepare for cloning!
		# detach ourself, since wo don't want to split again!
		get_parent().remove_child(self)
		
		_fastRaybasedMover.scale = Vector2.ONE * 0.75
		
		_fastRaybasedMover._currentSpeed = _fastRaybasedMover._randomizedSpeed * SplitStartSpeedMultiplier
		_fastRaybasedMover.set_targetDirection(Vector2.UP.rotated(randf_range(0, 2.0* PI)))
		# alternatively: rotate by 45 degrees, so that the direction doesn't change so abruptly:
		#_fastRaybasedMover.set_targetDirection(_fastRaybasedMover._currentDirection.rotated(PI/4))

		var secondSplinter: GameObject = Global.duplicate_gameObject_node(_gameObject)
		secondSplinter.setInheritModifierFrom(_gameObject.getInheritModifierFrom())
		secondSplinter.set_sourceGameObject(_gameObject.get_rootSourceGameObject())
		Global.attach_toWorld(secondSplinter, false)
		var secondSplinter_raybasedMover : Node = secondSplinter.getChildNodeWithMethod("set_targetDirection")
		secondSplinter_raybasedMover.set_targetDirection(Vector2.UP.rotated(randf_range(0, 2.0* PI)))
		# alternatively: rotate by 45 degrees, so that the direction doesn't change so abruptly:
		#secondSplinter_raybasedMover.set_targetDirection(_fastRaybasedMover._currentDirection.rotated(-PI/2))
		secondSplinter_raybasedMover._currentSpeed *= SplitStartSpeedMultiplier

		# we need to copy some variables, as well! this is, of course, highly implementation dependent,
		# but we should know which mover is used and that a bullet script is there, at this point.
		var originalSplinter_bullet: Node    = _gameObject.getChildNodeWithProperty("_numberOfHits")
		var secondSplinter_bulletNode : Node = secondSplinter.getChildNodeWithProperty("_numberOfHits")
		secondSplinter_bulletNode._numberOfHits = originalSplinter_bullet._numberOfHits
		secondSplinter_bulletNode._remainingLifeTime = originalSplinter_bullet._remainingLifeTime

		var originalSplinter_applyDamageOnHit: Node    = _gameObject.getChildNodeWithProperty("_activeTime")
		var secondSplinter_applyDamageOnHitNode : Node = secondSplinter.getChildNodeWithProperty("_activeTime")
		secondSplinter_applyDamageOnHitNode._activeTime = originalSplinter_applyDamageOnHit._activeTime

		secondSplinter_raybasedMover._currentAcceleration = _fastRaybasedMover._currentAcceleration
		secondSplinter_raybasedMover._velocity_offset = _fastRaybasedMover._velocity_offset
		secondSplinter_raybasedMover._allTimeHitObjects = _fastRaybasedMover._allTimeHitObjects
		queue_free()
