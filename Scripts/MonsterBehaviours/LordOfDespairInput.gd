extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var MaxDistForAttack : float = 220.0
@export var MinTimeForAttack : float = 0.8
@export var MaxTimeForAttack : float = 1.5
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6
@export var CharacterSprite : Node

@export_group("Viaduct Geometry")
@export var ViaductVector : Vector2 = Vector2(84, -64)

@export_group("Emitter References")
@export var BulletEmitter : Node
@export var FirewallEmitter : Node

@export_group("Scene References")
@export var BlastSmallScene : PackedScene
@export var CurseEffectScene : PackedScene
@export var GhostlyHandsScene : PackedScene
@export var MarchinGhostsNE : PackedScene
@export var MarchinGhostsSW : PackedScene
@export var LanceScene : PackedScene
@export var SmallExplosionHit : PackedScene

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

var _targetPosProvider : Node

var _curse_effect_prototype : EffectBase
var _attackRepeatTimer : float
var _attackDurationTimer : float
var _delay_timer : Timer
var _action_draw_pool
var _stunEffect : Node

var viaduct_dir_ortho :  Vector2

@onready var _difficulty_scale : float = 1.0
var _movementSpeedMod : Modifier
var _attackSpeedMod : Modifier
var _initial_animation_scale : float

func _ready():
	initGameObjectComponent()
	viaduct_dir_ortho = ViaductVector.normalized().rotated(deg_to_rad(90))
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_curse_effect_prototype = CurseEffectScene.instantiate()
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2,3,3,4,4])
	_attackRepeatTimer = 3

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
	$DifficultyTimer.timeout.connect(_increase_difficulty)
	$DifficultyTimer.start()
	Global.World.notify_lord_appearance(_gameObject)

func _exit_tree():
	if _curse_effect_prototype != null:
		_curse_effect_prototype.queue_free()
		_curse_effect_prototype = null


func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		_stunEffect = node


func _increase_difficulty():
	if _difficulty_scale >= DifficultyScaleCap:
		$DifficultyTimer.queue_free()
		return
	_difficulty_scale += DifficultyIncrement
	CharacterSprite.AnimationSpeed = _initial_animation_scale * _difficulty_scale
	_movementSpeedMod.setMultiplierMod((_difficulty_scale - 1.0) * 0.7)
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
					0: _summon_ghosts_NE()
					1: _summon_ghosts_SW()
					2: _summon_lances()
					3: _perform_wave_attack(attackDir)
					4: _summon_ghost_hands(attackDir)
		return

	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		_attackRepeatTimer -= delta
		if _attackRepeatTimer <= 0:
			if newInputDir.length() <= MaxDistForAttack:
				current_attack_index = _action_draw_pool.draw_value()
				_start_attack(0)

		if newInputDir.length() <= StopWhenInRange:
			targetFacingSetter.set_facingDirection(newInputDir)
			newInputDir = Vector2.ZERO
		else:
			newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)


func _start_attack(attack_animation_index:int, with_min_attack_repeat : bool = false):
	AttackTriggered.emit(0)
	_attackDurationTimer = AttackDuration / _difficulty_scale
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)


func _perform_ranged_attack(direction:Vector2):
	BulletEmitter.set_emitting(true)
	bullet_emission_angle = -0.08
	for i in range(10):
		_delay_timer.start(0.1)
		await _delay_timer.timeout
		bullet_emission_angle += PI * 0.04
	BulletEmitter.set_emitting(false)

func _summon_ghosts_NE():
	var spawn_interval = 0.22 / _difficulty_scale
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		var spawn_v_offset = ViaductVector.normalized() * -300
		for i in 8:
			var spawn_h_offset = viaduct_dir_ortho * randf_range(-360, 360)
			var ghost = MarchinGhostsNE.instantiate()
			ghost.global_position = targetPos + spawn_v_offset + spawn_h_offset
			Global.attach_toWorld(ghost)
			_delay_timer.start(spawn_interval); await _delay_timer.timeout

func _summon_ghosts_SW():
	var spawn_interval = 0.22 / _difficulty_scale
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		var spawn_v_offset = ViaductVector.normalized() * 300
		for i in roundi(8.0 * _difficulty_scale):
			var spawn_h_offset = viaduct_dir_ortho * randf_range(-360, 360)
			var ghost = MarchinGhostsSW.instantiate()
			ghost.global_position = targetPos + spawn_v_offset + spawn_h_offset
			Global.attach_toWorld(ghost)
			_delay_timer.start(spawn_interval); await _delay_timer.timeout

func _summon_lances():
	var spawn_interval = 0.22 / _difficulty_scale
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		var spawn_h_offset = viaduct_dir_ortho.normalized() * 200
		var viaduct_dir = ViaductVector.normalized()
		var spawn_v_offset = viaduct_dir * -320
		for i in roundi(8.0 * _difficulty_scale):
			spawn_h_offset *= -1.0
			spawn_v_offset += viaduct_dir * 80
			var lance = LanceScene.instantiate()
			lance.global_position = targetPos + spawn_v_offset + spawn_h_offset
			Global.attach_toWorld(lance, false)
			var lance_input = lance.getChildNodeWithMethod("start_attack")
			lance_input.start_attack(-viaduct_dir_ortho * ((float)(i % 2) - 0.5) * 2.0, _gameObject)
			_delay_timer.start(spawn_interval); await _delay_timer.timeout


func _perform_wave_attack(direction:Vector2):
	var wave_dir = direction * 50.0 * _difficulty_scale
	var angle : float = 0.0
	var pos = get_gameobjectWorldPosition()
	var spawn_interval = 0.075 / _difficulty_scale
	for i in range(20):
		angle = (PI * 0.33 * _difficulty_scale) * sin(i)
		pos += wave_dir.rotated(angle)
		var blast = BlastSmallScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast)
		if blast.has_method("start"):
			blast.start(_gameObject)
		await get_tree().create_timer(spawn_interval, false).timeout

func _summon_ghost_hands(direction:Vector2):
	var spawn_interval = 0.33 / _difficulty_scale
	if is_targetProvider_valid():
		var start_offsets = []
		var offset_vector = Vector2.RIGHT.rotated(randf_range(-PI, PI))
		for i in range(6):
			start_offsets.append(offset_vector)
			offset_vector = offset_vector.rotated(PI * 0.333)

		while len(start_offsets) > 0:
			if not is_targetProvider_valid(): break
			var offset = start_offsets.pop_at(randi_range(0, len(start_offsets)-1))
			var hand : GameObject = GhostlyHandsScene.instantiate()
			var pos = _targetPosProvider.get_worldPosition() + offset * 280
			Fx.show_custom_effect(SmallExplosionHit, pos, Vector2.RIGHT)
			hand.global_position = pos
			Global.attach_toWorld(hand)
			hand.set_sourceGameObject(_gameObject)
			var dirComponent = hand.getChildNodeWithMethod("set_targetDirection")
			if dirComponent:
				dirComponent.set_targetDirection(-offset)
			await get_tree().create_timer(spawn_interval, false).timeout

func _perform_player_curse():
	if is_targetProvider_valid():
		var player_go = Global.get_gameObject_in_parents(_targetPosProvider)
		player_go.add_effect(_curse_effect_prototype, _gameObject)


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
