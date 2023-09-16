extends GameObjectComponent

@export var AddStunDurationFactor : float = 0.0
@export var AddStunDurationFactorPercent : float = 0.0
@export var AddStunThreshold : float = 0.0
@export var AddStunThresholdPercent : float = 0.0
@export var AddStunRecoveryPerSecond : float = 0.0
@export var AddStunRecoveryPerSecondPercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _stunThresholdMod : Modifier
var _stunRecoveryMod : Modifier
var _stunDurationFactorMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_stunThresholdMod = Modifier.create("StunThreshold", _gameObject)
	_stunThresholdMod.setName(Name)
	_stunThresholdMod.setAdditiveMod(AddStunThreshold)
	_stunThresholdMod.setMultiplierMod(AddStunThresholdPercent)
	_stunRecoveryMod = Modifier.create("StunRecovery", _gameObject)
	_stunRecoveryMod.setName(Name)
	_stunRecoveryMod.setAdditiveMod(AddStunRecoveryPerSecond)
	_stunRecoveryMod.setMultiplierMod(AddStunRecoveryPerSecondPercent)
	_stunDurationFactorMod = Modifier.create("StunDurationFactor", _gameObject)
	_stunDurationFactorMod.setName(Name)
	_stunDurationFactorMod.setAdditiveMod(AddStunDurationFactor)
	_stunDurationFactorMod.setMultiplierMod(AddStunDurationFactorPercent)
	_gameObject.triggerModifierUpdated("StunThreshold")
	_gameObject.triggerModifierUpdated("StunRecovery")
	_gameObject.triggerModifierUpdated("StunDurationFactor")

func _exit_tree():
	_stunThresholdMod = null
	_stunRecoveryMod = null
	_stunDurationFactorMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
