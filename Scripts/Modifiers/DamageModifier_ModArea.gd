extends GameObjectComponent

@export var AddDamage : int = 0
@export var AddDamagePercent : float = 0.5
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]
@export var VisualEffectNode : Node2D

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _damageModifier : Modifier
var _remainingDuration : float = -1

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_damageModifier = Modifier.create("Damage", _gameObject)
	_damageModifier.setName(Name)
	_damageModifier.setAdditiveMod(AddDamage)
	_damageModifier.setMultiplierMod(AddDamagePercent)
	_damageModifier.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("Damage")

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
	_damageModifier = null
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
