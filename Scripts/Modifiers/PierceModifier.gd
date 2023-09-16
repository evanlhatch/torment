extends GameObjectComponent

@export var AddPierce : int = 1
@export var AddPiercePercent : float = 0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _pierceMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_pierceMod = Modifier.create("Pierce", _gameObject)
	_pierceMod.setName(Name)
	_pierceMod.setAdditiveMod(AddPierce)
	_pierceMod.setMultiplierMod(AddPiercePercent)
	_pierceMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("Pierce")

func _exit_tree():
	_pierceMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
