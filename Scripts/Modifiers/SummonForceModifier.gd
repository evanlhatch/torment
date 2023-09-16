extends GameObjectComponent

@export var AddSummonDuration : int = 0
@export var AddSummonDurationPercent : float = 0.5
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _modifier : Modifier

func _enter_tree():
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 else PROCESS_MODE_DISABLED
		
	_modifier = Modifier.create("SummonDuration", _gameObject)
	_modifier.setName(Name)
	_modifier.setAdditiveMod(AddSummonDuration)
	_modifier.setMultiplierMod(AddSummonDurationPercent)
	_modifier.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("SummonDuration")

func _exit_tree():
	_modifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
