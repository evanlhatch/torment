extends GameObjectComponent2D

@export var HitLocatorPools : Array[String]
@export_enum("Circle", "Rectangle", "CircleMotionInTargetDirection") var LocatorCheckType = 0
@export var CircleRadius : float = 1
@export var RectWidth : float = 5
@export var RectHeight : float = 5
@export var CircleMotionDistance : float = 1
@export var ResetCollisionsEverySeconds : float = -1

signal CollisionStarted(otherNode:Node)
signal CollisionEnded(otherNode:Node)

var _currentCollisions : Array[GameObject]
var _lastCollisions : Array[GameObject]
var _targetDirectionProvider : Node
var _remainingTimeToReset : float

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	initGameObjectComponent()
	if _gameObject != null && LocatorCheckType == 2:
		_targetDirectionProvider = _gameObject.getChildNodeWithMethod("get_targetDirection")
	_remainingTimeToReset = ResetCollisionsEverySeconds if ResetCollisionsEverySeconds > 0 else 9999999

func _process(delta):
#ifdef PROFILING
#	updateLocatorBasedCollider(delta)
#
#func updateLocatorBasedCollider(delta):
#endif
	if _gameObject == null:
		return
	_remainingTimeToReset -= delta
	if _remainingTimeToReset <= 0:
		_currentCollisions.clear()
		_remainingTimeToReset += ResetCollisionsEverySeconds if ResetCollisionsEverySeconds > 0 else 9999999
	var temp = _lastCollisions
	_lastCollisions = _currentCollisions
	_currentCollisions = temp
	_currentCollisions.clear()
	if LocatorCheckType == 0:
		collectCurrentCollisionsInCircle()
	elif LocatorCheckType == 1:
		collectCurrentCollisionsInRectangle()
	elif LocatorCheckType == 2:
		collectCurrentCollisionsInCircleMotion()
	for lastColl in _lastCollisions:
		if not is_instance_valid(lastColl):
			continue
		if not _currentCollisions.has(lastColl):
			CollisionEnded.emit(lastColl)
	for currColl in _currentCollisions:
		if not _lastCollisions.has(currColl):
			CollisionStarted.emit(currColl)


func set_locator_collider_active(active:bool):
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func collectCurrentCollisionsInCircle():
	for pool in HitLocatorPools:
		_currentCollisions.append_array(Global.World.Locators.get_gameobjects_in_circle(
			pool, global_position, CircleRadius))

func collectCurrentCollisionsInCircleMotion():
	var motionVector : Vector2 = Vector2.RIGHT * CircleMotionDistance * global_scale.x
	if _targetDirectionProvider != null:
		motionVector = _targetDirectionProvider.get_targetDirection() * CircleMotionDistance
	for pool in HitLocatorPools:
		_currentCollisions.append_array(Global.World.Locators.get_gameobjects_in_circle_motion(
					pool, global_position, CircleRadius * global_scale.x, motionVector))

func collectCurrentCollisionsInRectangle():
	var worldPos : Vector2 = global_position
	var minX : float = worldPos.x - RectWidth / 2.0
	var maxX : float = worldPos.x + RectWidth / 2.0
	var minY : float = worldPos.y - RectHeight / 2.0
	var maxY : float = worldPos.y + RectHeight / 2.0
	for pool in HitLocatorPools:
		_currentCollisions.append_array(Global.World.Locators.get_gameobjects_in_rectangle(
			pool, minX, maxX, minY, maxY))

func get_worldPosition() ->  Vector2:
	return global_position

func set_worldPosition(new_position : Vector2):
	global_position = new_position
