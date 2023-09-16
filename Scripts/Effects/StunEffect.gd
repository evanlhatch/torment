extends EffectBase

@export var StunDuration : float = 0.5
@export var StunBuildup : float
@export var StunIndicatorPath : NodePath

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _stunCounter : float
var _modifiedStunDurationFactor

var _movementSpeedModifier : Modifier
var _massModifier : Modifier
var _attackSpeedModifier : Modifier

var _stun_indicator : Node

func get_effectID() -> String:
	return "STUN"

func add_additional_effect(additionalStunEffectScene:EffectBase) -> void:
	if additionalStunEffectScene.StunDuration > StunDuration:
		if is_stunned():
			# stun duration has to be prolonged by the additional duration!
			var additionalDuration = additionalStunEffectScene.StunDuration - StunDuration
			_stunCounter = additionalDuration * _modifiedStunDurationFactor.Value()
		StunDuration = additionalStunEffectScene.StunDuration
	if not is_stunned():
		set_stunned(true)

func _enter_tree():
	_stun_indicator = get_node(StunIndicatorPath)
	initGameObjectComponent()
	if _gameObject:
		_movementSpeedModifier = Modifier.create("MovementSpeed", _gameObject)
		_movementSpeedModifier.setName(Name)
		_massModifier = Modifier.create("Mass", _gameObject)
		_massModifier.setName(Name)
		_attackSpeedModifier = Modifier.create("AttackSpeed", _gameObject)
		_attackSpeedModifier.setName(Name)
		var indicator_slot = _gameObject.getChildNodeInGroup("StatusIndicator")
		if indicator_slot != null:
			remove_child(_stun_indicator)
			indicator_slot.add_child(_stun_indicator)
			_stun_indicator.position = Vector2.ZERO
		_modifiedStunDurationFactor = createModifiedFloatValue(1.0, "StunDurationFactor")
		# this function also gets called when this effect is newly added
		# to a node and in that case we need to call add_additional_effect
		add_additional_effect(self)


func _exit_tree():
	_gameObject = null
	if _stun_indicator.get_parent() != self:
		_stun_indicator.queue_free()

func _process(delta):
#ifdef PROFILING
#	updateStunEffect(delta)
#
#func updateStunEffect(delta):
#endif
	if is_stunned():
		_stunCounter -= delta
		if _stunCounter <= 0:
			set_stunned(false)
		return

func is_stunned() -> bool:
	return _stunCounter > 0.0

func set_stunned(stunned:bool):
	if stunned:
		_stunCounter = StunDuration * _modifiedStunDurationFactor.Value()
		if _stunCounter <= 0:
			# modifier can force the duration to 0, e.g. for bosses 
			return
		_movementSpeedModifier.setMultiplierMod(-999.0)
		_massModifier.setMultiplierMod(999.0)
		_attackSpeedModifier.setMultiplierMod(-999.0)
	else:
		_stunCounter = 0.0
		# the duration will be set in the add_additional_effect!
		StunDuration = 0
		_movementSpeedModifier.setMultiplierMod(0.0)
		_massModifier.setMultiplierMod(0.0)
		_attackSpeedModifier.setMultiplierMod(0.0)
	
	_gameObject.triggerModifierUpdated("Mass")
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("AttackSpeed")
	if _stun_indicator:
		_stun_indicator.visible = stunned and _stun_indicator.get_parent().is_in_group("StatusIndicator")
