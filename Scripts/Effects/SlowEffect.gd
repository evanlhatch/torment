extends EffectBase

@export var SlowDuration : float = 3.0
@export var SlowDownSpeedMultiplierTarget : float = 0.1
@export var MaxStacks : int = 20
@export var SlowIndicatorPath : NodePath

@export_group("internal state")
@export var _weapon_index : int = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _slow_indicator : Node
var _health_component : Node

var _currentStackTime : float = 0
var _currentDuration : float = 0
var _num_stacks : int = 0
var _movementSpeedMod : Modifier

func get_effectID() -> String:
	return "SLOW"

func add_additional_effect(additionalSlowEffectNode:EffectBase) -> void:
	if additionalSlowEffectNode.SlowDownSpeedMultiplierTarget < SlowDownSpeedMultiplierTarget:
		SlowDownSpeedMultiplierTarget = additionalSlowEffectNode.SlowDownSpeedMultiplierTarget
	var newEffect : float = SlowDownSpeedMultiplierTarget**_num_stacks
	var newStackTime : float = newEffect / SlowDownSpeedMultiplierTarget * SlowDuration
	if newStackTime < _currentDuration:
		_currentDuration = 0
		# no additional stack in this case
	else:
		if _num_stacks < MaxStacks:
			_num_stacks += 1
		Global.QuestPool.notify_effect_stacks(_num_stacks, _weapon_index)
		recalculateModifier()


func _enter_tree():
	_slow_indicator = get_node(SlowIndicatorPath)
	initGameObjectComponent()
	if _gameObject:
		_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
		_movementSpeedMod.setName(Name)
		var position_component = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if position_component != null:
			remove_child(_slow_indicator)
			position_component.add_child(_slow_indicator)
			_slow_indicator.position = Vector2.ZERO
			_slow_indicator.visible = true
		# initialize the effect even when it is the first one:
		add_additional_effect(self)


func _exit_tree():
	_movementSpeedMod = null
	if _gameObject != null && not _gameObject.is_queued_for_deletion():
		_gameObject.triggerModifierUpdated("MovementSpeed")
		_gameObject = null
	_health_component = null
	if _slow_indicator.get_parent() != self:
		_slow_indicator.queue_free()


func recalculateModifier():
	var newEffect : float = SlowDownSpeedMultiplierTarget**_num_stacks
	_movementSpeedMod.setMultiplierMod(newEffect-1)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_currentStackTime = newEffect / SlowDownSpeedMultiplierTarget * SlowDuration


func _process(delta):
#ifdef PROFILING
#	updateSlow(delta)
#
#func updateSlow(delta):
#endif
	if _gameObject == null: return
	_currentDuration += delta
	if _currentDuration >= _currentStackTime:
		_num_stacks -= 1
		if _num_stacks == 0:
			queue_free()
			return
		_currentDuration -= _currentStackTime
		recalculateModifier()



