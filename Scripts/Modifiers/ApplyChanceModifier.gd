extends GameObjectComponent

@export var ChanceName : String = "Burn"
@export var AddChance : float = 0
@export var AddChancePercent : float = 0
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
	
	_hitChanceMod = Modifier.create(ChanceName, _gameObject)
	_hitChanceMod.setName(Name)
	_hitChanceMod.setAdditiveMod(AddChance)
	_hitChanceMod.setMultiplierMod(AddChancePercent)
	_hitChanceMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated(ChanceName)

func _exit_tree():
	_hitChanceMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
