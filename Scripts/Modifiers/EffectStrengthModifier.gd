extends GameObjectComponent

@export var AddEffectStrength : float = 0.0
@export var AddEffectStrengthPercent : float = 0.0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _attackSpeedMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED

	_attackSpeedMod = Modifier.create("EffectStrength", _gameObject)
	_attackSpeedMod.setName(Name)
	_attackSpeedMod.allowCategories(ModifierCategories)
	_attackSpeedMod.setAdditiveMod(AddEffectStrength)
	_attackSpeedMod.setMultiplierMod(AddEffectStrengthPercent)
	_gameObject.triggerModifierUpdated("EffectStrength")


func _exit_tree():
	_gameObject = null


func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
