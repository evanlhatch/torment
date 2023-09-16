extends GameObjectComponent

@export var Lifetime : float = 15.0

var targetDirectionSetter : Node
var positionProvider : Node

signal Killed(byNode)

var _startTrajectory : Vector2
var _currentTrajectory : Vector2

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")


func set_trajectory(direction:Vector2):
	_startTrajectory = direction
	_currentTrajectory = direction.rotated(deg_to_rad(-60.0))
	targetDirectionSetter.set_targetDirection(_currentTrajectory)


func _process(delta):
	if Lifetime > 0.0:
		Lifetime -= delta
		if Lifetime <= 0.0:
			Killed.emit(null)
			_gameObject.queue_free()
			return

	_currentTrajectory = _currentTrajectory.rotated(PI * 0.2 * delta)
	targetDirectionSetter.set_targetDirection(_currentTrajectory)
