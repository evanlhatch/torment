extends EffectBase

@export var ElectrifyDamage : int = 20
@export var ElectrifyTickInterval : float = 2
@export var MaxStacks : int = 20
@export var TickTimeReduction : float = 0.9
@export var IndicatorPath : NodePath
@export var ModifierCategories : Array[String] = ["Electrify", "Elemental"]
@export var DamageCategories : Array[String] = ["Electrify"]

@export_group("internal state")
@export var _weapon_index : int = -1


var _indicator : Node
var _health_component : Node

var _tick_time : float
var _currentDuration : float
var _num_stacks : int

func get_effectID() -> String:
	return "ELECTRIFY"

func add_additional_effect(additionalEffectNode:EffectBase) -> void:
	var finalDamage : int = additionalEffectNode.ElectrifyDamage
	var externalSource : GameObject = get_externalSource()
	if externalSource != null and is_instance_valid(externalSource):
		finalDamage = floori(externalSource.calculateModifiedValue("EffectStrength", additionalEffectNode.ElectrifyDamage, ModifierCategories))
	if finalDamage > ElectrifyDamage:
		ElectrifyDamage = finalDamage

	if _num_stacks >= MaxStacks:
		_currentDuration = 0
		tick_electro_damage()
	else:
		_num_stacks += 1
		var newTickTime : float = (TickTimeReduction**(_num_stacks)) / TickTimeReduction * ElectrifyTickInterval
		if newTickTime < _currentDuration:
			_currentDuration = 0
			tick_electro_damage()
		else:
			_tick_time = newTickTime

	Global.QuestPool.notify_effect_stacks(_num_stacks, _weapon_index)



func _enter_tree():
	_indicator = get_node(IndicatorPath)
	initGameObjectComponent()
	if _gameObject:
		_health_component = _gameObject.getChildNodeWithMethod("applyDamage")
		var position_component = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if position_component != null:
			remove_child(_indicator)
			position_component.add_child(_indicator)
			_indicator.position = Vector2.ZERO
			_indicator.visible = true
		# initialize the effect even when it is the first one:
		add_additional_effect(self)


func _exit_tree():
	_gameObject = null
	_health_component = null
	if _indicator.get_parent() != self:
		_indicator.queue_free()


func _process(delta):
#ifdef PROFILING
#	updateElectrifyEffect(delta)
#
#func updateElectrifyEffect(delta):
#endif
	if _gameObject == null: return

	_currentDuration += delta
	while _currentDuration >= _tick_time:
		tick_electro_damage()
		_currentDuration -= _tick_time
		_tick_time = (TickTimeReduction**(_num_stacks)) / TickTimeReduction * ElectrifyTickInterval


func tick_electro_damage():
	if _health_component:
		var damage = ElectrifyDamage * _num_stacks
		var externalSource : GameObject = get_externalSource()
		# electro damage cannot be blocked
		var damageReturn = _health_component.applyDamage(
			damage, externalSource, false, _weapon_index, true, Health.DamageEffectType.Electrify)
		Global.QuestPool.notify_electrify_damage(damage)
		if externalSource != null and is_instance_valid(externalSource):
			externalSource.injectEmitSignal(
				"DamageApplied", [DamageCategories, damage, damageReturn, _gameObject, false])
	_num_stacks -= 1
	if _num_stacks == 0:
		queue_free()


