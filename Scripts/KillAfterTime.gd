extends GameObjectComponent

@export var KillAfterTimer : float = 8.0
@export var KillViaInstakill : bool = true
@export var DamageCategories : Array[String] = ["Fire"]

signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)
signal Killed(byNode:Node)

var _health_component
var _timer : Timer

func _ready():
	initGameObjectComponent()
	if _gameObject:
		_health_component = _gameObject.getChildNodeWithMethod("applyDamage")
		_timer = Timer.new()
		add_child(_timer)
		_timer.connect("timeout", _on_timeout)
		_timer.start(KillAfterTimer)

func _on_timeout():
	if is_queued_for_deletion():
		return
	if _health_component:
		if KillViaInstakill:
			_health_component.instakill()
		else:
		# TODO: this doesn't incorporate defense or blockchance. 
		#       so it won't neccessarily kill! (might be that this is
		#       intentional, so i'll only leave this todo here...)
			var damage = _health_component._currentHealth
			var damageReturn = _health_component.applyDamage(damage, _gameObject, false, -1, true)
			ExternalDamageApplied.emit(DamageCategories, damage, damageReturn, _gameObject, false)
	else:
		# no health component, so we'll just trigger our own Killed signal...
		Killed.emit(null)
		if _gameObject != null and not _gameObject.is_queued_for_deletion():
			_gameObject.queue_free()
