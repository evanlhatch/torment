extends GameObjectComponent

@export var MaxDistForReset : float = 200.0
@export var MinTimeTillReset : float = 3.5
@export var MaxTimeTillReset : float = 4.5
@export var MinDistForRangedAttack : float = 100.0
@export var TrailPositionInterval : float = 0.25
@export var BodyLength : int = 8

@export_group("Node References")
@export var HeadSprite : Node
@export var RubbelFX : Node2D

@export_group("Scene References")
@export var BodyScene : PackedScene
@export var VolcanoProjectile : PackedScene

const PI_INV : float = 1.0 / PI
const PI_HALVE : float = PI * 0.5

signal input_dir_changed(dir_vector:Vector2)

var _targetPosProvider : Node

var healthComponent : Node
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var aoeComponent : Node
var input_direction : Vector2

var _circleResetTimer : float
var _trail_timer : Timer
var _action_draw_pool
var _circling_angle : float
var _steering_angle : float

var _head_height_time : float
var _head_height : float

var _tail_element : Node

@onready var body_part_inputs : Array[Node] = []

func _ready():
	initGameObjectComponent()
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	aoeComponent = _gameObject.getChildNodeWithMethod("set_harmless")
	healthComponent.Killed.connect(on_killed)
	if (Global.World.Player != null and not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_trail_timer = Timer.new()
	add_child(_trail_timer)
	_trail_timer.timeout.connect(_on_trail_timer_timeout)
	_trail_timer.start(TrailPositionInterval)

var _distance_to_player : float
func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	
	var attackDir = targetFacingSetter.get_facingDirection()
	if is_targetProvider_valid():
		attackDir = (_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()).normalized()
	
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		var direction_to_player = targetPos - positionProvider.get_worldPosition()
		newInputDir = get_circling_input_dir(direction_to_player)
		_circling_angle += delta * PI * 0.1
		_head_height_time += delta
		_steering_angle = sin(_head_height_time)
		# make sure wyrm spends more time over ground than submerged
		_head_height = clamp((cos(_head_height_time) + 0.6) * 1.4, 0.0, 0.9)
		_distance_to_player = direction_to_player.length()
		if _distance_to_player <= MaxDistForReset:
			_circleResetTimer -= delta
			if _circleResetTimer <= 0:
				_circleResetTimer = randf_range(MinTimeTillReset, MaxTimeTillReset)
				_circling_angle = 0.0
		newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)
	_update_submersion()


func get_circling_input_dir(direction_to_player:Vector2) -> Vector2:
	var vector_from_player = (-direction_to_player).normalized() * 160.0
	vector_from_player = vector_from_player.rotated(_circling_angle)
	return (direction_to_player + vector_from_player).rotated(_steering_angle)


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


var _is_submerged : bool
func _update_submersion():
	if not _is_submerged and _head_height < 0.5:
		_is_submerged = true
		aoeComponent.set_harmless(true)
		healthComponent.setInvincibleForTime(10.0)
	elif _is_submerged and _head_height >= 0.5:
		_is_submerged = false
		aoeComponent.set_harmless(false)
		healthComponent.setInvincibleForTime(-1.0)
		if _distance_to_player > MinDistForRangedAttack:
			emit_projectiles()
	HeadSprite.material.set_shader_parameter("submerge", _head_height)
	HeadSprite.position.y = _head_height * -12.0
	RubbelFX.scale = Vector2.ONE * sin(clamp(_head_height * PI, 0.0, PI_HALVE))


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()


func on_killed(by_node : Node):
	var kill_time : float = 0.2
	for b in body_part_inputs:
		b.kill(kill_time, by_node)
		kill_time += 0.1


func _on_trail_timer_timeout():
	if BodyLength > 0:
		var body_element = BodyScene.instantiate()
		Global.attach_toWorld(body_element)
		var body_element_input = body_element.getChildNodeWithMethod("set_target_element")
		body_part_inputs.append(body_element_input)
		if _tail_element == null:
			body_element_input.set_target_element(positionProvider, self)
			body_element.getChildNodeWithMethod("set_worldPosition").set_worldPosition(
				positionProvider.get_worldPosition())
		else:
			var target_input = _tail_element._gameObject.getChildNodeWithMethod("set_target_element")
			body_element_input.set_target_element(_tail_element, target_input)
			body_element.getChildNodeWithMethod("set_worldPosition").set_worldPosition(
				_tail_element.get_worldPosition())
		_tail_element = body_element.getChildNodeWithMethod("set_worldPosition")
		BodyLength -= 1
	else:
		_trail_timer.stop()

func emit_projectiles():
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
		target_pos += (Vector2.ONE * randf_range(-80.0, 80.0)).rotated(randf_range(-PI, PI))
		p.start_ballistic_motion(pos, target_pos)
