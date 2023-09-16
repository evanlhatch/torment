extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var MaxDistForAttack : float = 400.0
@export var MinTimeForAttack : float = 1.0
@export var MaxTimeForAttack : float = 3.5
@export var AttackDuration : float = 1.6
@export var AttackMoment : float = 0.8

@export_group("Node References")
@export var BulletEmitter : Node

@export_group("Sound Players")
@export var CastVoicePlayer : AudioStreamPlayer2D

@export_group("Scene References")
@export var IceColumnScene : PackedScene
@export var ArrowsScene : PackedScene

signal AttackTriggered(attack_index:int)

var gameObject : GameObject
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
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
	stunEffect = gameObject.getChildNodeWithMethod("is_stunned")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2])
	_delay_timer = Timer.new()
	add_child(_delay_timer)

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

var _attack_index : int = 0
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
			match(_attack_index):
				0: _perform_ice_columns(attackDir)
				1: _perform_ice_column_wall(attackDir)
				2: _perform_avalanche(attackDir)
		return

	if is_targetProvider_valid() and not positionProvider._is_jumping:
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - positionProvider.get_worldPosition()
		if newInputDir.length() <= MaxDistForAttack:
			_attackRepeatTimer -= delta
			if _attackRepeatTimer <= 0:
				_attack_index = _action_draw_pool.draw_value()
				_start_attack(
					1 if _attack_index < 2 else 0,
					-1.0 if _attack_index < 2 else 1.0)
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
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack(attack_index:int, custom_attack_duration:float = -1.0):
	AttackTriggered.emit(attack_index)
	CastVoicePlayer.play_variation()
	if custom_attack_duration < 0.0: _attackDurationTimer = AttackDuration
	else: _attackDurationTimer = custom_attack_duration
	if is_targetProvider_valid():
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_ice_columns(direction:Vector2):
	if not is_targetProvider_valid(): return
	var angle_increment = PI * 0.33333
	for i in range(5):
		var offset = direction * ((i + 1) * 90.0)
		for j in range(6):
			var pos = get_gameobjectWorldPosition() + offset.rotated(j * angle_increment)
			var ice_column = IceColumnScene.instantiate()
			ice_column.global_position = pos
			Global.attach_toWorld(ice_column)
		await get_tree().create_timer(0.15, false).timeout

func _perform_ice_column_wall(direction:Vector2):
	if not is_targetProvider_valid(): return
	var left_wall_dir = direction.rotated(PI * 0.5)
	var right_wall_dir = direction.rotated(PI * -0.5)
	var left_offset = left_wall_dir * 25
	var right_offset = right_wall_dir * 25
	var wall_pos = _targetPosProvider.get_worldPosition() + direction * 100
	for i in 5:
		var ice_column_l = IceColumnScene.instantiate()
		var ice_column_r = IceColumnScene.instantiate()
		ice_column_l.global_position = wall_pos + left_offset
		ice_column_r.global_position = wall_pos + right_offset
		Global.attach_toWorld(ice_column_l)
		Global.attach_toWorld(ice_column_r)
		left_offset += left_wall_dir * 50
		right_offset += right_wall_dir * 50
		_delay_timer.start(0.1); await _delay_timer.timeout

func _perform_avalanche(direction:Vector2):
	if not is_targetProvider_valid(): return
	BulletEmitter.set_emitting(true)
	_delay_timer.start(0.1)
	await _delay_timer.timeout
	BulletEmitter.set_emitting(false)

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
