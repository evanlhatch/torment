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
@export var FireBlastScene : PackedScene

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
	_action_draw_pool = createValueDrawPool([0,0,1,1])

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
					else: _perform_attack_far_A(attackDir)
				1:
					if distance_to_target < RangedAttacksDistance: _perform_attack_B(attackDir)
					else: _perform_attack_far_B(attackDir)
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
	# monsters walk to their target and aim to their target...
	return input_direction

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

func _start_attack():
	emit_signal("AttackTriggered", 0)
	CastVoicePlayer.play_variation()
	_attackDurationTimer = AttackDuration
	if is_targetProvider_valid():
		# Skeleton Lord attacks more often when player is further away
		var repeat_time_factor = clamp(inverse_lerp(MaxDistForAttack, 32.0,
			(_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).length()),
			0.0, 1.0)
		_attackRepeatTimer = lerp(MinTimeForAttack, MaxTimeForAttack, repeat_time_factor)
	else:
		_attackRepeatTimer = randf_range(MinTimeForAttack, MaxTimeForAttack)

func _perform_attack_A(direction:Vector2):
	var increment = direction * 64.0
	var pos = positionProvider.get_worldPosition() + increment
	for i in 5:
		var blast = FireBlastScene.instantiate()
		blast.global_position = pos
		Global.attach_toWorld(blast, false)
		if blast.has_method("start"):
			blast.start(gameObject)
		pos += increment
		await get_tree().create_timer(0.1, false).timeout

func _perform_attack_far_A(direction:Vector2):
	if is_targetProvider_valid():
		var increment1 = (direction * 64.0).rotated(deg_to_rad(-30))
		var increment2 = increment1.rotated(deg_to_rad(120))
		var pos = _targetPosProvider.get_worldPosition() + direction * 24.0
		pos += increment1 * 3
		var hole_count:int = 0
		for i in range(4, -1, -1):
			var count = i + 1
			for j in count:

				# this will leave a hole in the pattern to make things a bit easier
				if hole_count < 2:
					if (i == 2 or i == 1):
						if randf_range(0.0, 1.0) > 0.6:
							hole_count += 1; continue
					elif i == 1 and j == 0 and hole_count == 0:
						continue

				var blast = FireBlastScene.instantiate()
				blast.global_position = pos + (increment2 * j)
				Global.attach_toWorld(blast, false)
				if blast.has_method("start"):
					blast.start(gameObject)
			await get_tree().create_timer(0.1, false).timeout
			pos -= increment1

func _perform_attack_B(direction:Vector2):
	var dir = direction * 180.0
	for i in 16:
		var blast = FireBlastScene.instantiate()
		blast.global_position = positionProvider.get_worldPosition() + dir
		Global.attach_toWorld(blast, false)
		if blast.has_method("start"):
			blast.start(gameObject)
		dir = dir.rotated(2 * PI / 16.0)
		await get_tree().create_timer(0.075, false).timeout

func _perform_attack_far_B(direction:Vector2):
	if is_targetProvider_valid():
		var pos1 = _targetPosProvider.get_worldPosition() + direction * 80.0
		var pos2 = pos1
		var dir1 = (direction * -50.0).rotated(deg_to_rad(40))
		var dir2 = (direction * -50.0).rotated(deg_to_rad(-40))
		pos1 += dir1 * 4.0
		pos2 += dir2 * 4.0
		for i in 4:
			var blast1 = FireBlastScene.instantiate()
			var blast2 = FireBlastScene.instantiate()
			blast1.global_position = pos1
			blast2.global_position = pos2
			Global.attach_toWorld(blast1, false)
			Global.attach_toWorld(blast2, false)
			if blast1.has_method("start"): blast1.start(gameObject)
			if blast2.has_method("start"): blast2.start(gameObject)
			pos1 -= dir1; pos2 -= dir2
			await get_tree().create_timer(0.1, false).timeout

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
