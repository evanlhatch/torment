extends GameObjectComponent2D


func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("Killed", wasKilled)


func wasKilled(_byNode:Node):
	_gameObject = null
	var globalPositionBefore = global_position
	Global.attach_toWorld(self, false)
	global_position = globalPositionBefore
	var scaleParentAndRemove = load("res://Utilities/ScaleParentToZeroAndRemove.tscn").instantiate()
	add_child(scaleParentAndRemove)
	
