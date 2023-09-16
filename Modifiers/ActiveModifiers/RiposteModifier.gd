extends GameObjectComponent

@export var ChanceToRiposte : float = 1.0

var _attackEmitter

func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_attackEmitter = _gameObject.getChildNodeWithMethod("emit_immediate")
		_gameObject.connectToSignal("BlockedDamage", _on_damage_blocked)

func _exit_tree():
	_gameObject = null
	_attackEmitter = null

func _on_damage_blocked(_amount:int):
	if randf() <= ChanceToRiposte:
		if _attackEmitter:
			_attackEmitter.emit_immediate(true)
