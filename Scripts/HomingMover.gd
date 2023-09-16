@tool
extends GameObjectComponent2D

@export_group("Lifetime Settings")
@export var EndLifeAfterArrival : bool = true
@export var DestroyWhenLifeEnded : bool = true
@export var Lifetime : float = 5 # if -1: lifetime is unlimited
@export var DestroyWhenTargetLost : bool = false

@export_group("Motion Settings")
@export var Speed : float = 200
@export var ArrivalDistance : float = 8
@export var Acceleration = 1.5
@export_exp_easing("inout") var directionEase : float
@export_exp_easing("inout") var speedEase : float

@export_group("Collision Settings")
@export var shape : Shape2D
@export var AllowMultipleHits : bool = false
@export_flags_2d_physics var collisionMask = 0xFFFFFFFF

signal MotionStarted
signal CollisionStarted(otherNode:Node)
signal CollisionEnded(otherNode:Node)
signal OnArrived
signal OnEndOfLife

var _motion_started : bool = false
var _follow_target : WeakRef

var _start_dir : Vector2
var _mov_dir : Vector2
var _last_target_pos : Vector2 = Vector2.INF
var _timeFactor = 0
var _direction_factor = 0
var _currentSpeed = 0

var _allTimeHitObjects = []
var _lastHitObjects = []
var _clearLastHitObjects = false

#func _draw() -> void:
#	if not Engine.is_editor_hint():
#		return
#	if shape == null:
#		return
	#shape.draw(get_canvas_item(), Color.CORNFLOWER_BLUE)

func _ready():
	initGameObjectComponent()
	process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta):
	#if Engine.is_editor_hint():
	#	queue_redraw()
	#	return
#ifdef PROFILING
#	updateHomingMover(delta)
#
#func updateHomingMover(delta):
#endif
	if not _motion_started:
		return

	if _timeFactor < 1:
		_timeFactor = clamp(_timeFactor + delta * Acceleration, 0, 1)
		_currentSpeed = ease(_timeFactor, speedEase) * Speed
		_direction_factor = ease(_timeFactor, directionEase)

	if _follow_target:
		var target = _follow_target.get_ref()
		if target:
			if _direction_factor >= 0.9:
				if target.global_position.distance_squared_to(_last_target_pos) >= ArrivalDistance*ArrivalDistance:
					var target_dir = (target.global_position - global_position).normalized()
					_mov_dir = target_dir
					_last_target_pos = target.global_position

			var motion = _mov_dir * _currentSpeed * delta
			global_position += motion

			if _direction_factor >= 0.9:
				# did we overshoot the target?
				var new_dir_vec : Vector2 = target.global_position - global_position
				if new_dir_vec.dot(_mov_dir) < 0:
					# yes, we did!
					global_position = target.global_position
	elif DestroyWhenTargetLost:
		queue_free()
		return


	if Lifetime > -1:
		Lifetime -= delta
		if Lifetime <= 0:
			_end_life()
	_check_arrival()


func start_motion_with_target(target : Node2D, startDirection : Vector2):
	_start_dir = startDirection.normalized()
	_mov_dir = _start_dir
	_follow_target = weakref(target)
	_motion_started = true
	MotionStarted.emit()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _check_arrival():
	if not _follow_target: return
	var target = _follow_target.get_ref()
	if target and global_position.distance_squared_to(target.global_position) < ArrivalDistance * ArrivalDistance:
		OnArrived.emit()
		if EndLifeAfterArrival:
			_end_life()

func _end_life():
	OnEndOfLife.emit()
	if DestroyWhenLifeEnded:
		get_parent().queue_free()

func get_worldPosition() -> Vector2:
	return global_position
