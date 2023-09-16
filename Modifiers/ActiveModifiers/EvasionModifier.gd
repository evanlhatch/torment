extends GameObjectComponent2D

@export var AddBlockValuePerEntry : int = 1
@export var ModifierCap : int = 10
@export var ReductionIntervalLength : float = 0.2
@export var ReductionPerInterval : int = 1
@export var MovementThreshold : float = 54
@export var UseModifier : bool = true

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _previousPosition : Vector2
var _distanceMoved : float
var _buff_reduction_timer : float
var _modifiedCap

var buff_count : int
var _blockValueModifier : Modifier


func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_previousPosition = _positionProvider.get_worldPosition()
		_blockValueModifier = Modifier.create("BlockValue", _gameObject)
		_blockValueModifier.setName(Name)
		_modifiedCap = ModifiedFloatValue.new()
		_modifiedCap.initAsMultiplicativeOnly("MovementSpeed", _gameObject, Callable())


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		_positionProvider = null
	_gameObject = null


func _process(delta):
#ifdef PROFILING
#	updateEvasion(delta)
#
#func updateEvasion(delta):
#endif
	if _gameObject == null or _positionProvider == null: return
	
	var new_position = _positionProvider.get_worldPosition()
	var distance_this_frame = _previousPosition.distance_to(new_position)
	if distance_this_frame > 1.0:
		_distanceMoved += distance_this_frame
		_previousPosition = new_position
		_buff_reduction_timer = 0.0
		if _distanceMoved >= MovementThreshold:
			_distanceMoved = 0.0
			increase_buff()
		return
	
	_buff_reduction_timer += delta
	if _buff_reduction_timer >= ReductionIntervalLength:
		_buff_reduction_timer -= ReductionIntervalLength
		reduce_buff()


func reduce_buff():
	if buff_count <= 0: return
	buff_count -= 1
	updateModifier()

func increase_buff():
	if buff_count >= get_total_modifier_cap(): return
	buff_count += 1
	updateModifier()

func updateModifier():
	var addMod : float = AddBlockValuePerEntry * buff_count
	_blockValueModifier.setAdditiveMod(addMod)
	_gameObject.triggerModifierUpdated("BlockValue")
	if addMod > 0:
		mod_info_str = "%s" % addMod
	else:
		mod_info_str = ""


func get_total_modifier_cap() -> int:
	if not UseModifier: return ModifierCap
	return round(float(ModifierCap) * _modifiedCap.Value())

func get_modifier_count() -> int:
	return buff_count

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var mod_info_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_valuestr() -> String:
	return mod_info_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
