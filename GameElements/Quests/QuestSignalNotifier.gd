extends GameObjectComponent

@export var SignalName : String
@export var ParamCount : int = 0
@export var NotificationFunctionName : String
@export var OptionalStringParam : String = ""

func _ready():
	initGameObjectComponent()
	match(ParamCount):
		0: _gameObject.connectToSignal(SignalName, _on_signal_0)
		1: _gameObject.connectToSignal(SignalName, _on_signal_1)
		2: _gameObject.connectToSignal(SignalName, _on_signal_2)

func _on_signal_0():
	if Global.QuestPool.has_method(NotificationFunctionName):
		_perform_call()


func _on_signal_1(_param):
	if Global.QuestPool.has_method(NotificationFunctionName):
		_perform_call()


func _on_signal_2(_param1, _param2):
	if Global.QuestPool.has_method(NotificationFunctionName):
		_perform_call()


func _perform_call():
	if OptionalStringParam.is_empty():
		Global.QuestPool.call(NotificationFunctionName ,_gameObject)
	else:
		Global.QuestPool.call(NotificationFunctionName, OptionalStringParam)
