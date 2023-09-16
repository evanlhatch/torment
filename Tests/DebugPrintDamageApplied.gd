extends GameObjectComponent


func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("DamageApplied", damageAppliedWasCalled)

func damageAppliedWasCalled(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	print("DamageApplied categories:%s amount:%f applyReturn:%s target:%s"%[damageCategories, damageAmount, applyReturn, targetNode])
