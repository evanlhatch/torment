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
@export var IceColumnScene : PackedScene
@export var StompEffectScene : PackedScene

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

	var distance_to_target = 0.0
	if _attackDurationTimer > 0:
		if is_targetProvider_valid():
			aim_direction = _targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
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
		distance_to_target = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).length()
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
				if distance_to_target < RangedAttacksDistance: _start_attack(0)
				else: _start_attack(1)
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
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack(attack_index:int):
	emit_signal("AttackTriggered", attack_index)
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
	if not is_targetProvider_valid(): return
	var dir = direction * 80.0
	dir = dir.rotated(randf_range(-PI, PI))
	for i in 5:
		var ice_column = IceColumnScene.instantiate()
		ice_column.global_position = _targetPosProvider.get_worldPosition() + dir
		Global.attach_toWorld(ice_column)
		dir = dir.rotated(2 * PI / 5.0)
	_delay_timer.start(0.3); await _delay_timer.timeout
	dir += dir * 0.7
	dir = dir.rotated(PI / 5.0)
	for i in 5:
		var ice_column = IceColumnScene.instantiate()
		ice_column.global_position = _targetPosProvider.get_worldPosition() + dir
		Global.attach_toWorld(ice_column)
		dir = dir.rotated(2 * PI / 5.0)

func _perform_attack_far_A(direction:Vector2):
	var increment = direction * 50.0
	var pos = get_gameobjectWorldPosition() + increment
	for i in 16:
		var ice_column = IceColumnScene.instantiate()
		ice_column.global_position = pos
		Global.attach_toWorld(ice_column)
		pos += increment
		_delay_timer.start(0.03); await _delay_timer.timeout

func _perform_attack_B(direction:Vector2):
	var dir = direction * 50.0
	for i in 4:
		var attack_effect = StompEffectScene.instantiate()
		attack_effect.global_position = get_gameobjectWorldPosition() + dir
		Global.attach_toWorld(attack_effect)
		if attack_effect.has_method("start"): attack_effect.start(_gameObject, 0.5)
		dir += direction.rotated(pow(-1, (i+1)) * randf_range(-0.3, 0.3) * PI) * 50.0
		_delay_timer.start(0.2); await _delay_timer.timeout

func _perform_attack_far_B(direction:Vector2):
	if not is_targetProvider_valid(): return
	var pos = _targetPosProvider.get_worldPosition()
	var dir = direction * 100.0
	dir = dir.rotated(randf_range(-PI, PI))
	for i in 5:
		var ice_column_1 = IceColumnScene.instantiate()
		var ice_column_2 = IceColumnScene.instantiate()
		ice_column_1.global_position = pos + dir
		ice_column_2.global_position = pos - dir
		Global.attach_toWorld(ice_column_1)
		Global.attach_toWorld(ice_column_2)
		dir = dir.rotated(PI / 10.0)
	_delay_timer.start(0.5); await _delay_timer.timeout
	dir = dir.rotated(PI)
	dir += dir
	for i in 7:
		var ice_column_1 = IceColumnScene.instantiate()
		var ice_column_2 = IceColumnScene.instantiate()
		ice_column_1.global_position = pos + dir
		ice_column_2.global_position = pos - dir
		Global.attach_toWorld(ice_column_1)
		Global.attach_toWorld(ice_column_2)
		dir = dir.rotated(PI / 14.0)

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
