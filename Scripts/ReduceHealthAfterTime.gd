extends GameObjectComponent

@export var initialWaitTime : float = 1.5
@export var timePerReduction : float = 5
@export var healthPerReduction : int = 1500
@export var delayByOneFrame : bool = false

var _reimainingTime : float
signal OnEndOfLife

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	_reimainingTime = initialWaitTime

func _process(delta):
	if _reimainingTime > 0:
		_reimainingTime -= delta
		if _reimainingTime <= 0:
			_reimainingTime += timePerReduction
			reduceHealth()


func reduceHealth():
	if delayByOneFrame:
		await get_tree().process_frame
	var healthProvider = _gameObject.getChildNodeWithMethod("get_maxHealth")
	if healthProvider != null:
		if healthProvider.get_health() <= healthPerReduction:
			emit_signal("OnEndOfLife")
			get_parent().queue_free()
		else:
			healthProvider.reduce_health(healthPerReduction)
