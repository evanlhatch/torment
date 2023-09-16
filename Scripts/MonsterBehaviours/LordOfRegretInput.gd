extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var MaxDistForAttack : float = 220.0
@export var MinTimeForAttack : float = 0.8
@export var MaxTimeForAttack : float = 1.5
@export var AttackDuration : float = 1.2
@export var AttackMoment : float = 0.6
@export var CharacterSprite : Node
@export var MaxLavaBombs : int = 50

@export_group("Emitter References")
@export var BulletEmitter : Node
@export var FirewallEmitter : Node

@export_group("Scene References")
@export var GroundHitScene : PackedScene
@export var BlastSmallScene : PackedScene
@export var CurseEffectScene : PackedScene
@export var GhostlyHandsScene : PackedScene
@export var ThrownSwordScene : PackedScene
@export var LavaBombRaiseScene : PackedScene

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

var _is_killed : bool
var spawned_bombs : Array[GameObject]
var spawned_swords : Array[GameObject]

@onready var _difficulty_scale : float = 1.0
var _movementSpeedMod : Modifier
var _attackSpeedMod : Modifier
var _initial_animation_scale : float


func _ready():
	initGameObjectComponent()
	spawned_bombs = []
	spawned_swords = []
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
	_action_draw_pool = createValueDrawPool([0,0,0,1,1,1,2,3,3,4,4], [2])
	_gameObject.connectToSignal("Killed", _on_killded)

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
					0: _perform_sword_throw(attackDir)
					1: _perform_ranged_attack(attackDir)
					2:
						if len(spawned_bombs) < MaxLavaBombs: _perform_mining(attackDir)
						else: current_attack_index += randi_range(3,4)
						if current_attack_index == 3: _perform_wave_attack(attackDir)
						else: _perform_delta_attack(attackDir)
					3: _perform_wave_attack(attackDir)
					4: _perform_delta_attack(attackDir)
		return

	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		_attackRepeatTimer -= delta
		if _attackRepeatTimer <= 0:
			if newInputDir.length() <= MaxDistForAttack:
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
	# attack animation 0 is delayed and invoked by the _perform_fire_wave
	if attack_animation_index > 0:
		emit_signal("AttackTriggered", attack_animation_index)
	_attackDurationTimer = AttackDuration / _difficulty_scale
	if with_min_attack_repeat: _attackRepeatTimer = MinTimeForAttack
	else: _attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)


func _perform_ranged_attack(direction:Vector2):
	BulletEmitter.set_emitting(true)
	bullet_emission_angle = -0.08
	var sweep_interval = 0.1 / _difficulty_scale
	for i in range(10):
		_delay_timer.start(sweep_interval)
		await _delay_timer.timeout
		bullet_emission_angle += PI * 0.04
	BulletEmitter.set_emitting(false)

func _perform_sword_throw(direction:Vector2):
	emit_signal("AttackTriggered", 0)
	_delay_timer.start(0.25 / _difficulty_scale)
	await _delay_timer.timeout
	var sword_count : int = 1
	if _difficulty_scale > 1.33: sword_count += 1
	if _difficulty_scale > 1.85: sword_count += 1
	for c in sword_count:
		var sword : GameObject = ThrownSwordScene.instantiate()
		spawned_swords.append(sword)
		sword.connectToSignal("Killed", _on_sword_killed)
		Global.attach_toWorld(sword, false)
		var sword_speed = sword.getChildNodeWithMethod("set_movement_percent_bonus")
		if is_instance_valid(sword_speed):
			sword_speed.set_movement_percent_bonus((_difficulty_scale - 1.0) * 0.8)
		var swordPosition = sword.getChildNodeWithMethod("set_worldPosition")
		swordPosition.set_worldPosition(
			positionProvider.get_worldPosition() + direction * 32.0)
		var swordInput = sword.getChildNodeWithMethod("set_trajectory")
		swordInput.set_trajectory(direction.rotated(-0.5 * float(c)))


