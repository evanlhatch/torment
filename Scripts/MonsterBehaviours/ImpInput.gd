extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 150.0
@export var BackoffWhenInRange : float = 120.0
@export var BackoffSpeedFactor : float = 0.8
@export var ConfidenceAngle : float = 90.0
@export var NaturalConfidenceCap : float = 1.5
@export var ConfidenceIndicatorPath : NodePath

var directionSetter : Node
var facingSetter : Node
var input_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var _targetFacingProvider : Node

var _confidence : float
var _confidenceIndicator : Node


func _ready():
	initGameObjectComponent()
	_confidence = 0.0
	_confidenceIndicator = get_node(ConfidenceIndicatorPath)
	directionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	facingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)


func _process(delta):
#ifdef PROFILING
#	updateImpInput(delta)
#
#func updateImpInput(delta):
#endif
	var newInputDir : Vector2 = Vector2.ZERO
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		var distance_to_target = newInputDir.length()

		if distance_to_target <= StopWhenInRange and _confidence < 1.0:
			var normalizedInput = newInputDir.normalized()
			var targetFacing = _targetFacingProvider.get_facingDirection()
			var evasionFactor = targetFacing.dot(normalizedInput)
			var evasionVector = (normalizedInput - targetFacing).normalized() * evasionFactor
			if distance_to_target <= BackoffWhenInRange and BackoffSpeedFactor > 0.0:
				newInputDir = (normalizedInput + evasionVector).normalized() * -BackoffSpeedFactor
			else:
				newInputDir = evasionVector.normalized()
		else:
			newInputDir = newInputDir.normalized()
		
	update_confidence(delta)
	if _confidence > NaturalConfidenceCap:
		newInputDir = newInputDir.normalized() * 1.5
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		directionSetter.set_targetDirection(input_direction)
		facingSetter.set_facingDirection(get_aimDirection())


func set_confidence(newConfidence:float):
	_confidence = newConfidence


func update_confidence(delta:float):
	if _confidence > NaturalConfidenceCap:
		_confidence -= delta
	elif is_targetProvider_valid() and _targetFacingProvider:
		var targetDir = _targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
		var targetFacing = _targetFacingProvider.get_facingDirection()
		if targetDir.length_squared() < 0.1: return
		if abs(rad_to_deg(targetFacing.angle_to(-targetDir))) >=ConfidenceAngle:
			_confidence = clamp(_confidence + delta, 0.0, NaturalConfidenceCap)
		else:
			_confidence = clamp(_confidence - delta, 0.0, NaturalConfidenceCap)
	
	if _confidenceIndicator:
		if _confidenceIndicator.visible and _confidence < NaturalConfidenceCap:
			_confidenceIndicator.visible = false
		elif not _confidenceIndicator.visible and _confidence >= NaturalConfidenceCap:
			_confidenceIndicator.visible = true


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	_targetFacingProvider = targetNode.getChildNodeWithMethod("get_facingDirection")


func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
