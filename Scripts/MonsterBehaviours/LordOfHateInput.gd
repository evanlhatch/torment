extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var MaxDistForAttack : float = 220.0
@export var MinTimeForAttack : float = 0.8
@export var MaxTimeForAttack : float = 1.5
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6
@export var CharacterSprite : Node

@export_group("Emitter References")
@export var BulletEmitter : Node
@export var FlameEmitter : Node

@export_group("Cyclone Settings")
@export var Mover : TwoDMover
@export var CycloneVisualNode : Node
@export var CycloneDamage : Node
@export var CycloneDuration : float = 4.0
@export var MovementCurvatureAngle : float = 40
@export var MovementCurvatureDistance : float = 200
@export var CycloneSound : AudioStreamPlayer2D

@export_group("Difficulty Scaling")
@export var DifficultyScaleCap : float = 2.3
@export var DifficultyIncrement : float = 0.02

@export_group("Scene References")
@export var GroundHitScene : PackedScene
@export var BlastSmallScene : PackedScene

signal AttackTriggered(attack_index:int)
signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife
signal DashComplete

var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var bullet_emission_angle : float
var current_attack_index : int
var healthComponent : Node

var _targetPosProvider : Node
var _targetOverrideProvider : Node

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool
var _blast_pattern_pool
var _stunEffect : Node
var _spinning : bool

@onready var _difficulty_scale : float = 1.0
var _movementSpeedMod : Modifier
var _attackSpeedMod : Modifier
var _initial_animation_scale : float
var _currentSpinCurvature : float

func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")

	_initial_animation_scale = CharacterSprite.AnimationSpeed

	_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedMod.setName("Lord of Hate Movement Difficulty")
	_movementSpeedMod.setAdditiveMod(0)
	_movementSpeedMod.setMultiplierMod(0)
	_attackSpeedMod = Modifier.create("AttackSpeed", _gameObject)
	_attackSpeedMod.setName("Lord of Hate Movement Attack")
	_attackSpeedMod.setAdditiveMod(0)
	_attackSpeedMod.setMultiplierMod(0)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("AttackSpeed")

	_currentSpinCurvature = MovementCurvatureAngle
	CycloneDamage.set_harmless(true)

	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,3,3,3])
	_blast_pattern_pool = createValueDrawPool([0,0,1,1])
	$DifficultyTimer.timeout.connect(_increase_difficulty)
	$DifficultyTimer.start()
	Global.World.notify_lord_appearance(_gameObject)

func _exit_tree():
	pass

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		_stunEffect = node

func _increase_difficulty():
	if _difficulty_scale >= DifficultyScaleCap:
		$DifficultyTimer.queue_free()
		return
	_difficulty_scale += DifficultyIncrement
	CharacterSprite.AnimationSpeed = _initial_animation_scale * _difficulty_scale
	_movementSpeedMod.setMultiplierMod(_difficulty_scale - 1.0)
	_attackSpeedMod.setMultiplierMod(_difficulty_scale - 1.0)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("AttackSpeed")

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if _stunEffect and _stunEffect.is_stunned():
		_update_direction(newInputDir)
		return

	if _attackDurationTimer > 0 and not _spinning:
		_update_direction(newInputDir)
		var attFlankA = _attackDurationTimer > (AttackMoment / _difficulty_scale)
		_attackDurationTimer -= delta
		var attFlankB = _attackDurationTimer <= (AttackMoment / _difficulty_scale)
		if attFlankA and attFlankB:
			var attackDir = targetFacingSetter.get_facingDirection()
			if is_targetProvider_valid():
				attackDir = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized()
				match(current_attack_index):
					0: _start_spinning()
					1: _perform_ranged_attack(attackDir)
					2: _perform_carpet_bombing(attackDir)
					3: _perform_jump_attack(attackDir)
		return


	if is_targetProvider_valid():
		var targetPos : Vector2 = Vector2.ZERO
		var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
		if not hasOverridePos:
			targetPos = _targetPosProvider.get_worldPosition()
			if is_targetProvider_valid(): targetPos = _targetPosProvider.get_worldPosition()
		else:
			targetPos = _targetOverrideProvider.get_override_target_position()

		if _spinning:
			var target_vector : Vector2 = targetPos - get_gameobjectWorldPosition()
			var curve_factor : float = clamp(
				inverse_lerp(8.0, MovementCurvatureDistance, target_vector.length()),
				0.0, 1.0)
			newInputDir = target_vector.rotated(deg_to_rad(lerp(0.0, _currentSpinCurvature, curve_factor))).normalized() * (1.8 / _difficulty_scale)
			_update_direction(newInputDir)
			return

		newInputDir = targetPos - get_gameobjectWorldPosition()
		_attackRepeatTimer -= delta
		if _attackRepeatTimer <= 0:
			if newInputDir.length() <= MaxDistForAttack:
				current_attack_index = _action_draw_pool.draw_value()
				_start_attack()

		if newInputDir.length() <= StopWhenInRange:
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)


