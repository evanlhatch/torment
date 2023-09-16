extends Node
class_name Ability

# We agreed upon that ability weapon indices are always > 1000 if they have damage dealing effects.
@export var WeaponIndex : int = -1
@export var ExtendsAbilityWithWeaponIndex : int = -1

@export var Icon : Texture2D
@export var Frame : Texture2D
@export var Name : String
@export_multiline var Description : String

@export_category("Tags")
@export var AllTagsNeeded : Array[String] = []
@export var AndAnyTagNeeded : Array[String] = []
@export var ExcludeWithAnyTagsActive : Array[String] = []
@export var ThresholdTags : Array[String] = []

@export_category("Additional Information")
@export var AbilityTags : String = ""
@export var Keywords : Array[String] = []

@onready var bestowed_modifiers : Array[Node] = []

func _ready():
	if !Global.is_world_ready():
		await Global.WorldReady

	Global.World.Tags.TagsUpdated.connect(tagsUpdated)
	# initialize with current tags (we don't use the signal parameter...)
	tagsUpdated()


func tagsUpdated():
	if is_in_group("AcquiredAbilities"):
		return

	var abilityShouldBeAvailable : bool = true
	var tagsActive : int = 0

	if ExcludeWithAnyTagsActive != null and ExcludeWithAnyTagsActive.size() > 0 and Global.World.Tags.isAnyTagActive(ExcludeWithAnyTagsActive):
		abilityShouldBeAvailable = false
	else:
		if AllTagsNeeded != null and AllTagsNeeded.size() > 0 and not Global.World.Tags.areAllTagsActive(AllTagsNeeded):
			abilityShouldBeAvailable = false
		elif AndAnyTagNeeded != null and AndAnyTagNeeded.size() > 0 and not Global.World.Tags.isAnyTagActive(AndAnyTagNeeded):
			abilityShouldBeAvailable = false

	if abilityShouldBeAvailable and ThresholdTags != null and ThresholdTags.size() > 0:
		if AndAnyTagNeeded != null: tagsActive = max(tagsActive, Global.World.Tags.getTagsActiveCount(AndAnyTagNeeded))
		if Global.World.Tags.getTagsActiveCount(ThresholdTags) >= tagsActive: abilityShouldBeAvailable = false

	if abilityShouldBeAvailable:
		if !is_in_group("AvailableAbilities"): add_to_group("AvailableAbilities")
	else:
		if is_in_group("AvailableAbilities"): remove_from_group("AvailableAbilities")


func acquire_ability(modifiedTarget : Node):
	for child in get_children():
		if child.has_method("AquireAbility"):
			# this node should not be added as a child, but instead
			# this method should be called:
			var nodes : Array[Node] = child.AquireAbility(modifiedTarget)
			if nodes != null and nodes.size() > 0:
				for mod in nodes:
					# we update every weapon index we can to our ability
					if "_weapon_index" in mod:
						if ExtendsAbilityWithWeaponIndex != -1:
							mod._weapon_index = ExtendsAbilityWithWeaponIndex
						elif WeaponIndex != -1:
							mod._weapon_index = WeaponIndex
				bestowed_modifiers.append_array(nodes)
		else:
			var mod: Node = child.duplicate()
			# we update every weapon index we can to our ability
			if "_weapon_index" in mod:
				if ExtendsAbilityWithWeaponIndex != -1:
					mod._weapon_index = ExtendsAbilityWithWeaponIndex
				elif WeaponIndex != -1:
					mod._weapon_index = WeaponIndex
			modifiedTarget.add_child(mod)
			if not mod.is_queued_for_deletion():
				bestowed_modifiers.append(mod)
	remove_from_group("AvailableAbilities")
	add_to_group("AcquiredAbilities")
	if Global.is_world_ready():
		Global.World.emit_signal("AbilityAcquired", self)


func remove_ability(also_remove_from_pool:bool = false):
	for m in bestowed_modifiers:
		if m == null: continue
		m.queue_free()
	bestowed_modifiers.clear()
	remove_from_group("AcquiredAbilities")
	if !also_remove_from_pool:
		add_to_group("AvailableAbilities")
	if Global.is_world_ready():
		Global.World.emit_signal("AbilityRemoved", self)

func get_weapon_index() -> int:
	return WeaponIndex
