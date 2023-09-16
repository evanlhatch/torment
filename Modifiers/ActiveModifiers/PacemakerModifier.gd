extends GameObjectComponent

@export var NotMoveTimeForHealth : float = 1
@export var AmountOfHealthAdded : float = .01

var _lastframePosition : Vector2
var _remainingTimeToHealth : float = 0
var _healthComp : Node
var _timeSinceLastHealth : float = 9999
var _lastHealAmount : int = 0
var _lastFrameProgress : bool = false

func _ready():
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject != null:
		_lastframePosition = get_gameobjectWorldPosition()
		_healthComp = _gameObject.getChildNodeWithMethod("add_health")
		_remainingTimeToHealth = NotMoveTimeForHealth

func _process(delta):
	if _gameObject == null:
		return
	
	var currPos : Vector2 = get_gameobjectWorldPosition()
	if currPos != _lastframePosition:
		_lastframePosition = currPos
		_lastFrameProgress = false
		return

	_lastFrameProgress = true
	_timeSinceLastHealth += delta
	_remainingTimeToHealth -= delta
	if _remainingTimeToHealth < 0:
		if _healthComp.has_method("get_maxHealth"):
			_lastHealAmount = round(_healthComp.get_maxHealth() * AmountOfHealthAdded)
		else:
			_lastHealAmount = round(AmountOfHealthAdded * 500)
		_healthComp.add_health(_lastHealAmount)
		_remainingTimeToHealth = NotMoveTimeForHealth
		_timeSinceLastHealth = 0

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Pacemaker"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _remainingTimeToHealth / NotMoveTimeForHealth

func get_modifierInfoArea_active() -> bool:
	return _lastFrameProgress

func get_modifierInfoArea_valuestr() -> String:
	if _timeSinceLastHealth < 1:
		return str(_lastHealAmount)
	return ""

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
