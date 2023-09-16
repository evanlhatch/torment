extends Node

@export var lifeTime : float = 5
@export var DelayEndOfLifeByOneFrame : bool = false
@export var destroyWhenLifeEnded = false

var _remainingLifeTime : float
signal OnEndOfLife

func _ready():
	_remainingLifeTime = lifeTime

func _process(delta):
	if _remainingLifeTime > 0:
		_remainingLifeTime -= delta
		if _remainingLifeTime <= 0:
			endLife()


func endLife():
	if DelayEndOfLifeByOneFrame:
		await get_tree().process_frame
	emit_signal("OnEndOfLife")
	if destroyWhenLifeEnded:
		get_parent().queue_free()