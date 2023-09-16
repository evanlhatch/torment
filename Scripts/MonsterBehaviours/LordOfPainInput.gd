extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var JumpAttackAtRange : float = 200.0
@export var MaxDistForAttack : float = 180.0
@export var MinTimeForAttack : float = 0.8
@export var MaxTimeForAttack : float = 1.5
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6
@export var CharacterSprite : Node

@export_group("Scene References")
@export var GroundHitScene : PackedScene
@export var BlastSmallScene : PackedScene
@export var CurseEffectScene : PackedScene

@export_group("Difficulty Scaling")
@export var DifficultyScaleCap : float = 2.0
@export var DifficultyIncrement : float = 0.02

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
var bullet_emitter : Node

var _targetPosProvider : Node

var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool
var _stunEffect : Node

@onready var _difficulty_scale : float = 1.0
var _movementSpeedMod : Modifier
var _attackSpeedMod : Modifier
var _initial_animation_scale : float


func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	bullet_emitter = _gameObject.getChildNodeWithMethod("set_emitting")

	_initial_animation_scale = CharacterSprite.AnimationSpeed

	_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedMod.setName("Lord of Pain Movement Difficulty")
	_movementSpeedMod.setAdditiveMod(0)
	_movementSpeedMod.setMultiplierMod(0)
	_attackSpeedMod = Modifier.create("AttackSpeed", _gameObject)
	_attackSpeedMod.setName("Lord of Pain Movement Attack")
	_attackSpeedMod.setAdditiveMod(0)
	_attackSpeedMod.setMultiplierMod(0)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("AttackSpeed")

	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_action_draw_pool = createValueDrawPool([0,0,1,2,2,3,3])
	$DifficultyTimer.timeout.connect(_increase_difficulty)
	$DifficultyTimer.start()
	Global.World.notify_lord_appearance(_gameObject)

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

	if _attackDurationTimer > 0:
		_update_direction(newInputDir)
		var attFlankA = _attackDurationTimer > (AttackMoment / _difficulty_scale)
		_attackDurationTimer -= delta
		var attFlankB = _attackDurationTimer <= (AttackMoment / _difficulty_scale)
		if attFlankA and attFlankB:
			var attackDir = targetFacingSetter.get_facingDirection()
			if is_targetProvider_valid():
				attackDir = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized()
				match(current_attack_index):
					0: _perform_dash_attack(attackDir)
					1: _perform_double_dash(attackDir)
					2: _perform_ranged_attack(attackDir)
					3: _perform_carpet_bombing(attackDir)
					4: _perform_player_curse(attackDir)
		return


	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		_attackRepeatTimer -= delta
		if _attackRepeatTimer <= 0:
			if newInputDir.length() >= JumpAttackAtRange:
				current_attack_index = 0
				_start_attack(0)
			elif newInputDir.length() <= MaxDistForAttack:
				current_attack_index = _action_draw_pool.draw_value()
				if current_attack_index > 1: _start_attack(1)
				else: _start_attack(0)

		if newInputDir.length() <= StopWhenInRange:
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)


func _start_attack(attack_animation_index:int, with_min_attack_repeat : bool = false):
	# attack animation 0 is delayed and invoked by the _perform_attack routine
	if attack_animation_index > 0:
		emit_signal("AttackTriggered", attack_animation_index)
	_attackDurationTimer = AttackDuration / _difficulty_scale
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)


func _perform_dash_attack(attackDir:Vector2):
	if not is_targetProvider_valid(): return
	var target_pos = _targetPosProvider.get_worldPosition()
	var landing_position = target_pos + attackDir * 120.0
	var dash_distance = get_gameobjectWorldPosition().distance_to(landing_position)
	var blast_count = int(ceil(dash_distance / 64.0))
	var pos = get_gameobjectWorldPosition() + attackDir * 64.0
	var blast_interval = 0.3 / _difficulty_scale
	for i in range(blast_count):
		var blast = GroundHitScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast)
		if blast.has_method("start"):
			blast.start(_gameObject, 0.8)
		pos += attackDir * 64.0
		_delay_timer.start(blast_interval / blast_count); await _delay_timer.timeout
	var dash_duration = 0.6 / _difficulty_scale
	if healthComponent != null:
		healthComponent.setInvincibleForTime(dash_duration)
	positionProvider.jump_to(landing_position, dash_duration, dash_duration)
	emit_signal("AttackTriggered", 0)
	_delay_timer.start(1.0 / _difficulty_scale); await _delay_timer.timeout
	emit_signal("DashComplete")

func _perform_double_dash(attackDir:Vector2):
	_perform_dash_attack(attackDir)
	await DashComplete
	if is_targetProvider_valid():
		var secondAttackDir = (_targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized()
		_perform_dash_attack(secondAttackDir)

func _perform_ranged_attack(direction:Vector2):
	bullet_emitter.set_emitting(true)
	for i in range(8):
		_delay_timer.start(0.1)
		await _delay_timer.timeout
		bullet_emission_angle += PI * 0.04
	bullet_emitter.set_emitting(false)


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


func _perform_player_curse(direction:Vector2):
	if is_targetProvider_valid():
		var curse_bolt : GameObject = CurseEffectScene.instantiate()
		curse_bolt.set_sourceGameObject(_gameObject)
		Global.attach_toWorld(curse_bolt, false)

		var emitDir = Vector2.RIGHT
		var dirComponent = curse_bolt.getChildNodeWithMethod("set_targetDirection")
		if dirComponent:
			dirComponent.set_targetDirection(direction)

		var posComponent = curse_bolt.getChildNodeWithMethod("set_worldPosition")
		if posComponent:
			posComponent.set_worldPosition(get_gameobjectWorldPosition() + direction * 40.0)

		var targetComponent = curse_bolt.getChildNodeWithMethod("set_homing_target")
		if targetComponent:
			targetComponent.set_homing_target(_targetPosProvider)


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
