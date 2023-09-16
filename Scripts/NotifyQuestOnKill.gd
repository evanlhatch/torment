extends GameObjectComponent

@export var NotifyFunctionName : String
@export var NotifyParameter : String

var notify_function : Callable

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Killed", _on_killed_received)
	notify_function = Callable(Global.QuestPool, NotifyFunctionName)


func _on_killed_received(_byNode:Node):
	if notify_function.is_valid():
		notify_function.call(NotifyParameter)