func _perform_mining(direction:Vector2):
	var spawn_interval = 0.15 / _difficulty_scale
	for i in range(floori(3.0 * _difficulty_scale)):
		if _is_killed: return
		var offset = direction * ((i + 2) * 120.0)
		var angle_increment = PI * (0.7 / float(3 + i * 2)) + (PI * 0.35)
		for j in range(3 + i * 2):
			var pos = get_gameobjectWorldPosition() + offset.rotated(j * angle_increment + randf_range(-0.5, 0.5))
			var bomb_raising = LavaBombRaiseScene.instantiate()
			Global.attach_toWorld(bomb_raising)
			bomb_raising.raise(pos, Vector2.ZERO)
			bomb_raising.object_spawned.connect(_on_lava_bomb_spawned, CONNECT_ONE_SHOT)
		await get_tree().create_timer(spawn_interval, false).timeout

func _perform_wave_attack(direction:Vector2):
	var wave_dir = direction * 40.0 * _difficulty_scale
	var angle : float = 0.0
	var pos = get_gameobjectWorldPosition()
	var blast_interval = 0.075 / _difficulty_scale
	for i in range(20):
		angle = (PI * 0.3 * _difficulty_scale) * sin(i)
		pos += wave_dir.rotated(angle)
		var blast = BlastSmallScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast)
		if blast.has_method("start"):
			blast.start(_gameObject)
		await get_tree().create_timer(blast_interval, false).timeout

func _perform_delta_attack(direction:Vector2):
	var third_branch : bool = _difficulty_scale >= 1.5
	var rotation_factor = 0.15 if third_branch else 0.1
	var delta_dir_left = direction.rotated(PI * rotation_factor) * 40.0
	var delta_dir_right = direction.rotated(PI * -rotation_factor) * 40.0
	var delta_dir_center = direction  * 40.0
	var pos = get_gameobjectWorldPosition()
	var blast_interval = 0.075 / _difficulty_scale
	for i in range(20):
		if len(spawned_bombs) >= MaxLavaBombs: break
		var blast_left = BlastSmallScene.instantiate()
		var blast_right = BlastSmallScene.instantiate()
		var blast_center = null
		blast_left.global_position = pos + delta_dir_left * (i + 3)
		blast_right.global_position = pos + delta_dir_right * (i + 3)
		Global.attach_toWorld(blast_left)
		Global.attach_toWorld(blast_right)
		if blast_left.has_method("start"): blast_left.start(_gameObject)
		if blast_right.has_method("start"): blast_right.start(_gameObject)
		if third_branch:
			blast_center = BlastSmallScene.instantiate()
			blast_center.global_position = pos + delta_dir_center * (i + 3)
			Global.attach_toWorld(blast_center)
			if blast_center.has_method("start"): blast_center.start(_gameObject)
		await get_tree().create_timer(blast_interval, false).timeout

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


func _on_lava_bomb_spawned(spawned_bomb:GameObject):
	spawned_bombs.append(spawned_bomb)
	spawned_bomb.connectToSignal("Killed", _on_lava_bomb_killed)


func _on_lava_bomb_killed(lava_bomb:GameObject):
	if _is_killed: return
	if spawned_bombs.has(lava_bomb):
		spawned_bombs.erase(lava_bomb)


func _on_sword_killed(sword:GameObject):
	if _is_killed: return
	if spawned_swords.has(sword):
		spawned_swords.erase(sword)


func _on_killded(_killed_by:Node):
	_is_killed = true
	for s in spawned_swords:
		if is_instance_valid(s):
			s.injectEmitSignal("Killed", [s])
			s.queue_free()
	for b in spawned_bombs:
		if is_instance_valid(b):
			b.injectEmitSignal("Killed", [b])
			b.queue_free()
			await get_tree().create_timer(0.1).timeout
