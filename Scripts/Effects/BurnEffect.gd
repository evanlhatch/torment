extends EffectBase

@export var BurnDuration : float = 3.0
@export var BurnDamage : int = 1
@export var BurnInterval : float = 0.5
@export var MaxStacks : int = 5
@export var BurnIndicatorPath : NodePath
@export var ModifierCategories : Array[String] = ["Fire", "Elemental"]
@export var DamageCategories : Array[String] = ["Fire"]

@export_group("internal state")
@export var _weapon_index : int = -1


var _burn_indicator : Node
var _health_component : Node

var _burn_timer : float
var _burn_duration : float
var _num_stacks : int

func get_effectID() -> String:
	return "BURN"

func add_additional_effect(additionalEffectNode:EffectBase) -> void:
	var finalDamage : int = additionalEffectNode.BurnDamage
	var externalSource : GameObject = get_externalSource()
	if externalSource != null and is_instance_valid(externalSource):
		finalDamage = floori(externalSource.calculateModifiedValue("EffectStrength", additionalEffectNode.BurnDamage, ModifierCategories))
	if finalDamage > BurnDamage:
		BurnDamage = finalDamage

	if _num_stacks >= MaxStacks:
		_burn_timer = BurnInterval
		inflict_burn()
	else:
		_num_stacks += 1
	_burn_duration = BurnDuration
	Global.QuestPool.notify_effect_stacks(_num_stacks, _weapon_index)

#func add_additional_effect(additionalBurnEffectNode:EffectBase) -> void:
#	if len(_burn_stacks) >= MaxStacks: return
#	_burn_stacks.append(additionalBurnEffectNode.BurnDuration)
#	Global.QuestPool.notify_effect_stacks(len(_burn_stacks), _weapon_index)
#	if additionalBurnEffectNode.BurnDamage > BurnDamage:
#		BurnDamage = additionalBurnEffectNode.BurnDamage


func _enter_tree():
	_burn_indicator = get_node(BurnIndicatorPath)
	initGameObjectComponent()
	if _gameObject:
		_health_component = _gameObject.getChildNodeWithMethod("applyDamage")
		var position_component = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if position_component != null:
			remove_child(_burn_indicator)
			position_component.add_child(_burn_indicator)
			_burn_indicator.position = Vector2.ZERO
			_burn_indicator.visible = true
		# initialize the effect even when it is the first one:
		add_additional_effect(self)
		_burn_timer = BurnInterval


func _exit_tree():
	_gameObject = null
	_health_component = null
	if _burn_indicator.get_parent() != self:
		_burn_indicator.queue_free()


func _process(delta):
#ifdef PROFILING
#	updateBurnEffect(delta)
#
#func updateBurnEffect(delta):
#endif
	if _gameObject == null: return
	_burn_timer -= delta;
	if _burn_timer <= 0.0:
		_burn_timer += BurnInterval
		inflict_burn()

	_burn_duration -= delta
	if _burn_duration <= 0.0:
		queue_free()


func inflict_burn():
	if _health_component:
		var stack_damage = BurnDamage
		var damage = stack_damage * _num_stacks
		var externalSource : GameObject = get_externalSource()
		# fire damage cannot be blocked
		var damageReturn = _health_component.applyDamage(
			damage, externalSource, false, _weapon_index, true, Health.DamageEffectType.Burn)
		Global.QuestPool.notify_burn_damage(damage)
		if externalSource != null and is_instance_valid(externalSource):
			externalSource.injectEmitSignal(
				"DamageApplied", [DamageCategories, damage, damageReturn, _gameObject])

