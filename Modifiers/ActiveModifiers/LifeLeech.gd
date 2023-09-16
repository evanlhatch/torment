extends GameObjectComponent

# when OnlyOnKill is false, it will trigger on every damage event
@export var OnlyOnKill : bool = true
@export var Chance : float = 0.1
@export var AddAbsoluteHealth : int = 1
@export var AddPercentageOfDamageDone : float = 0
@export var OnlyWithDamageCategories : Array[String]

var _healthComponent : Node = null
var _timeOfLastLeech : float = 0
var _totalLeech : int = 0

func _ready():
	initGameObjectComponent()
	if _gameObject:
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_healthComponent = _gameObject.getChildNodeWithMethod("add_health")

func damageWasApplied(categories:Array[String], _damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	if _gameObject == null or _gameObject.is_queued_for_deletion():
		return
	if applyReturn[0] == Global.ApplyDamageResult.Blocked or applyReturn[0] == Global.ApplyDamageResult.Invincible:
		return
	if OnlyOnKill and applyReturn[0] != Global.ApplyDamageResult.Killed:
		return
	if Chance < 1 and randf() > Chance:
		return
	if not OnlyWithDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in categories:
			if OnlyWithDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return
	
	var addAmount : int = 0
	addAmount += AddAbsoluteHealth
	addAmount += floori(applyReturn[1] * AddPercentageOfDamageDone)
	if addAmount > 0:
		_healthComponent.add_health(addAmount)
		_totalLeech += addAmount
		mod_info_str = str(_totalLeech)
		_timeOfLastLeech = Global.World.current_world_time

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = ""
@export_multiline var TooltipText : String = ""
var mod_info_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_active() -> bool:
	return true

func get_modifierInfoArea_valuestr() -> String:
	return mod_info_str

func get_modifierInfoArea_name() -> String:
	return Name
