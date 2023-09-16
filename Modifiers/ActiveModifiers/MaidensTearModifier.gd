extends GameObjectComponent

@export var Cooldown : float = 120
@export var AddHealthPercent : float = 0.1

var _remainingCooldown : float 
var _healthComp : Node

func _ready():
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject != null:
		_healthComp = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
		_gameObject.connectToSignal("InvincibilityNegatedDamage", invincibilityNegatedDamage)
	_remainingCooldown = Cooldown

func _exit_tree():
	if _gameObject == null || _gameObject.is_queued_for_deletion():
		return
	_healthComp.setInvincibleForTime(0)
	_healthComp.setInvincibleForTime(_healthComp.InvincibilityTimeWhenDamaged)

func _process(delta):
	if _gameObject == null:
		return
	if _remainingCooldown > 0:
		_remainingCooldown -= delta
		if _remainingCooldown <= 0:
			_healthComp.setInvincibleForTime(9999)


func invincibilityNegatedDamage(amount:int, byNode:Node):
	if _remainingCooldown > 0:
		return # still on cooldown, must be other source of invincibility

	_remainingCooldown = Cooldown
	# first we need to reset the invincibility time!
	_healthComp.setInvincibleForTime(0)
	# and then we reset it to the invincibility when damaged...
	_healthComp.setInvincibleForTime(_healthComp.InvincibilityTimeWhenDamaged)
	var percentHealth : int = ceili(float(_healthComp.get_maxHealth()) * AddHealthPercent)
	_healthComp.add_health(percentHealth)


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Maiden's Tear"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _remainingCooldown / Cooldown

func get_modifierInfoArea_active() -> bool:
	return _remainingCooldown <= 0

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
