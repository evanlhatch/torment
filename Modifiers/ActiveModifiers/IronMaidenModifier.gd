extends GameObjectComponent

@export var DefenseGrantAmount : int = 3
@export var MaxStacks : int = 10
@export var Duration : float = 5

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _remainingDuration : Array[float] = []
var _defenseModifier : Modifier
var _activeStacks : int = 0
var _lowestTime : float = 0

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("ReceivedDamage", damageWasReceived)
		_remainingDuration.resize(MaxStacks)
		_defenseModifier = Modifier.create("Defense", _gameObject)
		_defenseModifier.setName(Name)


func damageWasReceived(amount:int, byNode:Node, weapon_index:int):
	for i in range(MaxStacks):
		if _remainingDuration[i] <= 0:
			_remainingDuration[i] = Duration
			_activeStacks += 1
			if _lowestTime <= 0:
				_lowestTime = Duration
			updateModifier()
			return


func updateModifier():
	_defenseModifier.setAdditiveMod(_activeStacks * DefenseGrantAmount)
	_gameObject.triggerModifierUpdated("Defense")


func _process(delta):
#ifdef PROFILING
#	updateIronMaiden(delta)
#
#func updateIronMaiden(delta):
#endif
	var lowestFound : float = Duration
	if _gameObject == null:
		return
	var needsUpdate : bool = false
	for i in range(MaxStacks):
		if _remainingDuration[i] > 0:
			_remainingDuration[i] -= delta
			if _remainingDuration[i] <= 0:
				_activeStacks -= 1
				_lowestTime = Duration
				updateModifier()
			elif _remainingDuration[i] < lowestFound:
				lowestFound = _remainingDuration[i]
	if lowestFound < Duration:
		_lowestTime = lowestFound


func get_cooldown_factor() -> float:
	return Duration

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if _lowestTime == 5:
		return 1
	return 1 - (_lowestTime / Duration)

func get_modifierInfoArea_active() -> bool:
	return _activeStacks > 0

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name

func get_modifierInfoArea_valuestr() -> String:
	return str(_activeStacks * DefenseGrantAmount)