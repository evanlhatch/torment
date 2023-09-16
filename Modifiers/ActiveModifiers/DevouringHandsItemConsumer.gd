## This node has to be a direct child of a Reviver node!

extends Node

var _chosenItemToRemove:Node

func _enter_tree():
	var parent = get_parent()
	if !parent.has_signal("Revived"):
		printerr("DevouringHandsItemConsumer has to be a direct child of a Reviver Node!")
		return
	parent.Revived.connect(reviveWasTriggered)

func modifyReviveTextBeforeRevive(currentReviveText:String) -> String:
	# we use this callback to choose the item, which we want to devour
	# when the revive is triggered afterwards!
	var parent = get_parent()
	if not parent:
		return currentReviveText
	_chosenItemToRemove = Global.World.ItemPool.find_equipped_item_with_modifier(parent)
	if not _chosenItemToRemove:
		printerr("DevouringHandsItemConsumer could not find the item it belongs to!")
		return currentReviveText
	var allItems : Array[Node] = Global.World.ItemPool.get_equipped_items_as_array()
	allItems.erase(_chosenItemToRemove)
	if allItems.size() > 0:
		var removeItemIndex = randi_range(0, allItems.size()-1)
		_chosenItemToRemove = allItems[removeItemIndex]
		currentReviveText += "\nBut it comes at a high cost: Devouring Hands has devoured your %s!" % _chosenItemToRemove.Name
	else:
		currentReviveText += "\nDevouring Hands didn't find any other Items to devour, so it has to perish itself."
	return currentReviveText
		
func reviveWasTriggered():
	if _chosenItemToRemove == null:
		printerr("DevouringHandsItemConsumer: something went wrong and we don't have an item to consume!?")
		return
	Global.World.ItemPool.remove_item(_chosenItemToRemove)
			
	
