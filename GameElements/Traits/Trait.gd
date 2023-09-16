extends Node

@export var Icon : Texture2D
@export var Frame : Texture2D
@export var Name : String
@export_multiline var Description : String
@export var RequiredCharacterTag : String = ""
@export var AnyTagNeeded : Array[String] = []
@export var AndAnyTagNeeded : Array[String] = []
@export var ExcludeWithAnyTagsActive : Array[String] = []
@export var ActivateTagsWhenAcquired : Array[String] = []
@export var MinLevel : int = -1
@export var MaxLevel : int = -1
@export var Keywords : Array[String] = []

## Category is used to banish a whole group of traits alltogether
@export var Category : String

@onready var bestowed_modifiers : Array = []

var AcquiredNumberOfTimes: int = 0

func _ready():
	if Global.is_world_ready():
		_on_world_ready()
	else:
		Global.connect("WorldReady", _on_world_ready)


func _on_world_ready():
	Global.World.Tags.TagsUpdated.connect(tagsUpdated)
	# initialize with current tags (we don't use the signal parameter...)
	tagsUpdated()


func tagsUpdated():
	if is_in_group("AcquiredTraits") or is_in_group("BanishedTraits"):
		return

	var traitShouldBeAvailable : bool = true
	if ExcludeWithAnyTagsActive != null and ExcludeWithAnyTagsActive.size() > 0 and Global.World.Tags.isAnyTagActive(ExcludeWithAnyTagsActive):
		traitShouldBeAvailable = false
	else:
		if not RequiredCharacterTag.is_empty() and not Global.World.Tags.isTagActive(RequiredCharacterTag):
			traitShouldBeAvailable = false
		elif AnyTagNeeded != null and AnyTagNeeded.size() > 0 and not Global.World.Tags.isAnyTagActive(AnyTagNeeded):
			traitShouldBeAvailable = false
		elif AndAnyTagNeeded != null and AndAnyTagNeeded.size() > 0 and not Global.World.Tags.isAnyTagActive(AndAnyTagNeeded):
			traitShouldBeAvailable = false
	if traitShouldBeAvailable:
		if !is_in_group("AvailableTraits"): add_to_group("AvailableTraits")
	else:
		if is_in_group("AvailableTraits"): remove_from_group("AvailableTraits")


func acquire_trait(modifiedTarget : Node):
	for child in get_children():
		var mod = child.duplicate(
			Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS |
			Node.DUPLICATE_SIGNALS)
		bestowed_modifiers.append(mod)
		modifiedTarget.add_child(mod)
	AcquiredNumberOfTimes += 1
	if is_in_group("AvailableTraits"): remove_from_group("AvailableTraits")
	if not is_in_group("AcqiredTraits"): add_to_group("AcquiredTraits")
	Global.QuestPool.notify_trait_acquired(Name)

	if ActivateTagsWhenAcquired != null and ActivateTagsWhenAcquired.size() > 0:
		Global.World.Tags.setTagsActive(ActivateTagsWhenAcquired)


func remove_trait(also_remove_from_pool:bool = false):
	for m in bestowed_modifiers:
		if m == null: continue
		m.queue_free()
	bestowed_modifiers.clear()
	remove_from_group("AcquiredTraits")
	if !also_remove_from_pool:
		add_to_group("AvailableTraits")


func is_available_for_level(level:int) -> bool:
	if MinLevel >= 0 and MinLevel > level:
		return false
	if MaxLevel >= 0 and MaxLevel < level:
		return false
	return true


func get_level_range_string() -> String:
	var min_lvl = max(MinLevel, 1)
	return "LVL %d " % min_lvl
