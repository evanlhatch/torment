extends GameObjectComponent

@export var AddAttackSpeed : float = 20
@export var AddAttackSpeedPercent : float = 0.0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]
@export var VisualEffectNode : Node2D

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _attackSpeedMod : Modifier
var _remainingDuration : float = -1

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_attackSpeedMod = Modifier.create("AttackSpeed", _gameObject)
	_attackSpeedMod.setName(Name)
	_attackSpeedMod.allowCategories(ModifierCategories)
	_attackSpeedMod.setAdditiveMod(AddAttackSpeed)
	_attackSpeedMod.setMultiplierMod(AddAttackSpeedPercent)
	_gameObject.triggerModifierUpdated("AttackSpeed")

	if is_instance_valid(VisualEffectNode):
		var positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if positionProvider != null:
			VisualEffectNode.reparent(positionProvider, false)
			VisualEffectNode.position = Vector2.ZERO
			VisualEffectNode.visible = true

	if RemoveAfterTime >= 0:
		_remainingDuration = RemoveAfterTime


func _exit_tree():
	if is_instance_valid(VisualEffectNode):
		VisualEffectNode.queue_free()
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0: return
	_remainingDuration -= delta
	if _remainingDuration <= 0:
		queue_free()




@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return 1.0 - _remainingDuration / RemoveAfterTime

func get_modifierInfoArea_active() -> bool:
	if RemoveAfterTime < 0: return false
	return _remainingDuration > 0

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name

