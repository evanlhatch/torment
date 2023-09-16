extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var ConfidenceAngle : float = 45.0
@export var ConfidenceDistance : float = 280.0
@export var NaturalConfidenceCap : float = 0.75
@export var BlockChanceBonusWhenNotMoving : float = 0.5

var directionSetter : Node
var facingSetter : Node
var input_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var _targetFacingProvider : Node
var _targetPosOffset : Vector2

var _confidence : float
var _confidenceHalfCap : float

var _blockChanceMod : Modifier

func _ready():
	initGameObjectComponent()
	_confidence = 0.0
	_confidenceHalfCap = NaturalConfidenceCap * 0.5
	directionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	facingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_targetPosOffset = (Vector2.ONE * randf_range(50.0, 120.0)).rotated(randf_range(-PI, PI))
	_blockChanceMod = Modifier.create("BlockChance", _gameObject)


func _process(delta):
#ifdef PROFILING
#	updateImpShieldInput(delta)
#
#func updateImpShieldInput(delta):
#endif
	var newInputDir : Vector2 = Vector2.ZERO
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition() + _targetPosOffset
		newInputDir = targetPos - get_gameobjectWorldPosition()
		var distance_to_target = newInputDir.length()

		if _confidence < _confidenceHalfCap:
			newInputDir = Vector2.ZERO
			facingSetter.set_facingDirection(get_aimDirection())
			if input_direction.length_squared() > 0.0:
				updateModifier()
		else:
			newInputDir = newInputDir.normalized()
			if input_direction.length_squared() == 0.0:
				updateModifier()
		
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
		if (abs(rad_to_deg(targetFacing.angle_to(-targetDir))) >=ConfidenceAngle or 
			targetDir.length() > ConfidenceDistance):
			_confidence = clamp(_confidence + delta, 0.0, NaturalConfidenceCap)
		else:
			_confidence = clamp(_confidence - delta, 0.0, NaturalConfidenceCap)


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

func updateModifier():
	if _confidence < _confidenceHalfCap:
		_blockChanceMod.setAdditiveMod(BlockChanceBonusWhenNotMoving)
	else:
		_blockChanceMod.setAdditiveMod(0)
	_gameObject.triggerModifierUpdated("BlockChance")