func _start_attack(with_min_attack_repeat : bool = false):
	if current_attack_index == 2: AttackTriggered.emit(0)
	_attackDurationTimer = AttackDuration / _difficulty_scale
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)


func _start_spinning():
	_spinning = true
	_currentSpinCurvature = MovementCurvatureAngle * (-1.0 if randf() < 0.5 else 1.0)
	FlameEmitter.set_emitting(true)
	CycloneDamage.set_harmless(false)
	CharacterSprite.visible = false
	CycloneVisualNode.visible = true
	Mover.movementForce = 800
	CycloneSound.play()
	_delay_timer.start(CycloneDuration)
	await _delay_timer.timeout
	_attackDurationTimer = 0.0
	_spinning = false
	CycloneDamage.set_harmless(true)
	CharacterSprite.visible = true
	CycloneVisualNode.visible = false
	Mover.movementForce = 2300
	CycloneSound.stop()
	FlameEmitter.set_emitting(false)


func _perform_ranged_attack(direction:Vector2):
	BulletEmitter.set_emitting(true)
	for i in range(8):
		_delay_timer.start(0.1)
		await _delay_timer.timeout
		bullet_emission_angle += PI * 0.04
	bullet_emission_angle -= PI * 0.32
	BulletEmitter.set_emitting(false)


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
	AttackTriggered.emit(1)
	_delay_timer.start(0.6); await _delay_timer.timeout
	match(_blast_pattern_pool.draw_value()):
		0: _blast_pattern_A(attackDir)
		1: _blast_pattern_B(attackDir)


func _perform_carpet_bombing(direction:Vector2):
	var delay = 0.1 / _difficulty_scale
	for i in range(5):
		var offset = direction * ((i + 1) * 80.0)
		for j in range(6 + i * 2):
			var angle_increment = PI * (2.0 / float(6 + i * 2))
			var pos = get_gameobjectWorldPosition() + offset.rotated(j * angle_increment + randf_range(-0.5, 0.5))
			var blast = BlastSmallScene.instantiate()
			blast.global_position = pos
			Global.attach_toWorld(blast)
			if blast.has_method("start"):
				blast.start(_gameObject)
		await get_tree().create_timer(delay, false).timeout


func _blast_pattern_A(attackDir:Vector2):
	for i in range(16):
		var angle_increment = float(i) * (PI / 8.0)
		var pos = get_gameobjectWorldPosition() + attackDir.rotated(PI * 0.5 - angle_increment) * 120.0
		var blast = BlastSmallScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast)
		if blast.has_method("start"):
			blast.start(_gameObject)
	await get_tree().create_timer(0.35 / _difficulty_scale, false).timeout
	for i in range(20):
		var angle_increment = float(i) * (PI / 8.0)
		var pos = get_gameobjectWorldPosition() + attackDir.rotated(PI * 0.5 - angle_increment) * 230.0
		var blast = BlastSmallScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast)
		if blast.has_method("start"):
			blast.start(_gameObject)


func _blast_pattern_B(attackDir:Vector2):
	var angle_increment = PI * 0.33333
	var spawn_delay = 0.05 / _difficulty_scale
	for i in range(5):
		var offset = attackDir * ((i + 2) * 42.0)
		for j in range(6):
			var pos = get_gameobjectWorldPosition() + offset.rotated(j * angle_increment)
			var blast = BlastSmallScene.instantiate()
			blast.global_position = pos
			Global.attach_toWorld(blast)
			if blast.has_method("start"):
				blast.start(_gameObject)
		await get_tree().create_timer(spawn_delay, false).timeout


func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()


func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - positionProvider.get_worldPosition()).normalized().rotated(bullet_emission_angle)
	return input_direction.normalized().rotated(bullet_emission_angle)
