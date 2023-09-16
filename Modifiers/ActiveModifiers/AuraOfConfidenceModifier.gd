extends GameObjectComponent2D

@export var DamageIncreasePerEnemyInPickupPercent : float = 0.05
@export var MaxDamageIncreasePercent : float = 0.5

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _pickupRangeProvider : Node = null
var _damageModifier : Modifier


func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)
		_pickupRangeProvider = _gameObject.getChildNodeWithMethod("get_total_pickup_range")


func _process(delta):
#ifdef PROFILING
#	updateAuraOfConfidence(delta)
#
#func updateAuraOfConfidence(delta):
#endif
	if _gameObject != null and _pickupRangeProvider != null:
		var center : Vector2 = get_gameobjectWorldPosition()
		var radius : float = _pickupRangeProvider.get_total_pickup_range()
		var numEnemiesInPickupRange : int = Global.World.Locators.count_locators_in_circle(
			"Enemies", center, radius)
		var newDamagePercentMod = DamageIncreasePerEnemyInPickupPercent * numEnemiesInPickupRange
		newDamagePercentMod = minf(MaxDamageIncreasePercent, newDamagePercentMod)
		if newDamagePercentMod != _damageModifier.getMultiplierMod():
			_damageModifier.setMultiplierMod(newDamagePercentMod)
			_gameObject.triggerModifierUpdated("Damage")
			_mod_value_str = "%s%%" % get_modifier_count()


func get_modifier_count() -> int:
	return ceili(_damageModifier.getMultiplierMod() * 100.0)

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
