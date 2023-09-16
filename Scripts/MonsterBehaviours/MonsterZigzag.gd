extends Node

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var ZigZagAngle : float = 30.0
@export var WaitDuration : float = 0.6
@export var MoveDuration : float = 0.7

var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var _delay_timer : Timer
var _angle : float

func _ready():
	positionProvider = get_parent().getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = get_parent().getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = get_parent().getChildNodeWithMethod("set_facingDirection")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	add_child(_delay_timer)
	_delay_timer.connect("timeout", change_direction)
	_delay_timer.start(WaitDuration + randf_range(0.0, 0.4))
	_angle = ZigZagAngle


func change_direction():
	if input_direction.length_squared() > 0.1:
		input_direction = Vector2.ZERO
		_delay_timer.start(WaitDuration)
	elif is_targetProvider_valid():
		input_direction = (
			_targetPosProvider.get_worldPosition() - positionProvider.get_worldPosition()
			).normalized()
		input_direction = input_direction.rotated(deg_to_rad(_angle))
		_angle *= -1.0
		_delay_timer.start(MoveDuration)
	emit_signal("input_dir_changed", input_direction)
	targetDirectionSetter.set_targetDirection(input_direction)


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	# monsters walk to their target and aim to their target...
	return input_direction

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
