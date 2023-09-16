@tool
extends Node

@export var ItemScenesFolders : Array[String]= ["res://GameElements/Items"]
@export var FetchItemScenes : bool:
	set(_value):
		fetch_scenes()
		notify_property_list_changed()

@export var GetWeaponIndices : bool:
	set(_value):
		get_weapon_indices()
		notify_property_list_changed()

@export var ItemScenePaths : Array[String] = []

@onready var Equipment = {
	"Head": null,		# 0
	"Neck": null,		# 1
	"Ring_L": null,		# 2
	"Ring_R": null,		# 3
	"Body": null,		# 4
	"Feet": null,		# 5
	"Gloves": null		# 6
}

@onready var bagSize : int = 4
@onready var StoredItems = []

signal InventoryChanged

var AdditionalChanceForNewItems : float = 5
var RarityChances : Array[float] = [
	3,
	1
]

func fetch_scenes():
	if ItemScenePaths == null: ItemScenePaths = []
	ItemScenePaths.clear()
	for d in ItemScenesFolders:
		var dir = DirAccess.open(d)
		if dir:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "": break
				elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
					ItemScenePaths.append(d + "/" +file_name)
			dir.list_dir_end()
		else:
			printerr("Could not open folder: %s" % d)


func sort_ascending(a, b):
	if a[0] < b[0]:
		return true
	return false

func get_weapon_indices():
	if not Engine.is_editor_hint(): return

	var output_string : String = ""
	var weapon_tuples = []

	# fetch item names along with their weapon indices
	for itemScenePath in ItemScenePaths:
		var item = load(itemScenePath).instantiate()
		weapon_tuples.append([item.WeaponIndex, item.Name])
		item.queue_free()
	weapon_tuples.sort_custom(sort_ascending)

	var unique_indices = []
	for entry in weapon_tuples:
		if entry[0] >= 0:
			if unique_indices.has(entry[0]):
				printerr("Duplicate weapon index found: '%d' - '%s'!" % entry)
			else:
				unique_indices.append(entry[0])
		output_string += "%d\t%s\n" % entry
	DisplayServer.clipboard_set(output_string)

func queue_resource_load():
	for itemScenePath in ItemScenePaths:
		ResourceLoaderQueue.queueResource(itemScenePath)

func instantiate_items_children():
	for itemScenePath in ItemScenePaths:
		var itemResource = ResourceLoaderQueue.getCachedResource(itemScenePath)
		add_child(itemResource.instantiate())


## since the ItemPool will be created/destroyed with the world, we can
## use it to store temporary items (like Bottles)
func instantiate_temp_item(itemScene:PackedScene) -> Node:
	var item : Node = itemScene.instantiate()
	add_child(item)
	return item


func roll_item_selection(itemCount : int, minimum_rarity : int = 0, maximum_rarity : int = 0) -> Array[Node]:
	var itemSelection : Array[Node] = []
	var availableItems = get_tree().get_nodes_in_group("AvailableItems")
	var weights : Array[float]
	var totalWeights : float = 0
	for item in availableItems:
		var itemWeight : float = RarityChances[item.Rarity]
		if item.get_well_state() == Item.ItemWellState.NEW:
			itemWeight += AdditionalChanceForNewItems
		if item.Rarity < minimum_rarity:
			itemWeight = 0
		if maximum_rarity >= 0 and item.Rarity > maximum_rarity:
			itemWeight = 0
		# don't add rare item variant if the common one hasn't been retrieved, yet.
		if item.Rarity > 0 and not item.is_in_well() and not item.is_bought():
			itemWeight = 0
		weights.append(itemWeight)
		totalWeights += itemWeight

	for _countIndex in itemCount:
		if availableItems.size() == 0 or totalWeights <= 0:
			break
		var randomWeightPos : float = randf() * totalWeights
		for i in weights.size():
			if randomWeightPos < weights[i]:
				var randomItem = availableItems[i]
				itemSelection.append(randomItem)
				# don't choose the same item again (for itemCount > 1)
				totalWeights -= weights[i]
				weights.remove_at(i)
				availableItems.remove_at(i)
				break
			randomWeightPos -= weights[i]

	return itemSelection


