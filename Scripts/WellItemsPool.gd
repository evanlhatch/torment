@tool
extends Node

@export var ItemsScenesFolder : String = "res://GameElements/Items"
@export var FetchBlessingScenes : bool:
	set(_value):
		fetch_items()
@export var ItemScenePaths : Array[String] = []

signal WellItemsUpdated
signal EquippedItemsUpdated

var Items : Array = []

func fetch_items():
	if FetchBlessingScenes == null: ItemScenePaths = []
	var dir = DirAccess.open(ItemsScenesFolder)
	
	ItemScenePaths.clear()
	if dir:
		dir.list_dir_begin()
		while true:
			var file_name = dir.get_next()
			if file_name == "": break
			elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
				ItemScenePaths.append(ItemsScenesFolder + "/" +file_name)
		dir.list_dir_end()
		notify_property_list_changed()
	else:
		printerr("Could not open folder: %s" % ItemsScenesFolder)

func queue_resource_load():
	for itemScenePath in ItemScenePaths:
		ResourceLoaderQueue.queueResource(itemScenePath)

func instantiate_item_children():
	for itemScenePath in ItemScenePaths:
		var itemResource = ResourceLoaderQueue.getCachedResource(itemScenePath)
		var item = itemResource.instantiate()
		item.IsWellItem = true
		add_child(item)
		Items.append(item)

func get_item_with_name(item_name:String) -> Node:
	for i in Items:
		if i.Name == item_name:
			return i
	return null

func get_item_with_id(item_id:String) -> Node:
	item_id = Item.remove_item_name_uniqueness(item_id)
	for i in Items:
		if i.ItemID == item_id:
			return i
	return null

func retrieve_item(item):
	var itemID : String = item.ItemID
	if item.SlotType == 6:
		# this is a bottle. we have to make the itemname unique, so
		# that several bottles of the same type can fit in the well at the same time
		itemID = Item.make_item_name_unique(itemID)
		while Global.PlayerProfile.ItemsInWell.has(itemID):
			# on the very off chance that the same name was generated,
			# generate a new one...
			itemID = Item.make_item_name_unique(itemID)
	if not Global.PlayerProfile.ItemsInWell.has(itemID):
		Global.PlayerProfile.ItemsInWell.append(itemID)
		Global.savePlayerProfile(true)
	WellItemsUpdated.emit()
	notify_item_counts()

func equip_item(item):
	var slot_name = item.get_slot_name()
	if slot_name == "Ring":
		if get_equipped_item("Ring_L") == null:
			Global.PlayerProfile.Equipped["Ring_L"] = item.ItemID
			Global.savePlayerProfile(true)
			EquippedItemsUpdated.emit()
			return
		else:
			var ring_r = get_equipped_item("Ring_R")
			if ring_r != null: unequip_item(ring_r, false)
			Global.PlayerProfile.Equipped["Ring_R"] = item.ItemID
			Global.savePlayerProfile(true)
			EquippedItemsUpdated.emit()
			return
	else:
		var present_item = get_equipped_item(slot_name)
		if present_item != null: unequip_item(present_item, false)
		Global.PlayerProfile.Equipped[slot_name] = item.ItemID
		Global.savePlayerProfile(true)
		EquippedItemsUpdated.emit()

func unequip_item(item, save_profile : bool):
	if item == null: return
	for slot in Global.PlayerProfile.Equipped.keys():
		if Global.PlayerProfile.Equipped[slot] == item.ItemID:
			Global.PlayerProfile.Equipped[slot] = null
			if save_profile:
				Global.savePlayerProfile(true)
			EquippedItemsUpdated.emit()
			return


func get_equipped_item(slot_name:String) -> Node:
	var returnedItem : Node = null
	if Global.PlayerProfile.Equipped.has(slot_name) and Global.PlayerProfile.Equipped[slot_name] != null:
		var item_id : String = Global.PlayerProfile.Equipped[slot_name]
		if not item_id.is_empty():
			returnedItem = get_item_with_id(item_id)
	return returnedItem

func is_item_equipped(item) -> bool:
	return Global.PlayerProfile.Equipped.values().has(item.ItemID)


func notify_item_counts():
	var stash = 0
	var retrieved = 0
	for item in Global.PlayerProfile.ItemStash:
		stash += 1
		retrieved += 1
	for item in Global.PlayerProfile.ItemsInWell:
		retrieved += 1
	Global.QuestPool.notify_total_stash(stash)
	Global.QuestPool.notify_total_retrieved(retrieved)
