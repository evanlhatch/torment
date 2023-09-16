extends GameObjectComponent

@export var OnlyForTargetGroups : Array[String] = ["Boss", "Elite"]
@export var ReducedDurationGroups : Array[String] = ["Champion"]
@export var AddHealthPercentPerSecond : float = 0.01
@export var Duration : float = 45
@export var ReducedDuration : float = 15

var _remainingDuration : float = 0
var _nextAddHealthSecond : float = 0
var _remainder : float = 0
var _healthComp : Node = null
var _lastDuration : float = 0

func _ready():
	initGameObjectComponent()
	
	if Global.is_world_ready():
		Global.World.connect("EnemyAppeared", _onEnemyAppeared)
	
	if _gameObject != null:
	#	_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_healthComp = _gameObject.getChildNodeWithMethod("add_health")


func _onEnemyAppeared(spawnedEnemy:GameObject):
	var isInCorrectGroup : bool = false
	var isInSecondaryGroup : bool = false
	for g in OnlyForTargetGroups:
		if spawnedEnemy.is_in_group(g):
			isInCorrectGroup = true
			break

	if isInCorrectGroup:
		_lastDuration = Duration
		_remainingDuration = Duration
		_nextAddHealthSecond = Duration - 1
		return
		
	if ReducedDurationGroups == null or ReducedDurationGroups.size() == 0:
		return

	for g in ReducedDurationGroups:
		if spawnedEnemy.is_in_group(g):
			isInSecondaryGroup = true
			break

	if isInSecondaryGroup:
		_lastDuration = max(_remainingDuration, ReducedDuration)
		_remainingDuration = _lastDuration
		_nextAddHealthSecond = _lastDuration - 1
		return


func damageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	if applyReturn[0] != Global.ApplyDamageResult.Killed:
		return
	var isInCorrectGroup : bool = false
	for g in OnlyForTargetGroups:
		if targetNode.is_in_group(g):
			isInCorrectGroup = true
			break
	if not isInCorrectGroup:
		return
	_remainingDuration = Duration
	_nextAddHealthSecond = Duration - 1


func _process(delta):
	if _remainingDuration <= 0:
		_mod_value_str = ""
		return
	if _gameObject == null:
		return
	_remainingDuration -= delta
	if _remainingDuration <= _nextAddHealthSecond:
		_nextAddHealthSecond -= 1
		var addHealthFloat : float = _healthComp.get_maxHealth() * AddHealthPercentPerSecond
		addHealthFloat += _remainder
		var addHealthInt : int = floori(addHealthFloat)
		if addHealthInt > 0:
			_healthComp.add_health(addHealthInt)
			_mod_value_str = str(addHealthInt)
		_remainder = addHealthFloat - addHealthInt

func get_cooldown_factor() -> float:
	return maxf(0, _remainingDuration / _lastDuration)

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Pacemaker"
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return get_cooldown_factor()

func get_modifierInfoArea_active() -> bool:
	return _remainingDuration > 0

func get_modifierInfoArea_valuestr() -> String:
	return _mod_value_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
