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
@export var ApperitionScene : PackedScene
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
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,3,3])
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
				0: _perform_attack_A(attackDir)
				1: _perform_attack_B(attackDir)
				2: _perform_attack_C(attackDir)
				3: perform_attack_D()
		return
	
	if is_targetProvider_valid() and not positionProvider._is_jumping:
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
	# monsters walk to their target and aim to their target...
	return input_direction

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack(custom_attack_duration:float = -1.0):
	CastVoicePlayer.play_variation()
	if custom_attack_duration < 0.0: _attackDurationTimer = AttackDuration
	else: _attackDurationTimer = custom_attack_duration
	if is_targetProvider_valid():
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_attack_A(direction:Vector2):
	if not is_targetProvider_valid(): return
	targetFacingSetter.set_facingDirection(direction)
	var target_pos = _targetPosProvider.get_worldPosition()
	var landing_position = target_pos + direction * 100.0
	AttackTriggered.emit(0)
	_delay_timer.start(0.5); await _delay_timer.timeout
	positionProvider.jump_to(landing_position, 0.4, 0.5)
	_attackDurationTimer = 0.6

func _perform_attack_B(direction:Vector2):
	if not is_targetProvider_valid(): return
	var direction_switch : bool = randf() > 0.5
	var lane_dir = direction.rotated(deg_to_rad(45.0 if direction_switch else -45.0))
	_delay_timer.start(0.5); await _delay_timer.timeout
	positionProvider.jump_to(positionProvider.get_worldPosition() + lane_dir * 280, 0.7, 0.5)
	var charge_dir = lane_dir.rotated(deg_to_rad(-90.0 if direction_switch else 90.0)).normalized()
	var wait_order = 1.8
	for i in 7:
		var apperition = ApperitionScene.instantiate()
		apperition.global_position = positionProvider.get_worldPosition()
		Global.attach_toWorld(apperition)
		var apperitionFacing = apperition.getChildNodeWithMethod("set_facingDirection")
		apperitionFacing.set_facingDirection(charge_dir)
		var apperitionInput = apperition.getChildNodeWithSignal("AttackTriggered")
		apperitionInput.WaitTime = wait_order
		wait_order -= 0.1
		_delay_timer.start(0.1); await _delay_timer.timeout
	
	targetFacingSetter.set_facingDirection(charge_dir)
	_delay_timer.start(0.25); await _delay_timer.timeout
	AttackTriggered.emit(1)

func _perform_attack_C(direction:Vector2):
	if not is_targetProvider_valid(): return
	var radius_vector = direction * -180.0
	var circle_center = positionProvider.get_worldPosition() + direction * 180.0
	var direction_switch : bool = randf() > 0.5
	var angle_increment = (PI/10.0) if direction_switch else (-PI/10.0)
	positionProvider.start_jump_manual()
	for i in 10:
		# create apperition
		var apperition = ApperitionScene.instantiate()
		apperition.global_position = positionProvider.get_worldPosition()
		Global.attach_toWorld(apperition)
		var apperitionFacing = apperition.getChildNodeWithMethod("set_facingDirection")
		apperitionFacing.set_facingDirection(-radius_vector)
		var apperitionInput = apperition.getChildNodeWithSignal("AttackTriggered")
		apperitionInput.WaitTime = 1.0
		
		# move
		radius_vector = radius_vector.rotated(angle_increment)
		var target_position = circle_center + radius_vector
		var jump_tween = create_tween()
		jump_tween.set_trans(Tween.TRANS_LINEAR)
		jump_tween.tween_property(positionProvider, "global_position", target_position, 0.12)
		await jump_tween.finished
	
	_delay_timer.start(0.5); await _delay_timer.timeout
	positionProvider.end_jump_manual()

func perform_attack_D():
	if not is_targetProvider_valid(): return
	_delay_timer.start(0.5); await _delay_timer.timeout
	AttackTriggered.emit(1)
	for i in 3:
		var target_pos = _targetPosProvider.get_worldPosition()
		var arrows = ArrowsScene.instantiate()
		arrows.global_position = target_pos + Vector2(randf_range(-100,100), randf_range(-100,100))
		Global.attach_toWorld(arrows)
		_delay_timer.start(0.25); await _delay_timer.timeout

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
