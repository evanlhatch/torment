extends GameObjectComponent2D

@export var DamageIncreasePercent : float = 1
@export var DamageDecreasePerEnemyPercent : float = 0.05

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _currentDamagePercentMod : float = 0
var _pickupRangeProvider : Node = null
var _damageModifier : Modifier

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_pickupRangeProvider = _gameObject.getChildNodeWithMethod("get_total_pickup_range")
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)


func _process(delta):
#ifdef PROFILING
#	updateDuelist(delta)
#
#func updateDuelist(delta):
#endif
	if _gameObject != null and _pickupRangeProvider != null:
		var center : Vector2 = get_gameobjectWorldPosition()
		var radius : float = _pickupRangeProvider.get_total_pickup_range()
		var numEnemiesInPickupRange : int = Global.World.Locators.count_locators_in_circle(
			"Enemies", center, radius)
		var newDamagePercentMod = DamageIncreasePercent - DamageDecreasePerEnemyPercent * numEnemiesInPickupRange
		newDamagePercentMod = maxf(0, newDamagePercentMod)
		if newDamagePercentMod != _currentDamagePercentMod:
			_currentDamagePercentMod = newDamagePercentMod
			_damageModifier.setMultiplierMod(_currentDamagePercentMod)
			_gameObject.triggerModifierUpdated("Damage")
			_mod_value_str = "%s%%" % get_modifier_count()

func get_modifier_count() -> int:
	return ceili(_currentDamagePercentMod * 100.0)

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
