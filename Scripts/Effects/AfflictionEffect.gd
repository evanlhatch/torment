extends EffectBase

@export var AddDamageFactor : float = 0.5
@export var AddDamageFactorPercent : float = 0.0
@export var TimeReductionPerStack : float = 0.05
@export var RemoveAfterTime : float = 5
@export var AfflictionIndicatorPath : NodePath

@export_group("internal state")
@export var _weapon_index : int = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _indicator : Node
var _remove_timer : float
var _damageFactorMod : Modifier
var _num_stacks : int = 0

func get_effectID() -> String:
	return "AFFLICTION"

func add_additional_effect(additionalEffectNode:EffectBase) -> void:
	if _gameObject == null || _gameObject.is_queued_for_deletion():
		return
	_num_stacks += 1
	Global.QuestPool.notify_effect_stacks(_num_stacks, _weapon_index)

	# let's also take the maximum of every factor, just to be sure.
	AddDamageFactor = max(AddDamageFactor, additionalEffectNode.AddDamageFactor)
	AddDamageFactorPercent = max(AddDamageFactorPercent, additionalEffectNode.AddDamageFactorPercent)

	recalculateModifier()
	if _remove_timer > 0:
		_remove_timer -= TimeReductionPerStack
	else:
		_remove_timer = RemoveAfterTime - _num_stacks * TimeReductionPerStack


func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_damageFactorMod = Modifier.create("DamageFromEffectsFactor", _gameObject)
		_damageFactorMod.setName(Name)
		_indicator = get_node(AfflictionIndicatorPath)
		var indicator_slot = _gameObject.getChildNodeInGroup("StatusIndicator")
		if indicator_slot != null:
			remove_child(_indicator)
			indicator_slot.add_child(_indicator)
			_indicator.position = Vector2.ZERO
			_indicator.visible = true
		add_additional_effect(self)


func _exit_tree():
	if _indicator and _indicator.get_parent() != self:
		_indicator.queue_free()

func recalculateModifier():
	_damageFactorMod.setAdditiveMod(_num_stacks * AddDamageFactor)
	_damageFactorMod.setMultiplierMod(_num_stacks * AddDamageFactorPercent)
	_gameObject.triggerModifierUpdated("DamageFromEffectsFactor")

func _process(delta):
	if RemoveAfterTime < 0:
		return
	_remove_timer -= delta
	if _remove_timer <= 0:
		# number of stacks is halved, every time the timer hits 0!
		_num_stacks = floori(float(_num_stacks) * 0.5)
		if _num_stacks == 0:
			_damageFactorMod = null
			if _gameObject != null and !_gameObject.is_queued_for_deletion():
				_gameObject.triggerModifierUpdated("DamageFromEffectsFactor")
			queue_free()
			return
		recalculateModifier()
		_remove_timer += RemoveAfterTime - _num_stacks * TimeReductionPerStack

