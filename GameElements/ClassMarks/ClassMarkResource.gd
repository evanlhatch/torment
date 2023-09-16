extends Resource
class_name ClassMarkResource

@export var Icon : Texture2D
@export var Name : String
@export_multiline var Description : String
@export var ActivatesTag : String
@export var Modifiers : Array[PackedScene]
@export var UnlockedByQuestID : String

@export_group("Unused Stub Properties")
@export var Rarity : int = 0
@export var SlotType : int = 7

# stub function, so resource can be passed on to InventorySlot safely
func get_well_state() -> Item.ItemWellState:
	return Item.ItemWellState.NONE
