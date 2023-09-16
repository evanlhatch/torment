extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var RangedAttacksDistance : float = 200.0
@export var MaxDistForAttack : float = 400.0
@export var MinTimeForAttack : float = 1.75
@export var MaxTimeForAttack : float = 3.5
@export var AttackDuration : float = 1.6
@export var AttackMoment : float = 0.8
@export var FlameTrailTrigger : Node

@export_group("Sound Players")
@export var CastVoicePlayer : AudioStreamPlayer2D

@export_group("Scene References")
@export var FirePatchScene:PackedScene
@export var VolcanoProjectile : PackedScene

@export_group("Emitters")
@export var FlameEmitter : Node

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

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool
var _circling_angle : float

func _ready():
	initGameObjectComponent()
	gameObject = Global.get_gameObject_in_parents(self)
	gameObject.child_entered_tree.connect(_on_child_entered_gameObject)
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
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,3])

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if stunEffect and stunEffect.is_stunned():
		_update_direction(newInputDir)
		return

	var attackDir = targetFacingSetter.get_facingDirection()
	if is_targetProvider_valid():
		attackDir = (_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).normalized()

	var current_attack_pattern : int = -1
	if _attackDurationTimer > 0:
		var distance_to_target = 0.0
		if is_targetProvider_valid():
			distance_to_target = (_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).length()
		_update_direction(newInputDir)
		var attFlankA = _attackDurationTimer > AttackMoment
		_attackDurationTimer -= delta
		var attFlankB = _attackDurationTimer <= AttackMoment
		if attFlankA and attFlankB:
			current_attack_pattern = _action_draw_pool.draw_value()
			match(current_attack_pattern):
				0: _perform_attack_A(attackDir)
				1: _perform_attack_B(attackDir)
				2: _perform_attack_C()
				3: _perform_attack_D()
		return

	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		var direction_to_player = targetPos - positionProvider.get_worldPosition()
		newInputDir = get_circling_input_dir(direction_to_player)
		_circling_angle += delta * PI * 0.6
		if direction_to_player.length() <= MaxDistForAttack:
			_attackRepeatTimer -= delta
			if _attackRepeatTimer <= 0:
				_start_attack()
		if direction_to_player.length() <= StopWhenInRange:
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)

func get_circling_input_dir(direction_to_player:Vector2) -> Vector2:
	var vector_from_player = (-direction_to_player).normalized() * 100.0
	vector_from_player = vector_from_player.rotated(_circling_angle)
	return direction_to_player + vector_from_player

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

func get_facingDirection():
	return get_aimDirection()

func _start_attack(custom_attack_duration:float = -1.0):
	CastVoicePlayer.play_variation()
	if custom_attack_duration < 0.0: _attackDurationTimer = AttackDuration
	else: _attackDurationTimer = custom_attack_duration
	if is_targetProvider_valid():
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_circling_angle = 0.0

func _perform_attack_A(direction:Vector2):
	if not is_targetProvider_valid(): return
	FlameTrailTrigger.set_active(true)
	var target_pos = _targetPosProvider.get_worldPosition()
	var landing_position = target_pos + direction * 100.0
	_delay_timer.start(0.4); await _delay_timer.timeout
	AttackTriggered.emit(1)
	positionProvider.jump_to(landing_position, 0.6, 0.5)
	# Play a dashing sound sample
	# JumpVoicePlayer.play_variation()
	_delay_timer.start(0.6); await _delay_timer.timeout
	FlameTrailTrigger.set_active(false)

func _perform_attack_B(direction:Vector2):
	FlameEmitter.set_emitting(true)
	_delay_timer.start(2.0)
	await _delay_timer.timeout
	FlameEmitter.set_emitting(false)

func _perform_attack_C():
	if not is_targetProvider_valid(): return
	for i in 6:
		var target_pos = _targetPosProvider.get_worldPosition()
		var projectile : GameObject = VolcanoProjectile.instantiate()
		Global.attach_toWorld(projectile, false)
		if projectile.has_method("set_sourceGameObject"):
			projectile.set_sourceGameObject(_gameObject)
		elif projectile.has_method("set_externalSource"):
			projectile.set_externalSource(_gameObject)
		var p = projectile.getChildNodeWithMethod("start_ballistic_motion")
		var pos = positionProvider.get_worldPosition()
		target_pos += (Vector2.ONE * randf_range(-70.0, 70.0)).rotated(randf_range(-PI, PI))
		p.start_ballistic_motion(pos, target_pos)
		_delay_timer.start(0.2); await _delay_timer.timeout

const flama_angle_increment : float = PI / 18.0
func _perform_attack_D():
	if not is_targetProvider_valid(): return
	var target_pos = _targetPosProvider.get_worldPosition()
	var flame_vector = Vector2.RIGHT * 200.0
	for i in 36:
		var firePatch = FirePatchScene.instantiate()
		if firePatch.has_method("set_sourceGameObject"):
			firePatch.set_sourceGameObject(_gameObject)
		elif firePatch.has_method("set_externalSource"):
			firePatch.set_externalSource(_gameObject)
		firePatch.global_position = target_pos + flame_vector
		Global.attach_toWorld(firePatch)
		if firePatch.has_method("start"):
			firePatch.start(_gameObject)
		flame_vector = flame_vector.rotated(flama_angle_increment)


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
