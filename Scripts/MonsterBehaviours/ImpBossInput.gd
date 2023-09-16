extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var JumpAttackAtRange : float = 130.0
@export var MaxDistForAttack : float = 200.0
@export var MinTimeForAttack : float = 1.0
@export var MaxTimeForAttack : float = 2.0
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6

@export_group("Encourage Parameters")
@export var EncourageCastRange : float = 120.0
@export var EncourageRadius : float = 40.0
@export var EncourageLocatorPool : String = "Enemies"

@export_group("Sound Players")
@export var JumpVoicePlayer : AudioStreamPlayer2D
@export var TauntVoicePlayer : AudioStreamPlayer2D

@export_group("Scene References")
@export var RaiseImpScene : PackedScene
@export var EncourageAreaScene : PackedScene
@export var GroundHitScene : PackedScene
@export var FireBlastScene : PackedScene

signal AttackTriggered(attack_index:int)

var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var stunEffect : Node
var input_direction : Vector2
var bullet_emitter : Node
var current_attack_index : int
var healthComponent : Node

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool
var _blast_pattern_pool

func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	bullet_emitter = _gameObject.getChildNodeWithMethod("set_emitting")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	stunEffect = _gameObject.getChildNodeWithMethod("is_stunned")
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,2])
	_blast_pattern_pool = createValueDrawPool([0,0,1,1,2,2])

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
				match(current_attack_index):
					0: _perform_summon(attackDir)
					1: _perform_encourage()
					2: _perform_jump_attack(attackDir)
		return

	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		_attackRepeatTimer -= delta
		if _attackRepeatTimer <= 0:
			if newInputDir.length() >= JumpAttackAtRange:
				current_attack_index = 2
				_start_attack(0)
			elif newInputDir.length() <= MaxDistForAttack:
				current_attack_index = _action_draw_pool.draw_value()
				if current_attack_index < 2:
					_start_attack(1)
				else:
					_start_attack(0)


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
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack(attack_animation_index:int, with_min_attack_repeat : bool = false):
	# attack animation 0 is delayed and invoked by the _perform_jump_attack routine
	if attack_animation_index > 0:
		TauntVoicePlayer.play_variation()
		emit_signal("AttackTriggered", attack_animation_index)
	_attackDurationTimer = AttackDuration
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_summon(attackDir:Vector2):
	for i in 5:
		var dir = attackDir.rotated(randf_range(-PI, PI) * 0.4) * randf_range(80.0, 200.0)
		if not is_targetProvider_valid(): return
		var pos = _targetPosProvider.get_worldPosition() + dir
		var imp_raising = RaiseImpScene.instantiate()
		Global.attach_toWorld(imp_raising)
		imp_raising.raise(pos, -dir)
		_delay_timer.start(0.1)
		await _delay_timer.timeout


func _perform_encourage():
	var gameObjectsInRange = Global.World.Locators.get_gameobjects_in_circle(
		EncourageLocatorPool, get_gameobjectWorldPosition(), EncourageCastRange)
	gameObjectsInRange.shuffle()
	var target_imp : Node = null
	for go in gameObjectsInRange:
		target_imp = go.getChildNodeWithMethod("set_confidence")
		if target_imp:
			var encourageArea = EncourageAreaScene.instantiate()
			encourageArea.global_position = target_imp.get_gameobjectWorldPosition()
			Global.attach_toWorld(encourageArea)
			encourageArea.call_deferred("activate")
			return

func _perform_jump_attack(attackDir:Vector2):
	if not is_targetProvider_valid(): return
	var target_pos = _targetPosProvider.get_worldPosition()
	var landing_position = target_pos - attackDir * 40.0
	var blast = GroundHitScene.instantiate()
	blast.global_position = target_pos
	Global.attach_toWorld(blast)
	if blast.has_method("start"):
		blast.start(_gameObject, 1.0)
	_delay_timer.start(0.4); await _delay_timer.timeout
	if healthComponent != null:
		healthComponent.setInvincibleForTime(0.6)
	positionProvider.jump_to(landing_position, 0.6, 0.5)
	emit_signal("AttackTriggered", 0)
	JumpVoicePlayer.play_variation()
	_delay_timer.start(0.6); await _delay_timer.timeout
	match(_blast_pattern_pool.draw_value()):
		0: _blast_pattern_A(attackDir)
		1: _blast_pattern_B(attackDir)
		2: _blast_pattern_C(attackDir)

func _blast_pattern_A(attackDir:Vector2):
	for i in range(5):
		var angle_increment = float(i) * (PI * 0.11)
		var pos1 = get_gameobjectWorldPosition() + attackDir.rotated(PI * 0.5 - angle_increment) * 140.0
		var pos2 = get_gameobjectWorldPosition() + attackDir.rotated(-PI * 0.5 + angle_increment) * 140.0
		var blast1 = FireBlastScene.instantiate()
		var blast2 = FireBlastScene.instantiate()
		blast1.global_position = pos1
		blast2.global_position = pos2
		Global.attach_toWorld(blast1)
		Global.attach_toWorld(blast2)
		if blast1.has_method("start"):
			blast1.start(_gameObject)
			blast2.start(_gameObject)
		await get_tree().create_timer(0.12, false).timeout

func _blast_pattern_B(attackDir:Vector2):
	var angle_increment = PI * 0.33333
	for i in range(5):
		var offset = attackDir * ((i + 2) * 42.0)
		for j in range(6):
			var pos = get_gameobjectWorldPosition() + offset.rotated(j * angle_increment)
			var blast = FireBlastScene.instantiate()
			blast.global_position = pos
			Global.attach_toWorld(blast)
			if blast.has_method("start"):
				blast.start(_gameObject)
		await get_tree().create_timer(0.10, false).timeout

func _blast_pattern_C(attackDir:Vector2):
	var angle_increment = PI * 0.33333
	for i in range(6):
		var offset = attackDir.rotated(i * angle_increment)
		for j in range(5):
			var pos = get_gameobjectWorldPosition() + offset.rotated(-PI * j * 0.05) * ((j + 2) * 42.0)
			var blast = FireBlastScene.instantiate()
			blast.global_position = pos
			Global.attach_toWorld(blast)
			if blast.has_method("start"):
				blast.start(_gameObject)
		await get_tree().create_timer(0.135, false).timeout

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
