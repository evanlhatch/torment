extends GameObjectComponent

@export var Duration : float = 1

## NOTE: when this GameObject also has Health, make sure that
##       the Health Node comes before this node, so that
##       this "Killed" signal is essentially skipped!
signal Killed(byNode:Node)


var _modifiedRange
var _remainingTimeAlive : float


func _enter_tree():
	initGameObjectComponent()
	if not _gameObject:
		return
	_remainingTimeAlive = Duration
	_modifiedRange = createModifiedFloatValue(1.0, "Range")
	_modifiedRange.connect("ValueUpdated", rangeWasUpdated)
	rangeWasUpdated(1, _modifiedRange.Value())

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedRange = null

func rangeWasUpdated(oldRange:float, newRange:float):
	var durationChange = (newRange - oldRange) * Duration
	_remainingTimeAlive += durationChange

func _process(delta):
	_remainingTimeAlive -= delta
	if _remainingTimeAlive <= 0:
		var killedSignaller = _gameObject.getChildNodeWithSignal("Killed")
		killedSignaller.emit_signal("Killed", null)
		_gameObject.queue_free()
