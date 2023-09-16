extends GameObjectComponent

@export var Duration : float = 1
@export var ShieldEffectNode : Node2D

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _healthComp : Node
var _remainingDuration : float

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	if Duration <= 0:
		printerr("InvincibilityModifier needs a Duration greater than 0!")
		return
	_healthComp = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	if _healthComp == null:
		return
	_healthComp.setInvincibleForTime(Duration)
	var positionComponent = _gameObject.getChildNodeWithMethod("get_worldPosition")
	if positionComponent != null:
		ShieldEffectNode.reparent(positionComponent, false)
		ShieldEffectNode.position = Vector2.ZERO
		ShieldEffectNode.visible = true
	_remainingDuration = Duration
	process_mode = PROCESS_MODE_INHERIT
	

func _exit_tree():
	if _healthComp != null and not _healthComp.is_queued_for_deletion():
		_healthComp.setInvincibleForTime(-1)
		_healthComp = null
	if is_instance_valid(ShieldEffectNode):
		ShieldEffectNode.queue_free()
	_gameObject = null

func _process(delta):
	_remainingDuration -= delta
	if _remainingDuration <= 0:
		queue_free()


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return 1.0 - _remainingDuration / Duration

func get_modifierInfoArea_active() -> bool:
	return _remainingDuration > 0

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
