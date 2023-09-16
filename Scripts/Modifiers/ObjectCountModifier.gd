extends GameObjectComponent
# currently used for summon rings to not have them get emit coutns from all emit count modifiers

@export var AddEmitCount : float = 1
@export var AddEmitCountPercent : float = 0.0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _emitCountMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_emitCountMod = Modifier.create("ObjectCount", _gameObject)
	_emitCountMod.setName(Name)
	_emitCountMod.setAdditiveMod(AddEmitCount)
	_emitCountMod.setMultiplierMod(AddEmitCountPercent)
	_emitCountMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("ObjectCount")

func _exit_tree():
	_emitCountMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
