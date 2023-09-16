extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var MaxAttackDistance : float = 32.0
@export var AttackEffectScene : PackedScene

@export_group("Loitering Parameters")
@export var MinMotionDuration : float = 1.0
@export var MaxMotionDuration : float = 1.0
@export var MinLoiteringDuration : float = 0.0
@export var MaxLoiteringDuration : float = 0.0

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var loitering_counter : float
var stomping : bool

signal AttackTriggered(attack_index:int)
signal input_dir_changed(dir_vector:Vector2)

var _aimDirection : Vector2
var _targetPosProvider : Node
var _targetOverrideProvider : Node
var _targetPosOffset : Vector2


func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_targetPosOffset = (Vector2.ONE * randf_range(60.0, 90.0)).rotated(randf_range(-PI, PI))


func _process(delta):
	if stomping: return
	var newInputDir : Vector2 = Vector2.ZERO

	var targetPos : Vector2
	var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
	if not hasOverridePos:
		if is_targetProvider_valid(): targetPos = _targetPosProvider.get_worldPosition() + _targetPosOffset
	else:
		targetPos = _targetOverrideProvider.get_override_target_position()

	newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()

	if is_targetProvider_valid():
		var dist_sqr = get_gameobjectWorldPosition().distance_squared_to(
			_targetPosProvider.get_worldPosition())
		if dist_sqr <= MaxAttackDistance * MaxAttackDistance:
			perform_stomp()
			return

	if MaxLoiteringDuration > 0.0:
		if loitering_counter == 0.0:
			loitering_counter = randf_range(MinLoiteringDuration, MaxLoiteringDuration)
		elif loitering_counter > 0.0:
			loitering_counter = clamp(loitering_counter - delta, 0.0, 9999.0)
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
			if loitering_counter == 0.0:
				loitering_counter = -randf_range(MinMotionDuration, MaxMotionDuration)
		elif loitering_counter < 0.0:
			loitering_counter = clamp(loitering_counter + delta, -9999.0, 0.0)

	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)


func perform_stomp():
	if stomping: return
	input_direction = Vector2.ZERO
	input_dir_changed.emit(input_direction)
	targetDirectionSetter.set_targetDirection(input_direction)
	stomping = true
	AttackTriggered.emit(0)
	var attack_effect = AttackEffectScene.instantiate()
	attack_effect.global_position = get_gameobjectWorldPosition()
	Global.attach_toWorld(attack_effect)
	if attack_effect.has_method("start"):
		attack_effect.start(_gameObject, 0.5)
	$StompTimer.start(1)
	await $StompTimer.timeout
	_targetPosOffset = (Vector2.ONE * randf_range(60.0, 90.0)).rotated(randf_range(-PI, PI))
	stomping = false


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


func get_aimDirection() -> Vector2:
	return _aimDirection


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
