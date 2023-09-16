## This node has to be a direct child of a Reviver node!

extends Node

@export var RemoveRandomOtherItemFirst : bool = false

func _enter_tree():
	var parent = get_parent()
	if !parent.has_signal("Revived"):
		printerr("ReviverChildItemRemover has to be a direct child of a Reviver Node!")
		return
	parent.Revived.connect(reviveWasTriggered)

func reviveWasTriggered():
	var parent = get_parent()
	if not parent:
		return
	var reviveBelongsToItem = Global.World.ItemPool.find_equipped_item_with_modifier(parent)
	if not reviveBelongsToItem:
		printerr("ReviverChildItemRemover could not find the item it belongs to!")
		return
	if RemoveRandomOtherItemFirst:
		var allItems : Array[Node] = Global.World.ItemPool.get_equipped_items_as_array()
		allItems.erase(reviveBelongsToItem)
		if allItems.size() > 0:
			var removeItemIndex = randi_range(0, allItems.size()-1)
			Global.World.ItemPool.remove_item(allItems[removeItemIndex])
			return
	
	Global.World.ItemPool.remove_item(reviveBelongsToItem)
