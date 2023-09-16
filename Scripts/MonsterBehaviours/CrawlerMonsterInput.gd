extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var MovementSineStrength : float = 1.35
@export var MovementSineInterval : float = 45
@export var MovementSineFalloffDistanceMin : float = 30
@export var MovementSineFalloffDistanceMax : float = 300

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var attacking : bool

signal AttackTriggered(attack_index:int)
signal input_dir_changed(dir_vector:Vector2)

var _targetPosProvider : Node
var _targetOverrideProvider : Node
var _sineCoefficient : float

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_sineCoefficient = MovementSineStrength / MovementSineInterval


func _process(delta):
	if attacking: return
	var newInputDir : Vector2 = Vector2.ZERO

	var targetPos : Vector2
	var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
	if not hasOverridePos:
		if is_targetProvider_valid():
			targetPos = _targetPosProvider.get_worldPosition()
			var rawDir = targetPos - get_gameobjectWorldPosition()
			var distance = rawDir.length()
			var sineFalloff = clampf(inverse_lerp(
				MovementSineFalloffDistanceMin,
				MovementSineFalloffDistanceMax,
				distance), 0.0, 1.0)
			var sineFactor = distance * _sineCoefficient * sineFalloff
			var rotation = sin(sineFactor)
			newInputDir = rawDir.rotated(rotation).normalized()
	else:
		targetPos = _targetOverrideProvider.get_override_target_position()
		newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()

	targetFacingSetter.set_facingDirection(newInputDir)

	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
