extends GameObjectComponent

@export var AttackSpeedMod : float = 0.3
@export var DamagePercentMod : float = 0.3
@export var ModDuration : float = 15
@export var Cooldown : float = 90

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _remainingCooldown : float = 0
var _remainingDuration : float = 0
var _damageModifier : Modifier
var _attackSpeedModifier : Modifier

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("CollectableCollected", collectableWasCollected)
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)
		_attackSpeedModifier = Modifier.create("AttackSpeed", _gameObject)
		_attackSpeedModifier.setName(Name)


func collectableWasCollected(collectable:GameObject):
	if _remainingCooldown > 0:
		return
	if not collectable.is_in_group("Potion") or not collectable.is_in_group("Health"):
		return
	_remainingDuration = ModDuration
	_remainingCooldown = Cooldown + ModDuration
	updateModifier()

func updateModifier():
	if _remainingDuration > 0:
		_damageModifier.setMultiplierMod(DamagePercentMod)
		_attackSpeedModifier.setMultiplierMod(AttackSpeedMod)
		_mod_value_str = "%s%%" % ceili(DamagePercentMod * 100.0)
	else:
		_damageModifier.setMultiplierMod(0)
		_attackSpeedModifier.setMultiplierMod(0)
		_mod_value_str = ""
	_gameObject.triggerModifierUpdated("Damage")
	_gameObject.triggerModifierUpdated("AttackSpeed")


func _process(delta):
#ifdef PROFILING
#	updateWarriorsHearth(delta)
#
#func updateWarriorsHearth(delta):
#endif
	_remainingCooldown -= delta

	if _remainingDuration > 0:
		_remainingDuration -= delta
		if _remainingDuration <= 0:
			updateModifier()


func get_modifier_count() -> int:
	if _remainingDuration <= 0:
		return 0
	return int(ceil(AttackSpeedMod * 100.0))


func get_cooldown_factor() -> float:
	return maxf(0, _remainingCooldown / Cooldown)

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if _remainingDuration > 0:
		return 1 - _remainingDuration / ModDuration
	return _remainingCooldown / Cooldown

func get_modifierInfoArea_active() -> bool:
	return _remainingDuration > 0 or _remainingCooldown <= 0

func get_modifierInfoArea_valuestr() -> String:
	return _mod_value_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
