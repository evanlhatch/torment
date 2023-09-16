extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var LaneDirection : Vector2 = Vector2(84, -63.65)
@export var MaxSquaredDistToTarget : float = 90000

@export_group("Viaduct Geometry Settings")
@export var LeftEdgeYOffset : float = -140.0
@export var MaxEdgeDistance : float = 1120.0
@export var MinTurningAnglePerSecond : float = 1.1
@export var MaxTurningAnglePerSecond : float = 2.3

@export_group("Scene References")
@export var ArrowsScene : PackedScene
@export var LanceScene : PackedScene
@export var ApperitionScene : PackedScene

@export_group("Audio Settings")
@export var VoiceAudio : AudioStreamPlayer2D

signal input_dir_changed(dir_vector:Vector2)

enum DirectionState { MOVING_DOWN, MOVING_UP, CHANGING_DIR}
var moving_dir_state : DirectionState

var _lane_dir_norm : Vector2
var _lane_ortho : Vector2
var _edge_gradient : float

var targetPosProvider : Node
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2

var _delayTimer : Timer
var _currentAttackPattern : int
var _action_draw_pool

func _ready():
	initGameObjectComponent()
	_lane_dir_norm = LaneDirection.normalized()
	_lane_ortho = _lane_dir_norm.rotated(PI * 0.5)
	_edge_gradient = LaneDirection.x / LaneDirection.y
	_currentAttackPattern = -1
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_delayTimer = Timer.new()
	add_child(_delayTimer)
	_action_draw_pool = createValueDrawPool([0,0,1,1,2,2])
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	moving_dir_state = DirectionState.MOVING_UP
	_update_direction(_lane_dir_norm)


func set_target(targetNode : Node):
	targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


var newInputDir : Vector2
func _process(delta):
	if is_targetProvider_valid():
		var target_dir : Vector2 = (targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition())
		var dist_to_target = get_lane_distance_sqr_to_target()
		if dist_to_target > MaxSquaredDistToTarget:
			var dotProd = target_dir.dot(input_direction)
			if dotProd < 0.0:
				if moving_dir_state == DirectionState.MOVING_UP:
					perform_turn(DirectionState.MOVING_DOWN)
				elif moving_dir_state == DirectionState.MOVING_DOWN:
					perform_turn(DirectionState.MOVING_UP)
	if moving_dir_state != DirectionState.CHANGING_DIR:
		process_attack()


func perform_turn(next_direction:DirectionState):
	VoiceAudio.play_variation()
	newInputDir = input_direction
	moving_dir_state = DirectionState.CHANGING_DIR

	var dist_to_edge = get_distance_to_edge(get_gameobjectWorldPosition())
	var turn_angle = randf_range(MinTurningAnglePerSecond, MaxTurningAnglePerSecond)
	if dist_to_edge < (MaxEdgeDistance * 0.5):
		if next_direction == DirectionState.MOVING_UP:
			turn_angle *= -1.0
	elif next_direction == DirectionState.MOVING_DOWN:
		turn_angle *= -1.0

	var current_turn_angle : float = 0.0
	while true:
		current_turn_angle += turn_angle * 0.1
		if abs(current_turn_angle) > PI: break
		newInputDir = newInputDir.rotated(turn_angle * 0.1)
		_update_direction(newInputDir)
		_delayTimer.start(0.1); await _delayTimer.timeout

	# turn complete: pick attack pattern
	match(_action_draw_pool.draw_value()):
		0: attack_pattern_A()
		1: attack_pattern_B()
		2: attack_pattern_C()

	if next_direction == DirectionState.MOVING_DOWN:
		newInputDir = -_lane_dir_norm
	elif next_direction == DirectionState.MOVING_UP:
		newInputDir = _lane_dir_norm
	moving_dir_state = next_direction
	_update_direction(newInputDir)


func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)


var _previousPosition : Vector2
var _traveledDistance : float
var _attackTriggerDistance : float
var _apperition_wait_order : float
func process_attack():
	var newPos = get_gameobjectWorldPosition()
	var posDelta = _previousPosition.distance_to(newPos)
	_previousPosition = newPos
	_traveledDistance += posDelta
	if _traveledDistance >= _attackTriggerDistance:
		_traveledDistance -= _attackTriggerDistance
		trigger_attack()


func is_targetProvider_valid():
	return targetPosProvider != null and not targetPosProvider.is_queued_for_deletion()


func get_lane_distance_sqr_to_target() -> float:
	if is_targetProvider_valid():
		var my_pos = get_gameobjectWorldPosition()
		var target_pos = targetPosProvider.get_worldPosition()
		var closest_point = Geometry2D.get_closest_point_to_segment_uncapped(
			my_pos, target_pos + _lane_ortho, target_pos - _lane_ortho)
		return my_pos.distance_squared_to(closest_point)
	return -1.0


func get_distance_to_edge(point:Vector2) -> float:
	var edge_x = (point.y - LeftEdgeYOffset) * _edge_gradient
	return point.x - edge_x


func trigger_attack():
	match _currentAttackPattern:
		0:
			var target_pos = (get_gameobjectWorldPosition() +
				_lane_ortho * randf_range(60.0, 200.0) * signf(randf_range(-1,1)))
			var arrows = ArrowsScene.instantiate()
			arrows.global_position = target_pos
			Global.attach_toWorld(arrows)
		1:
			var lance : GameObject = LanceScene.instantiate()
			var lance_component = lance.getChildNodeWithMethod("start_attack")
			var my_pos = get_gameobjectWorldPosition()
			lance.global_position = my_pos + input_direction * 130.0
			Global.attach_toWorld(lance, false)
			var lance_direction = input_direction.rotated(PI * 0.25)
			if is_targetProvider_valid():
				var target_dir = targetPosProvider.get_worldPosition() - my_pos
				if target_dir.dot(input_direction.rotated(PI * 0.5)) < 0.0:
					lance_direction = lance_direction.rotated(-PI * 0.5)
			lance_component.start_attack(lance_direction, _gameObject)
		2:
			var apperition = ApperitionScene.instantiate()
			var my_pos = get_gameobjectWorldPosition()
			apperition.global_position = positionProvider.get_worldPosition()
			Global.attach_toWorld(apperition)
			var charge_dir = input_direction.rotated(PI * 0.5)
			if is_targetProvider_valid():
				var target_dir = targetPosProvider.get_worldPosition() - my_pos
				if target_dir.dot(charge_dir) < 0.0: charge_dir *= -1.0
			var apperitionFacing = apperition.getChildNodeWithMethod("set_facingDirection")
			apperitionFacing.set_facingDirection(charge_dir)
			var apperitionInput = apperition.getChildNodeWithSignal("AttackTriggered")
			apperitionInput.WaitTime = _apperition_wait_order
			_apperition_wait_order -= 0.6


func attack_pattern_A():
	_currentAttackPattern = 0
	_traveledDistance = 0.0
	_attackTriggerDistance = 50
	_previousPosition = get_gameobjectWorldPosition()

func attack_pattern_B():
	_currentAttackPattern = 1
	_traveledDistance = 100.0
	_attackTriggerDistance = 120
	_previousPosition = get_gameobjectWorldPosition()

func attack_pattern_C():
	_currentAttackPattern = 2
	_apperition_wait_order = 3.6
	_traveledDistance = 50.0
	_attackTriggerDistance = 120
	_previousPosition = get_gameobjectWorldPosition()
