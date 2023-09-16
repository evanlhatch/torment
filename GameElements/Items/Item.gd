@icon("res://Sprites/UI_gfx/equip.png")
extends Node
class_name Item
@export var ItemID : String

@export_enum("Head", "Neck", "Ring", "Body", "Feet", "Gloves", "Bottle", "None") var SlotType : int

@export var QuestItem : bool = false
@export var WeaponIndex : int = -1
@export var Icon : Texture2D
@export var Name : String
@export_multiline var Description : String
@export var GoldPrice : int = 100
@export var AnyTagNeeded : Array[String] = []
@export var AndAnyTagNeeded : Array[String] = []
@export var ExcludeWithAnyTagsActive : Array[String] = []
@export var IsWellItem : bool = false
@export var Rarity : ItemRarity = ItemRarity.Common

enum ItemRarity {
	Common,
	Uncommon
}

enum ItemWellState {
	NONE, NEW, RETRIEVED, OWNED, NOTRETRIEVABLE
}

@onready var bestowed_modifiers : Array = []

func _ready():
	if IsWellItem:
		if is_in_group("AvailableItems"):
			remove_from_group("AvailableItems")
		return
	if Global.is_world_ready():
		_on_world_ready()
	else:
		Global.connect("WorldReady", _on_world_ready)

func _on_world_ready():
	Global.World.Tags.TagsUpdated.connect(tagsUpdated)
	# initialize with current tags (we don't use the signal parameter...)
	tagsUpdated()

func tagsUpdated():
	if is_in_group("EquippedItems") or is_in_group("StoredItems"):
		return

	var itemShouldBeAvailable : bool = true
	if ExcludeWithAnyTagsActive != null and ExcludeWithAnyTagsActive.size() > 0 and Global.World.Tags.isAnyTagActive(ExcludeWithAnyTagsActive):
		itemShouldBeAvailable = false
	else:
		if AnyTagNeeded != null and AnyTagNeeded.size() > 0 and not Global.World.Tags.isAnyTagActive(AnyTagNeeded):
			itemShouldBeAvailable = false
		elif AndAnyTagNeeded != null and AndAnyTagNeeded.size() > 0 and not Global.World.Tags.isAnyTagActive(AndAnyTagNeeded):
			itemShouldBeAvailable = false
	if itemShouldBeAvailable:
		if !is_in_group("AvailableItems"): add_to_group("AvailableItems")
	else:
		if is_in_group("AvailableItems"): remove_from_group("AvailableItems")

func equip_item(modifiedTarget : Node):
	if SlotType == 6: return # slot type is 'None' and cannot be equipped
	Logging.log_item_equip(Name)
	for child in get_children():
		var mod = child.duplicate(
			Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS |
			Node.DUPLICATE_SIGNALS)
		# we update every weapon index we can to our item weapon index
		if WeaponIndex != -1 and "_weapon_index" in mod:
			mod._weapon_index = WeaponIndex
		bestowed_modifiers.append(mod)
		modifiedTarget.add_child(mod)

	if is_in_group("AvailableItems"):
		remove_from_group("AvailableItems")
	if is_in_group("StoredItems"):
		remove_from_group("StoredItems")
	else:
		Global.QuestPool.notify_item_found(self)
	add_to_group("EquippedItems")


func unequip_item():
	Logging.log_item_unequip(Name)
	remove_besowed_modifiers()
	if is_in_group("EquippedItems"):
		remove_from_group("EquippedItems")


func store_item():
	remove_besowed_modifiers()
	if is_in_group("AvailableItems"):
		remove_from_group("AvailableItems")
	if not is_in_group("StoredItems"):
		add_to_group("StoredItems")


func discard_item(stay_available : bool = false):
	remove_besowed_modifiers()
	if stay_available:
		add_to_group("AvailableItems")
	elif is_in_group("AvailableItems"):
		remove_from_group("AvailableItems")

	if is_in_group("StoredItems"):
		remove_from_group("StoredItems")
	if is_in_group("EquippedItems"):
		remove_from_group("EquippedItems")


func remove_besowed_modifiers():
	for m in bestowed_modifiers:
		if m == null: continue
		m.queue_free()
	bestowed_modifiers.clear()

func has_bestowed_modifier(mod:Node) -> bool:
	if bestowed_modifiers == null:
		return false
	return bestowed_modifiers.find(mod) != -1

func is_in_well(uniqueID:String = "") -> bool:
	return Global.PlayerProfile.ItemsInWell.has(ItemID if uniqueID.is_empty() else uniqueID)

func is_bought() -> bool:
	return Global.PlayerProfile.ItemStash.has(ItemID)

func get_well_state() -> ItemWellState:
	if QuestItem: return ItemWellState.NONE
	if Rarity != ItemRarity.Common: return ItemWellState.NOTRETRIEVABLE
	if is_bought(): return ItemWellState.OWNED
	if is_in_well(): return ItemWellState.RETRIEVED
	return ItemWellState.NEW

func try_to_buy(uniqueItemID:String) -> bool:
	if !is_in_well(uniqueItemID): return false
	if is_bought(): return false
	if SlotType == 6:
		# this is a bottle! do not add to stash, but increase the amount!
		var potion : PotionResource = Global.PotionsPool.get_potion_for_item(ItemID)
		if potion == null:
			printerr("Could not find potion for item %s!" % ItemID)
			return false
		else:
			var currentAmount : int = 0
			if Global.PlayerProfile.has(potion.AmountProfileFieldName):
				currentAmount = Global.PlayerProfile[potion.AmountProfileFieldName]
			if currentAmount >= potion.MaxAmount:
				printerr("Cannot buy %s, max amount has been reached." % potion.PotionName)
				return false
			if !Global.payGold(GoldPrice, false): return false
			currentAmount += 1
			Global.PlayerProfile[potion.AmountProfileFieldName] = currentAmount
	else:
		if !Global.payGold(GoldPrice, false): return false
		Global.PlayerProfile["ItemStash"].append(ItemID)
	Global.QuestPool.notify_item_bought(ItemID)
	Global.PlayerProfile["ItemsInWell"].erase(uniqueItemID)
	Global.WellItemsPool.notify_item_counts()
	Global.savePlayerProfile(true)
	return true

func get_slot_name() -> String:
	match SlotType:
		0: return "Head"
		1: return "Neck"
		2: return "Ring"
		3: return "Body"
		4: return "Feet"
		5: return "Gloves"
	return ""

func get_weapon_index() -> int:
	return WeaponIndex

static func make_item_name_unique(itemname:String) -> String:
	if not itemname.is_empty() and itemname[-1] == "$":
		# this itemname already is unique! we'll "refresh" the uniqueness, so that
		# this function doesn't every return the same unique name...
		itemname = remove_item_name_uniqueness(itemname)
	return "%s$%d$" % [itemname, randi_range(100,999)]

static func remove_item_name_uniqueness(itemname:String) -> String:
	if itemname.length() <= 5:
		return itemname
	if itemname[-1] != "$" or itemname[-5] != "$":
		# this name already isn't unique!
		return itemname
	return itemname.left(-5)
