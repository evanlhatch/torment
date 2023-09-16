extends GameObjectComponentKinematicBody2D

@export var maxSpeed : float = 100
@export var reduceAddVelocityPerSecond : float = 10

signal MaxSpeedUpdated(newMaxSpeed:float)

var _modifiedCurrentSpeed
# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedCurrentSpeed
	]
func is_character_base_node() -> bool : return true

var _targetVelocity : Vector2
var _targetDirection : Vector2
var _targetWorldPos : Vector2 = Vector2.ZERO
var _vectorToWorldPos : Vector2
var _additionalVelocity : Vector2

func _ready():
	initGameObjectComponent()
	_modifiedCurrentSpeed = createModifiedFloatValue(maxSpeed, "MovementSpeed")
	_modifiedCurrentSpeed.connect("ValueUpdated", speedWasUpdated)
	speedWasUpdated(_modifiedCurrentSpeed.Value(), _modifiedCurrentSpeed.Value())

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedCurrentSpeed = null

func speedWasUpdated(_oldValue:float, newSpeed:float):
	_targetVelocity = _targetDirection * newSpeed
	MaxSpeedUpdated.emit(newSpeed)

func set_targetDirection(targetDir:Vector2):
	_targetDirection = targetDir
	_targetVelocity = targetDir * _modifiedCurrentSpeed.Value()

func set_targetWorldPos(targetWorldPos:Vector2):
	_targetWorldPos = targetWorldPos
	_vectorToWorldPos = targetWorldPos - get_gameobjectWorldPosition()

func get_targetVelocity() -> Vector2:
	return _targetVelocity

# only the player has the kinematic mover and we don't want to
# ever push the player around. if this intention changes, uncomment this:
# func add_velocity(addVelocity:Vector2):
# 	_additionalVelocity += addVelocity

func get_worldPosition() ->Vector2:
	return global_position

func set_worldPosition(new_position : Vector2):
	global_position = new_position

func _physics_process(delta):
#ifdef PROFILING
#	updateKinematicMover(delta)
#
#func updateKinematicMover(delta):
#endif

	if _targetWorldPos != Vector2.ZERO:
		var dirToWorldPos : Vector2 = _targetWorldPos - get_gameobjectWorldPosition()
		if dirToWorldPos.dot(_vectorToWorldPos) < 0:
			# we have moved past the world pos
			_targetVelocity = Vector2.ZERO
			_targetWorldPos = Vector2.ZERO
		else:
			_targetDirection = dirToWorldPos.normalized()
			_targetVelocity = _targetDirection * _modifiedCurrentSpeed.Value()


	if _additionalVelocity != Vector2.ZERO:
		var addVelLen = _additionalVelocity.length()
		var addVelDir = _additionalVelocity / addVelLen
		addVelLen -= delta * reduceAddVelocityPerSecond
		if addVelLen <= 0: _additionalVelocity = Vector2.ZERO
		else : _additionalVelocity = addVelDir * addVelLen
	velocity = _targetVelocity + _additionalVelocity
	move_and_slide()
