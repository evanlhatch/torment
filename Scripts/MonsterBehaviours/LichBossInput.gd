extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var RangedAttacksDistance : float = 200.0
@export var MaxDistForAttack : float = 400.0
@export var MinTimeForAttack : float = 1.75
@export var MaxTimeForAttack : float = 3.5
@export var AttackDuration : float = 1.6
@export var AttackMoment : float = 0.8

@export_group("Sound Players")
@export var CastVoicePlayer : AudioStreamPlayer2D

@export_group("Scene References")
@export var RaiseSkeletonScene:PackedScene

signal AttackTriggered(attack_index:int)

var gameObject : GameObject
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2
var bullet_emitter : Node

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool

func _ready():
	initGameObjectComponent()
	gameObject = Global.get_gameObject_in_parents(self)
	gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	bullet_emitter = gameObject.getChildNodeWithMethod("set_emitting")
	positionProvider = gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = gameObject.getChildNodeWithMethod("set_facingDirection")
	stunEffect = gameObject.getChildNodeWithMethod("is_stunned")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,2])

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
			distance_to_target = (_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).length()
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
					else: _perform_attack_D(attackDir)
				1:
					_perform_attack_B(attackDir)
				2:
					if distance_to_target < RangedAttacksDistance: _perform_attack_C(attackDir)
					else: _perform_attack_D(attackDir)
		return

	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
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
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - positionProvider.get_worldPosition()).normalized()
	return input_direction.normalized()

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack():
	AttackTriggered.emit(0)
	CastVoicePlayer.play_variation()
	_attackDurationTimer = AttackDuration
	if is_targetProvider_valid():
		# Lich attacks more often when player is further away
		var repeat_time_factor = clamp(inverse_lerp(MaxDistForAttack, 32.0,
			(_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).length()),
			0.0, 1.0)
		_attackRepeatTimer = lerp(MinTimeForAttack, MaxTimeForAttack, repeat_time_factor)
	else:
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_attack_A(direction:Vector2):
	var increment = direction.rotated(PI*0.5) * 40.0
	var pos1 = positionProvider.get_worldPosition() + direction * 80.0
	var pos2 = pos1
	for i in 5:
		var skeleton_raising = RaiseSkeletonScene.instantiate()
		Global.attach_toWorld(skeleton_raising)
		skeleton_raising.raise(pos1, direction)
		if i > 0: skeleton_raising.raise(pos2, direction)
		pos1 += increment
		pos2 -= increment
		_delay_timer.start(0.1); await _delay_timer.timeout

func _perform_attack_B(direction:Vector2):
	if not is_targetProvider_valid(): return
	var dir = direction * 220.0
	for i in 16:
		var skeleton_raising = RaiseSkeletonScene.instantiate()
		Global.attach_toWorld(skeleton_raising)
		skeleton_raising.raise(_targetPosProvider.get_worldPosition() + dir, -dir)
		dir = dir.rotated(2 * PI / 16.0)
		_delay_timer.start(0.075); await _delay_timer.timeout

func _perform_attack_C(direction:Vector2):
	bullet_emitter.set_emitting(true)
	_delay_timer.start(0.5)
	await _delay_timer.timeout
	bullet_emitter.set_emitting(false)

func _perform_attack_D(direction:Vector2):
	if not is_targetProvider_valid(): return
	var increment = direction.rotated(PI*0.5) * 36.0
	for i in 2:
		var pos1 = _targetPosProvider.get_worldPosition() + direction * (130.0 + 30.0 * i)
		pos1 -= increment * 0.5
		var pos2 = pos1 + increment
		for j in 4:
			var skeleton_raising = RaiseSkeletonScene.instantiate()
			Global.attach_toWorld(skeleton_raising)
			skeleton_raising.raise(pos1, -direction)
			skeleton_raising.raise(pos2, -direction)
			pos1 += increment
			pos2 -= increment
		_delay_timer.start(0.2); await _delay_timer.timeout

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
