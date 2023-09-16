extends GameObjectComponent

@export var AddOnCritChance : float = 0
@export var AddOnCritChancePercent : float = 0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _hitChanceMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_hitChanceMod = Modifier.create("OnCritChance", _gameObject)
	_hitChanceMod.setName(Name)
	_hitChanceMod.setAdditiveMod(AddOnCritChance)
	_hitChanceMod.setMultiplierMod(AddOnCritChancePercent)
	_hitChanceMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("OnCritChance")

func _exit_tree():
	_hitChanceMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
