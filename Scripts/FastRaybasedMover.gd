@tool
extends GameObjectComponent2D

class_name FastRaybasedMover

@export var Radius : float = 10
@export var movementSpeed : float = 100
@export var acceleration : float = 0
@export_range(0,5) var damping : float = 0
@export_range(0,1) var startSpeedRandomizer : float = 0
@export_range(0,1) var dampingRandomizer : float = 0
@export var allowMultipleHits : bool = false
@export var alignTransformWithMovement : bool = true
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]


signal CollisionStarted(otherNode:Node)
signal CollisionEnded(otherNode:Node)
signal MovementStopped


var _randomizedDamping:float
var _randomizedSpeed:float
var _randomizedAcceleration:float

var _currentDirection:Vector2
var _currentSpeed:float
var _currentAcceleration:float
var _allTimeHitObjects : Array[GameObject]
var _currentHitObjects : Array[GameObject]
var _lastHitObjects : Array[GameObject]
var _clearLastHitObjects = false
var _emitStopped = false
var _velocity_offset = Vector2.ZERO

# func _draw() -> void:
# 	if not Engine.is_editor_hint():
# 		return

# 	draw_circle(Vector2.ZERO, Radius, Color.CORNFLOWER_BLUE)

func _ready():
	initGameObjectComponent()

	_randomizedDamping = damping + randf() * dampingRandomizer * damping
	_randomizedSpeed = movementSpeed + randf() * startSpeedRandomizer * movementSpeed
	_randomizedAcceleration = (_randomizedSpeed / movementSpeed) * acceleration

	_currentSpeed = _randomizedSpeed
	_currentAcceleration = _randomizedAcceleration

func _enter_tree():
	Global.World.FastRaybasedMoverSys.RegisterFastRaybasedMover(self)

func _exit_tree():
	Global.World.FastRaybasedMoverSys.UnregisterFastRaybasedMover(self)

func get_targetVelocity() -> Vector2:
	return (_currentDirection + _velocity_offset) * _currentSpeed

func get_velocity() -> Vector2:
	return get_targetVelocity()

func get_movement_speed() -> float:
	return _randomizedSpeed

func set_movement_speed(new_movement_speed:float):
	_currentSpeed = new_movement_speed;

func set_acceleration(new_acceleration:float):
	_currentAcceleration = new_acceleration

func set_velocity_offset(new_velocity_offset:Vector2):
	_velocity_offset = new_velocity_offset / _currentSpeed

func set_targetDirection(targetDirection:Vector2):
	_currentDirection = targetDirection
	if alignTransformWithMovement:
		var rotationFromDirection = _currentDirection.angle()
		set_rotation(rotationFromDirection)

func get_targetDirection() -> Vector2:
	return _currentDirection

func get_worldPosition() ->Vector2:
	return global_position

func set_worldPosition(pos : Vector2):
	global_position = pos

func add_velocity(_addVelocity:Vector2):
	# no external deflection for the moment...
	pass

# !!NOTE: any changes in the calculateMotion function have to also be done
# in the FastRaybasedMoverSystem.gd file _process (that function is basically
# manually inlined there...)
func calculateMotion(delta) -> Vector2:
	if _currentAcceleration > 0:
		_currentSpeed += _currentAcceleration * delta
	if _currentAcceleration < 0:
		var speedBeforePositive = _currentSpeed > 0
		_currentSpeed += _currentAcceleration * delta
		if speedBeforePositive && _currentSpeed <= 0:
			_emitStopped = true
	if _currentSpeed > 0 && _randomizedDamping > 0:
		_currentSpeed -= _currentSpeed * _randomizedDamping * delta
		if _currentSpeed < 1:
			_currentSpeed = 0
			_emitStopped = true

	if _currentSpeed == 0:
		return Vector2.ZERO

	return (_currentDirection + _velocity_offset) * _currentSpeed * delta

var _tempHits : Array[GameObject] = []
# !!NOTE: motion is updated in the FastRaybasedMoverSystem.gd file!!


func get_current_speed():
	return _currentSpeed
