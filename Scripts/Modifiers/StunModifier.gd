extends GameObjectComponent

@export var AddStunBuildup : float = 0
@export var AddStunBuildupPercent : float = 0.0
@export var AddStunDuration : float = 0
@export var AddStunDurationPercent : float = 0.0
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _stunBuildupMod : Modifier
var _stunDurationMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_stunBuildupMod = Modifier.create("StunBuildup", _gameObject)
	_stunBuildupMod.setName(Name)
	_stunBuildupMod.setAdditiveMod(AddStunBuildup)
	_stunBuildupMod.setMultiplierMod(AddStunBuildupPercent)
	_stunBuildupMod.allowCategories(ModifierCategories)
	_stunDurationMod = Modifier.create("StunDuration", _gameObject)
	_stunDurationMod.setName(Name)
	_stunDurationMod.setAdditiveMod(AddStunDuration)
	_stunDurationMod.setMultiplierMod(AddStunDurationPercent)
	_stunDurationMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("StunBuildup")
	_gameObject.triggerModifierUpdated("StunDuration")

func _exit_tree():
	_stunBuildupMod = null
	_stunDurationMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
