extends GameObjectComponent2D

@export var AttachToObject : GameObject
@export var OffsetPosition : Vector2
@export_enum("GlobalRelativePosition", "LocalPositionRotated") var OffsetPositionBehaviour : int
@export var GlobalOffset : Vector2
@export var PositionDamping : float
@export var OffsetDirection : Vector2
@export_enum("GlobalDirection", "LocalFromFacingDirection") var OffsetDirectionBehaviour : int
@export var UpdateTransformRotationFromDirection : bool
@export var DirectionDamping : float
@export var DestroyWithAttachedObject : bool

var _targetDirection : Vector2
@export var _attachedTargetDirectionProvider : Node
@export var _attachedGlobalPositionProvider : Node

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	if _attachedGlobalPositionProvider != null:
		updateGlobalPosition(false)
		updateGlobalDirection(false)
	elif AttachToObject != null:
		attachToGameObject(AttachToObject, OffsetPosition, OffsetDirection)

	if AttachToObject == null:
		process_mode = PROCESS_MODE_DISABLED

func attachToGameObject(toObject:GameObject, offsetPosition:Vector2, offsetDirection:Vector2):
	AttachToObject = toObject
	OffsetPosition = offsetPosition
	OffsetDirection = offsetDirection
	if AttachToObject == null:
		_attachedGlobalPositionProvider = null
		_attachedTargetDirectionProvider = null
		return

	process_mode = PROCESS_MODE_INHERIT

	_attachedGlobalPositionProvider = AttachToObject.getChildNodeWithMethod("get_worldPosition")
	if _attachedGlobalPositionProvider == null:
		printerr("AttachedMover can't attach to %s: it has no position provider!" % AttachToObject.name)
		return
	_attachedTargetDirectionProvider = AttachToObject.getChildNodeWithMethod("get_facingDirection")
	updateGlobalPosition(false)
	updateGlobalDirection(false)

func updateGlobalPosition(respectDamping:bool, delta:float=1.0/60.0):
	var targetGlobalPosition : Vector2
	if OffsetPositionBehaviour == 0 or _attachedTargetDirectionProvider == null: # GlobalRelativePosition
		targetGlobalPosition = GlobalOffset + _attachedGlobalPositionProvider.get_worldPosition() + OffsetPosition
	else: # LocalPositionRotated
		var rotationFromDirection : float = _attachedTargetDirectionProvider.get_facingDirection().angle()
		targetGlobalPosition = GlobalOffset + _attachedGlobalPositionProvider.get_worldPosition() + OffsetPosition.rotated(rotationFromDirection)

	if respectDamping and PositionDamping > 0:
		global_position = lerp(global_position, targetGlobalPosition, delta * PositionDamping)
	else:
		global_position = targetGlobalPosition

func updateGlobalDirection(respectDamping:bool, delta:float=1.0/60.0):
	var newTargetDirection : Vector2
	if OffsetDirectionBehaviour == 0: # GlobalDirection
		newTargetDirection = OffsetDirection
	else: # LocalFromFacingDirection
		var rotationFromDirection : float = _attachedTargetDirectionProvider.get_facingDirection().angle()
		newTargetDirection = OffsetDirection.rotated(rotationFromDirection)

	if respectDamping and DirectionDamping > 0:
		_targetDirection = _targetDirection.slerp(newTargetDirection, delta * DirectionDamping)
	else:
		_targetDirection = newTargetDirection
	if UpdateTransformRotationFromDirection:
		set_rotation(_targetDirection.angle())

func get_targetDirection() -> Vector2:
	return _targetDirection

func get_targetVelocity() -> Vector2:
	# no own velocity behaviour, for now
	return Vector2.ZERO

func get_velocity() -> Vector2:
	# no own velocity behaviour, for now
	return Vector2.ZERO

func set_targetDirection(targetDirection:Vector2):
	if OffsetDirectionBehaviour == 0: # GlobalDirection
		OffsetDirection = targetDirection
	else: # LocalFromFacingDirection
		if _attachedTargetDirectionProvider != null:
			var rotationFromDirection : float = _attachedTargetDirectionProvider.get_facingDirection().angle()
			OffsetDirection = targetDirection.rotated(-rotationFromDirection)
	updateGlobalDirection(false)


func get_worldPosition() ->  Vector2:
	return global_position

func set_worldPosition(new_position : Vector2):
	# we have our own offsets, updating our position should be left to ourselves alone.
	pass
#	if OffsetPositionBehaviour == 0: # GlobalPosition
#		if _attachedGlobalPositionProvider != null and not _attachedGlobalPositionProvider.is_queued_for_deletion():
#			OffsetPosition = new_position - _attachedGlobalPositionProvider.get_worldPosition()
#		else:
#			OffsetPosition = new_position
#	else: # LocalPositionRotated
#		var rotationFromDirection : float = _attachedTargetDirectionProvider.get_facingDirection().angle()
#		OffsetPosition = (new_position - _attachedGlobalPositionProvider.get_worldPosition()).rotated(-rotationFromDirection)
#	updateGlobalPosition()

func add_velocity(velocity:Vector2):
	# no change in velocity
	pass

func _process(delta: float) -> void:
#ifdef PROFILING
#	updateAttachedMover(delta)
#
#func updateAttachedMover(delta):
#endif
	if _attachedGlobalPositionProvider == null or _attachedGlobalPositionProvider.is_queued_for_deletion():
		return
	updateGlobalPosition(true, delta)
	updateGlobalDirection(true, delta)
