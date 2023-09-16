extends GameObjectComponent2D

@export var BlastSoundVolume : float = -4.0
@export var BaseRange : float = 200
@export var BaseSpeed : float = 150
@export var MaxHeight : float = 100
@export var KillOnArrival : bool = true
@export var StartBallisticMotionOnReady : bool = false

signal Killed(byNode:Node)

var _duration : float
var _currentMovementTime : float
var _startPosition : Vector2
var _totalMovement : Vector2
var _velocityDir : Vector2

var _modifiedRange : ModifiedFloatValue
var _modifiedSpeed : ModifiedFloatValue

var _shadowNode : Node2D
var _spriteNode : Node2D

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	_startPosition = Vector2.INF
	_totalMovement = Vector2.INF
	_velocityDir = Vector2.INF
	process_mode = Node.PROCESS_MODE_DISABLED
	_currentMovementTime = 0

	_modifiedRange = createModifiedFloatValue(BaseRange, "Range")
	_modifiedRange.ValueUpdated.connect(ballisticsWereUpdated)
	_modifiedSpeed = createModifiedFloatValue(BaseSpeed, "MovementSpeed")
	_modifiedSpeed.ValueUpdated.connect(ballisticsWereUpdated)

	_spriteNode = $Sprite
	_shadowNode = $Shadow

	if StartBallisticMotionOnReady:
		# the velocityDir has to be random in this case!
		_velocityDir = Vector2.from_angle(randf_range(0, 2.0 * PI))
		_startPosition = global_position
		start_ballistic_motion_via_range()

func ballisticsWereUpdated(previousValue:float, currentValue:float):
	start_ballistic_motion_via_range()

func set_velocity_offset(new_velocity_offset:Vector2):
	pass # we could add the velocity to the motion,
	# making throwing things fun

func set_targetDirection(targetDirection:Vector2):
	_velocityDir = targetDirection
	start_ballistic_motion_via_range()

func get_targetDirection() -> Vector2:
	if _velocityDir == Vector2.INF: return Vector2.ZERO
	return _velocityDir

func get_worldPosition() ->Vector2:
	return global_position

func set_worldPosition(pos : Vector2):
	global_position = pos
	_startPosition = pos
	start_ballistic_motion_via_range()

func add_velocity(_addVelocity:Vector2):
	pass # no external deflection for the moment...

func get_speed() -> float:
	return _modifiedSpeed.Value()

func start_ballistic_motion(start_pos: Vector2, target_position:Vector2, overrideDuration:float = -1):
	_startPosition = start_pos
	_velocityDir = target_position - _startPosition
	_totalMovement = _velocityDir
	var distance = _velocityDir.length()
	_velocityDir /= distance
	if overrideDuration > 0:
		_duration = overrideDuration
	else:
		_duration = distance / _modifiedSpeed.Value()
	# we'll set our own position to the target position and move
	# the animated objects towards that
	global_position = _startPosition + _totalMovement
	_shadowNode.global_position = _startPosition
	_spriteNode.global_position = _startPosition
	# and kick off the movement!
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return _duration

func start_ballistic_motion_via_range():
	if _startPosition == Vector2.INF or _velocityDir == Vector2.INF:
		return 0 # not all values available, yet
	_totalMovement = _velocityDir * _modifiedRange.Value()
	_duration = _modifiedRange.Value() / _modifiedSpeed.Value()
	# we'll set our own position to the target position and move
	# the animated objects towards that
	global_position = _startPosition + _totalMovement
	_shadowNode.global_position = _startPosition
	_spriteNode.global_position = _startPosition
	# and kick off the movement!
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return _duration

func _process(delta):
	_currentMovementTime += delta
	var movementFactor := clampf(_currentMovementTime / _duration, 0, 1)
	var horizontalPosition := _startPosition + _totalMovement * movementFactor
	_shadowNode.global_position = horizontalPosition

	var parabolaFactor := 2.0 * (movementFactor - 0.5)
	parabolaFactor *= parabolaFactor
	parabolaFactor = 1.0 - parabolaFactor
	var verticalPosition := MaxHeight * parabolaFactor
	_spriteNode.global_position = horizontalPosition + Vector2.UP * verticalPosition

	if KillOnArrival and movementFactor == 1:
		var killedSignaller = _gameObject.getChildNodeWithSignal("Killed")
		killedSignaller.emit_signal("Killed", null)
		_gameObject.queue_free()


func calculateMotion(delta) -> Vector2:
	# this is normally used to offset the start position slightly
	# so that the position is exact, no matter the framerate.
	# since we calculate our position based on total elapsed time,
	# we can just use this delta to offset our _currentMovementTime!
	_currentMovementTime += delta
	# but changing the start position would in this case not be correct!
	return Vector2.ZERO
