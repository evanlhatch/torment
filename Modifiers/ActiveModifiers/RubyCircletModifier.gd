extends GameObjectComponent

@export var AdditionalDamagePercentagePerBurningEnemy : float = 0.03
@export var MaxBonus : float = 0.6

func get_modifier_name() -> String:
	return Name

var _currentNumberOfBurningEnemies : int = 0
var _modifierInfoValueStr : String = ""
var _damageModifier : Modifier
var _burnModifier : Modifier

func _enter_tree():
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject:
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)
		_burnModifier = Modifier.create("EffectStrength", _gameObject)
		_burnModifier.setName(Name)
		_burnModifier.allowCategories(["Burn"])
	


func _exit_tree():
	_currentNumberOfBurningEnemies = 0
	_gameObject = null


func updateModifier():
	_damageModifier.setMultiplierMod(min(MaxBonus, AdditionalDamagePercentagePerBurningEnemy * _currentNumberOfBurningEnemies))
	_burnModifier.setMultiplierMod(min(MaxBonus, AdditionalDamagePercentagePerBurningEnemy * _currentNumberOfBurningEnemies))
	_gameObject.triggerModifierUpdated("Damage")
	_gameObject.triggerModifierUpdated("EffectStrength")


func _process(delta):
#ifdef PROFILING
#	updateRubyCirclet(delta)
#
#func updateRubyCirclet(delta):
#endif
	if _gameObject == null:
		return
	
	var burningEnemiesBefore = _currentNumberOfBurningEnemies
	# we'll count the number of burning enemies via the group that the burn effect is in.
	_currentNumberOfBurningEnemies = get_tree().get_nodes_in_group("BurnEffect").size()
	if burningEnemiesBefore != _currentNumberOfBurningEnemies:
		updateModifier()
		_modifierInfoValueStr = "%d%%"% roundi(min(MaxBonus, AdditionalDamagePercentagePerBurningEnemy * _currentNumberOfBurningEnemies) * 100.0)


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Ruby Circlet"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_valuestr() -> String:
	return _modifierInfoValueStr

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
