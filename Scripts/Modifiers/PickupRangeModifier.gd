extends GameObjectComponent

@export var AddPickupRange : float = 20
@export var AddPickupRangePercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _pickupRangeMod : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_pickupRangeMod = Modifier.create("PickupRange", _gameObject)
	_pickupRangeMod.setName(Name)
	_pickupRangeMod.setAdditiveMod(AddPickupRange)
	_pickupRangeMod.setMultiplierMod(AddPickupRangePercent)
	_gameObject.triggerModifierUpdated("PickupRange")

func _exit_tree():
	_pickupRangeMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
