extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var MaxDistForAttack : float = 300.0
@export var RangedAttacksDistance : float = 180.0
@export var MinTimeForAttack : float = 1.0
@export var MaxTimeForAttack : float = 3.5
@export var AttackDuration : float = 1.6
@export var AttackMoment : float = 0.8

@export_group("Sound Players")
@export var CastVoicePlayer : AudioStreamPlayer2D

@export_group("Emitters")
@export var FlameEmitterA : Node
@export var FlameEmitterB : Node
@export var ThrowEmitter : Node
@export var FlameWallEmitter1 : Node
@export var FlameWallEmitter2 : Node

signal AttackTriggered(attack_index:int)

var gameObject : GameObject
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2
var aim_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var _targetOverrideProvider : Node
var _delay_timer : Timer

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _action_draw_pool

func _ready():
	initGameObjectComponent()
	gameObject = Global.get_gameObject_in_parents(self)
	gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	positionProvider = gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	stunEffect = gameObject.getChildNodeWithMethod("is_stunned")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_action_draw_pool = createValueDrawPool([0,0,1,1])

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if stunEffect and stunEffect.is_stunned():
		_update_direction(newInputDir)
		return

	if _attackDurationTimer > 0:
		var distance_to_target = 0.0
		if is_targetProvider_valid():
			aim_direction = _targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()
			distance_to_target = aim_direction.length()
			aim_direction = aim_direction.normalized()
			targetFacingSetter.set_facingDirection(aim_direction)
		_update_direction(newInputDir)
		var attFlankA = _attackDurationTimer > AttackMoment
		_attackDurationTimer -= delta
		var attFlankB = _attackDurationTimer <= AttackMoment
		if attFlankA and attFlankB:
			var attackDir = targetFacingSetter.get_facingDirection()
			if is_targetProvider_valid():
				attackDir = (_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).normalized()
			match(_action_draw_pool.draw_value()):
				0:
					if distance_to_target < RangedAttacksDistance: _perform_attack_A(attackDir)
					else: _perform_attack_far_A(attackDir)
				1:
					if distance_to_target < RangedAttacksDistance: _perform_attack_B(attackDir)
					else: _perform_attack_far_B(attackDir)
		return

	if is_targetProvider_valid():
		var targetPos : Vector2 = Vector2.ZERO
		var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
		if not hasOverridePos:
			targetPos = _targetPosProvider.get_worldPosition()
		else:
			targetPos = _targetOverrideProvider.get_override_target_position()
		newInputDir = targetPos - positionProvider.get_worldPosition()
		if newInputDir.length() <= MaxDistForAttack:
			_attackRepeatTimer -= delta
			if _attackRepeatTimer <= 0:
				_start_attack()
		if newInputDir.length() <= StopWhenInRange:
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	return aim_direction

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		if newInputDir.length_squared() > 0.0:
			aim_direction = newInputDir
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack():
	if is_instance_valid(CastVoicePlayer):
		CastVoicePlayer.play_variation()
	_attackDurationTimer = AttackDuration
	if is_targetProvider_valid():
		# attacks more often when player is further away
		var repeat_time_factor = clamp(inverse_lerp(MaxDistForAttack, 32.0,
			(_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).length()),
			0.0, 1.0)
		_attackRepeatTimer = lerp(MinTimeForAttack, MaxTimeForAttack, repeat_time_factor)
	else:
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_attack_A(direction:Vector2):
	AttackTriggered.emit(1)
	FlameEmitterA.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	FlameEmitterA.set_emitting(false)

func _perform_attack_far_A(direction:Vector2):
	AttackTriggered.emit(1)
	ThrowEmitter.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	ThrowEmitter.set_emitting(false)

func _perform_attack_B(direction:Vector2):
	AttackTriggered.emit(1)
	FlameEmitterB.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	FlameEmitterB.set_emitting(false)

func _perform_attack_far_B(direction:Vector2):
	AttackTriggered.emit(1)
	FlameWallEmitter1.set_emitting(true)
	FlameWallEmitter2.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	FlameWallEmitter1.set_emitting(false)
	FlameWallEmitter2.set_emitting(false)

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
