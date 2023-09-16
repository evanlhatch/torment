extends GameObjectComponent

@export var AddArea : float = 0
@export var AddAreaPercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _areaModifier : Modifier
var _remainingLevelsToChange : int = 0


func _enter_tree():
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED

	if ChangeEveryXLevels > 0:
		await Global.awaitWorldReady()
		Global.World.ExperienceThresholdReached.connect(on_level_up)
		_remainingLevelsToChange = ChangeEveryXLevels
	
	_areaModifier = Modifier.create("Area", _gameObject)
	_areaModifier.setName(Name)
	_areaModifier.allowCategories(ModifierCategories)
	_areaModifier.setAdditiveMod(AddArea)
	_areaModifier.setMultiplierMod(AddAreaPercent)
	_gameObject.triggerModifierUpdated("Area")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_areaModifier.setMultiplierMod(_areaModifier.getMultiplierMod() + ChangeMultiplier)
		_areaModifier.setAdditiveMod(_areaModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("Area")

func _exit_tree():
	_areaModifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
