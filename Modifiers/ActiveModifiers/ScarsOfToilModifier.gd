extends GameObjectComponent

@export var AddBaseDamagePerMissingHealth : float = 0.0
@export var AddPercentPerMissingHealth : float = 0.015
@export var RemoveAfterTime : float = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _healthComponent
var _missingHealth : int
var _damageModifier : Modifier

func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_healthComponent = _gameObject.getChildNodeWithMethod("get_health")
		if _healthComponent and _healthComponent.has_signal("HealthChanged"):
			_healthComponent.connect("HealthChanged", _on_health_changed)
			_missingHealth = _healthComponent.get_maxHealth() - _healthComponent.get_health()
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)
		updateModifier()

func _exit_tree():
	_missingHealth = 0
	if _healthComponent and _healthComponent.has_signal("HealthChanged"):
		_healthComponent.disconnect("HealthChanged", _on_health_changed)
	_gameObject = null
	_healthComponent = null

func updateModifier():
	_damageModifier.setAdditiveMod(AddBaseDamagePerMissingHealth * _missingHealth)
	_damageModifier.setMultiplierMod(AddPercentPerMissingHealth * _missingHealth)
	_gameObject.triggerModifierUpdated("Damage")
	# the item that currently uses this only has a percentage mod!
	_mod_value_str = "%s%%" % ceili(_damageModifier.getMultiplierMod() * 100.0)

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()

func _on_health_changed(_currentAmount:int, _change:int):
	_missingHealth = _healthComponent.get_maxHealth() - _healthComponent.get_health()
	updateModifier()

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_active() -> bool:
	return _damageModifier.getMultiplierMod() != 0

func get_modifierInfoArea_valuestr() -> String:
	return _mod_value_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
