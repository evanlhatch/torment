extends GameObjectComponent

@export var AddGold : int = 0
@export var AddGoldPercent : float = 0.10
@export var RemoveAfterTime : float = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _goldGainMod : Modifier

func _enter_tree():
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_goldGainMod = Modifier.create("GoldGain", _gameObject)
	_goldGainMod.setName(Name)
	_goldGainMod.setAdditiveMod(AddGold)
	_goldGainMod.setMultiplierMod(AddGoldPercent)
	_gameObject.triggerModifierUpdated("GoldGain")


func _exit_tree():
	_goldGainMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
