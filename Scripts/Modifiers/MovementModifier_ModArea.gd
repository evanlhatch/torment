extends GameObjectComponent

@export var AddSpeed : float = 0
@export var AddSpeedPercent : float = 0.5
@export var AddMass : float = 0
@export var AddMassPercent : float = 2
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _movementSpeedMod : Modifier
var _massMod : Modifier
var _remainingDuration : float = -1

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED	

	_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedMod.setName(Name)
	_movementSpeedMod.setAdditiveMod(AddSpeed)
	_movementSpeedMod.setMultiplierMod(AddSpeedPercent)
	_movementSpeedMod.allowCategories(ModifierCategories)
	_massMod = Modifier.create("Mass", _gameObject)
	_massMod.setName(Name)
	_massMod.setAdditiveMod(AddMass)
	_massMod.setMultiplierMod(AddMassPercent)
	_massMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("Mass")

	if RemoveAfterTime >= 0:
		_remainingDuration = RemoveAfterTime

func _exit_tree():
	_movementSpeedMod = null
	_massMod = null
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
