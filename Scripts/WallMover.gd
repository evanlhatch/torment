@tool
extends GameObjectComponent2D

@export var Radius : float = 10
@export var Width : float = 50
@export var movementSpeed : float = 100
@export var acceleration : float = 0
@export_range(0,5) var damping : float = 0
@export var allowMultipleHits : bool = false
@export var alignTransformWithMovement : bool = true
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var ModifierCategories : Array[String] = ["Physical"]

var _modifiedWidth
var _modifiedRadius

signal CollisionStarted(otherNode:Node)
signal CollisionEnded(otherNode:Node)
signal MovementStopped


var _currentDirection:Vector2
var _currentSpeed:float
var _allTimeHitObjects = []
var _currentHitObjects = []
var _lastHitObjects = []
var _clearLastHitObjects = false
var _emitStopped = false

# func _draw() -> void:
# 	if not Engine.is_editor_hint():
# 		return

# 	draw_circle(Vector2.DOWN * Width/2.0, Radius, Color.CORNFLOWER_BLUE)
# 	draw_circle(Vector2.UP * Width/2.0, Radius, Color.CORNFLOWER_BLUE)
# 	draw_line(Vector2.DOWN * Width/2.0, Vector2.UP * Width/2.0, Color.BLUE)

func _ready():
	initGameObjectComponent()
	_currentSpeed = movementSpeed
	if _gameObject != null:
		initialize_modifiers(self)

func initialize_modifiers(referenceParent):
	_modifiedWidth = referenceParent.createModifiedIntValue(Width, "Area")
	_modifiedRadius = referenceParent.createModifiedIntValue(Radius, "Area")
	applyModifierCategories()

func applyModifierCategories():
	_modifiedWidth.setModifierCategories(ModifierCategories)
	_modifiedRadius.setModifierCategories(ModifierCategories)

func get_totalWidth() -> float: return _modifiedWidth.Value()
func get_totalRadius() -> float: return _modifiedRadius.Value()


func get_targetVelocity() -> Vector2:
	return _currentDirection * _currentSpeed

func get_velocity() -> Vector2:
	return get_targetVelocity()

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
	pass # no external deflection for the moment...

func _process(delta):
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if _gameObject == null:
		return

	update_motion(delta)

	for node in _lastHitObjects:
		if node == null || node.is_queued_for_deletion():
			continue # do not trigger signals for deleted nodes!
		if not node in _currentHitObjects:
			if not node in _allTimeHitObjects:
				_allTimeHitObjects.append(node)
			_currentHitObjects.append(node)
			emit_signal("CollisionStarted", node)
		# else would be CollisionStay...
	for i in range(_currentHitObjects.size() - 1, -1, -1):
		var node = _currentHitObjects[i]
		if node == null || node.is_queued_for_deletion():
			_currentHitObjects.remove_at(i)
			continue # do not trigger signals for deleted nodes!
		if not node in _lastHitObjects:
			emit_signal("CollisionEnded", node)
			_currentHitObjects.remove_at(i)
	_clearLastHitObjects = true
	if _emitStopped:
		emit_signal("MovementStopped")
		_emitStopped = false

func calculateMotion(delta) -> Vector2:
	if acceleration > 0:
		_currentSpeed += acceleration * delta
	if acceleration < 0:
		var speedBeforePositive = _currentSpeed > 0
		_currentSpeed += acceleration * delta
		if speedBeforePositive && _currentSpeed <= 0:
			_emitStopped = true
	if _currentSpeed > 0 && damping > 0:
		_currentSpeed -= _currentSpeed * damping * delta
		if _currentSpeed < 1:
			_currentSpeed = 0
			_emitStopped = true

	if _currentSpeed == 0:
		return Vector2.ZERO

	return _currentDirection * _currentSpeed * delta

var _tempHits : Array[GameObject] = []
func update_motion(delta):
	if _gameObject == null:
		return
	if _clearLastHitObjects:
		_lastHitObjects.clear()
		_clearLastHitObjects = false
	_tempHits.clear()

	var scaledRadius : float = get_totalRadius()
	scaledRadius *= global_scale.x
	var wallStartPos = global_position + Vector2.UP.rotated(global_rotation) * get_totalWidth()/2.0 * global_scale.y
	var wallWidthVector = (Vector2.DOWN * global_scale.y * get_totalWidth()).rotated(global_rotation)
	for pool in HitLocatorPools:
		_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle_motion(pool, wallStartPos, scaledRadius, wallWidthVector))
	for hitGameObj in _tempHits:
		if not allowMultipleHits && hitGameObj in _allTimeHitObjects:
			continue
		if hitGameObj in _lastHitObjects:
			continue
		_lastHitObjects.append(hitGameObj)
	global_position += calculateMotion(delta)
