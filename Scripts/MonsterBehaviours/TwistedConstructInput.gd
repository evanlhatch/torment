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

@export_group("Scene References")
@export var FireBlastScene : PackedScene
@export var LightningBlastScene : PackedScene

@export_group("Head Positions")
@export var HeadSprite : Node2D
@export var HeadEmissionPos : Node2D
@export var HeadPositions : Array[Vector2]

@export_group("Emitters")
@export var BlitzEmitter : Node
@export var BlitzStarEmitter : Node

signal AttackTriggered(attack_index:int)

var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2
var aim_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetOverrideProvider : Node
var _targetPosProvider : Node
var _delay_timer : Timer

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _action_draw_pool

func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	stunEffect = _gameObject.getChildNodeWithMethod("is_stunned")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_action_draw_pool = createValueDrawPool([0,0,1,1])
	_delay_timer = Timer.new()
	add_child(_delay_timer)

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
			aim_direction = _targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
			var dir_index : int = DirectionsUtil.get_direction_from_vector(aim_direction)
			HeadSprite.position = HeadPositions[dir_index]
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
				attackDir = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized()
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
			if is_targetProvider_valid(): targetPos = _targetPosProvider.get_worldPosition()
		else:
			targetPos = _targetOverrideProvider.get_override_target_position()
		newInputDir = targetPos - get_gameobjectWorldPosition()
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
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)
		if input_direction.length_squared() > 0:
			aim_direction = newInputDir
		var dir_index : int = DirectionsUtil.get_direction_from_vector(aim_direction)
		HeadSprite.position = HeadPositions[dir_index]
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack():
	emit_signal("AttackTriggered", 0)
	if CastVoicePlayer != null:
		CastVoicePlayer.play_variation()
	_attackDurationTimer = AttackDuration
	if is_targetProvider_valid():
		# attacks more often when player is further away
		var repeat_time_factor = clamp(inverse_lerp(MaxDistForAttack, 32.0,
			(_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).length()),
			0.0, 1.0)
		_attackRepeatTimer = lerp(MinTimeForAttack, MaxTimeForAttack, repeat_time_factor)
	else:
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_attack_A(direction:Vector2):
	var dir1 = direction * 90.0
	var dir2 = direction * 210.0
	for i in 16:
		var blast1 = FireBlastScene.instantiate()
		var blast2 = FireBlastScene.instantiate()
		blast1.global_position = get_gameobjectWorldPosition() + dir1
		blast2.global_position = get_gameobjectWorldPosition() + dir2
		Global.attach_toWorld(blast1)
		Global.attach_toWorld(blast2)
		if blast1.has_method("start"): blast1.start(_gameObject)
		if blast2.has_method("start"): blast2.start(_gameObject)
		dir1 = dir1.rotated(2 * PI / 16.0)
		dir2 = dir2.rotated(-2 * PI / 16.0)
		_delay_timer.start(0.05); await _delay_timer.timeout

func _perform_attack_far_A(direction:Vector2):
	BlitzEmitter.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	BlitzEmitter.set_emitting(false)

func _perform_attack_B(direction:Vector2):
	var dir = direction.rotated(-PI * 0.3) * 180.0
	for i in 12:
		var blast = LightningBlastScene.instantiate()
		Global.attach_toWorld(blast)
		blast.global_position = get_gameobjectWorldPosition() + dir * randf_range(0.5, 1.5)
		if blast.has_method("start"):
			blast.start(_gameObject, HeadEmissionPos)
		dir = dir.rotated(PI * 0.6 / 12.0)
		await get_tree().create_timer(0.075, false).timeout

func _perform_attack_far_B(direction:Vector2):
	BlitzStarEmitter.set_emitting(true)
	_delay_timer.start(_attackDurationTimer)
	await _delay_timer.timeout
	BlitzStarEmitter.set_emitting(false)

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
