extends GameObjectComponent

@export var DamageThresholdPercentage : float = 20

var _healthComponent
var _damageCounter : int
var _timeSinceLastHealth : float = 9999
var _total_healed : int = 0

func _enter_tree():
	_damageCounter = 0
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject:
		Global.World.connect("DamageEvent", _on_damage_event)
		_healthComponent = _gameObject.getChildNodeWithMethod("add_health")


func _exit_tree():
	if _gameObject && !_gameObject.is_queued_for_deletion():
		Global.World.disconnect("DamageEvent", _on_damage_event)
		_gameObject = null


func _on_damage_event(_targetObject:GameObject, sourceObject:GameObject, damageAmount:int, _totalDamage:int):
	if not _healthComponent: return
	if sourceObject != null and sourceObject.is_in_group("FromPlayer"):
		_damageCounter += damageAmount
	if _damageCounter >= _healthComponent.get_maxHealth() * DamageThresholdPercentage:
		_damageCounter = 0
		_healthComponent.add_health(1)
		_total_healed += 1
		_timeSinceLastHealth = 0

func _process(delta):
	_timeSinceLastHealth += delta

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Blood Catcher"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if not _healthComponent: return 1.0
	return 1.0 - (float(_damageCounter) / (float(_healthComponent.get_maxHealth()) * DamageThresholdPercentage))

func get_modifierInfoArea_active() -> bool:
	return _timeSinceLastHealth < 0.5

func get_modifierInfoArea_valuestr() -> String:
	return str(_total_healed)

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText.format({
		"DamageThresholdPercentage": ceili(DamageThresholdPercentage * 100.0)
	})

func get_modifierInfoArea_name() -> String:
	return Name