func get_space_in_bag() -> int:
	return bagSize - len(StoredItems)


func get_empty_slot_for_item_available(item:Node) -> int:
	match item.SlotType:
		0: if Equipment["Head"] == null: return 0
		1: if Equipment["Neck"] == null: return 1
		2:
			if Equipment["Ring_L"] == null:
				return 2
			elif Equipment["Ring_R"] == null:
				return 3
		3: if Equipment["Body"] == null: return 4
		4: if Equipment["Feet"] == null: return 5
		5: if Equipment["Gloves"] == null: return 6
	return -1

func get_possible_slots_for_item(item:Node) -> Array[int]:
	match item.SlotType:
		0: return [0]
		1: return [1]
		2: return [2, 3]
		3: return [4]
		4: return [5]
		5: return [6]
	return []

func equip_item(item:Node, modifiedTarget:Node, preferRightRingSlot:bool = false):
	if item.SlotType == 6: return # slot type is 'None' and cannot be equipped
	item.equip_item(modifiedTarget)
	if StoredItems.has(item):
		StoredItems.erase(item)

	match item.SlotType:
		0: Equipment["Head"] = item
		1: Equipment["Neck"] = item
		2:
			if preferRightRingSlot:
				Equipment["Ring_R"] = item
			else:
				if Equipment["Ring_L"] == null:
					Equipment["Ring_L"] = item
				else:
					Equipment["Ring_R"] = item

		3: Equipment["Body"] = item
		4: Equipment["Feet"] = item
		5: Equipment["Gloves"] = item
	InventoryChanged.emit()


func store_item(item:Node):
	item.unequip_item()
	item.store_item()
	for key in Equipment:
		var equipped_item = Equipment[key]
		if equipped_item == item:
			Equipment[key] = null
			break
	StoredItems.append(item)
	InventoryChanged.emit()


func remove_item(item:Node, stay_available : bool = false):
	item.discard_item(stay_available)
	for key in Equipment:
		var equipped_item = Equipment[key]
		if equipped_item == item:
			Equipment[key] = null
			break
	if StoredItems.has(item):
		StoredItems.erase(item)
	InventoryChanged.emit()

func find_item_with_weapon_index(weapon_index : int) -> Node:
	for i in get_children():
		if "WeaponIndex" in i and i.WeaponIndex == weapon_index:
			return i
	return null

func get_item_name_from_weapon_index(weapon_index : int) -> String:
	if weapon_index < 100: return "DEFAULT WEAPON"
	var item = find_item_with_weapon_index(weapon_index)
	if item: return item.Name
	return "?UNKNOWN? WEAPON"

func get_item_icon_from_weapon_index(weapon_index : int) -> Texture2D:
	if weapon_index < 100: return null
	var item = find_item_with_weapon_index(weapon_index)
	if item: return item.Icon
	return null


func find_equipped_item_with_modifier(modifierNode:Node) -> Node:
	for key in Equipment:
		var equipped_item = Equipment[key]
		if equipped_item && equipped_item.has_bestowed_modifier(modifierNode):
			return equipped_item
	return null

func get_equipped_items_as_array() -> Array[Node]:
	var itemArray : Array[Node] = []
	for key in Equipment:
		var equipped_item = Equipment[key]
		if equipped_item != null and !equipped_item.is_queued_for_deletion():
			itemArray.append(equipped_item)
	return itemArray

func find_item_with_name(item_name:String) -> Node:
	for item in get_children():
		if "Name" in item and item.Name == item_name:
			return item
	return null;

func find_item_with_id(item_id:String) -> Node:
	for item in get_children():
		if "ItemID" in item and item.ItemID == item_id:
			return item
	return null;
