extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var JumpAttackMaxDistance : float = 160.0
@export var JumpAttackMinDistance : float = 80.0
@export var MinTimeForAttack : float = 2.0
@export var MaxTimeForAttack : float = 6.0
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6

@export_enum("Linear", "Curve") var MovePattern : int

@export_group("Curved Movement Parameters")
@export var MovementCurvatureAngle : float = 30.0
@export var MovementCurvatureDistance : float = 300.0

@export_group("Sound Resources")
@export var JumpVoice : AudioFXResource

@export_group("Scene References")
@export var FireBlastScene : PackedScene

signal AttackTriggered(attack_index:int)

var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2
var healthComponent : Node

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var _targetsVelocityProvider : Node

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _curve_angle_factor : float

func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	stunEffect = _gameObject.getChildNodeWithMethod("is_stunned")
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_curve_angle_factor = 1.0

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if stunEffect and stunEffect.is_stunned():
		_update_direction(newInputDir)
		return
	
	if _attackDurationTimer > 0:
		_update_direction(newInputDir)
		var attFlankA = _attackDurationTimer > AttackMoment
		_attackDurationTimer -= delta
		var attFlankB = _attackDurationTimer <= AttackMoment
		if attFlankA and attFlankB:
			var attackDir = targetFacingSetter.get_facingDirection()
			if is_targetProvider_valid():
				attackDir = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized()
				_perform_jump_attack(attackDir)
		return
	
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		if MovePattern == 0:
			newInputDir = get_linear_movement_input(targetPos)
		elif MovePattern == 1:
			newInputDir = get_curved_movement_input(targetPos)
		_attackRepeatTimer -= delta
		var dist = newInputDir.length()
		if _attackRepeatTimer <= 0:
			if dist < JumpAttackMaxDistance and dist > JumpAttackMinDistance:
				_start_attack(0)
		
		if dist <= StopWhenInRange:
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	_targetsVelocityProvider = targetNode.getChildNodeWithMethod("get_targetVelocity")

func get_linear_movement_input(targetPos : Vector2) -> Vector2:
	return targetPos - get_gameobjectWorldPosition()

func get_curved_movement_input(targetPos : Vector2) -> Vector2:
	var target_vector : Vector2 = targetPos - get_gameobjectWorldPosition()
	var curve_factor = clamp(
		inverse_lerp(8.0, MovementCurvatureDistance, target_vector.length()),
		0.0, 1.0)
	return target_vector.rotated(deg_to_rad(lerp(0.0, MovementCurvatureAngle * _curve_angle_factor, curve_factor)))

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack(attack_animation_index:int, with_min_attack_repeat : bool = false):
	_attackDurationTimer = AttackDuration
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	if randf() >= 0.5: _curve_angle_factor *= -1.0

func _perform_jump_attack(attackDir:Vector2):
	if not is_targetProvider_valid(): return
	var target_pos = (_targetPosProvider.get_worldPosition() +
		#_targetsVelocityProvider.get_targetVelocity() +
		Vector2(randf_range(-64.0, 64.0), randf_range(-64.0, 64.0)))
	var landing_position = target_pos - attackDir * 20.0
	var blast = FireBlastScene.instantiate()
	blast.global_position = target_pos
	Global.attach_toWorld(blast)
	blast.start(_gameObject, 0.8)
	_delay_timer.start(0.3); await _delay_timer.timeout
	if healthComponent != null:
		healthComponent.setInvincibleForTime(0.6)
	positionProvider.jump_to(landing_position, 0.6, 0.5)
	AttackTriggered.emit(0)
	FxAudioPlayer.play_sound_2D(JumpVoice, _positionProvider.get_worldPosition(), false, false, 0,0)
	_delay_timer.start(0.6); await _delay_timer.timeout

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
