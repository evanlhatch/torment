extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 132.0
@export var BackoffWhenInRange : float = 100.0
@export var BackoffSpeedFactor : float = 0.7
@export var AttackStopDuration : float = 0.5

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var bullet_emitter : Node

signal input_dir_changed(dir_vector:Vector2)

var _targetPosProvider : Node
var _attackStopTimer : float
var _targetOverrideProvider : Node

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	bullet_emitter = _gameObject.getChildNodeWithMethod("set_emitting")
	bullet_emitter.connect("AttackTriggered", on_attack_triggered)

func _process(delta):
	var targetPos : Vector2
	var newInputDir : Vector2 = Vector2.ZERO
	var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
	if _attackStopTimer > 0:
		_attackStopTimer -= delta
	elif not hasOverridePos and is_targetProvider_valid():
		targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		var distance_to_target = newInputDir.length()
		if distance_to_target <= StopWhenInRange:
			bullet_emitter.set_emitting(true)
			targetFacingSetter.set_facingDirection(newInputDir)
			if distance_to_target <= BackoffWhenInRange and BackoffSpeedFactor > 0.0:
				newInputDir = newInputDir.normalized() * -BackoffSpeedFactor
			else:
				newInputDir = Vector2.ZERO
		else:
			bullet_emitter.set_emitting(false)
			newInputDir = newInputDir.normalized()
	elif is_instance_valid(_targetOverrideProvider):
		targetPos = _targetOverrideProvider.get_override_target_position()
		newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()

	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)
		targetFacingSetter.set_facingDirection(get_aimDirection())

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	var throwEmitter = _gameObject.getChildNodeWithMethod("set_throw_target")
	if throwEmitter != null:
		throwEmitter.set_throw_target(targetNode)

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func on_attack_triggered(_attack_index:int):
	_attackStopTimer = AttackStopDuration

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
