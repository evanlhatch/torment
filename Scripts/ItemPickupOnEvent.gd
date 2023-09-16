extends GameObjectComponent

enum ItemPickupType
{
	RegularItems,
	Bottles,
	ChampionItems
}

@export_enum("Collected", "Touched") var OnEvent : int
@export var DestroyOnEvent : bool
@export var PickupType : ItemPickupType

func _ready():
	initGameObjectComponent()
	if OnEvent == 0:
		_gameObject.connectToSignal("Collected", show_item_pickup_screen)
	if OnEvent == 1:
		_gameObject.connectToSignal("Touched", show_item_pickup_screen)


func show_item_pickup_screen():
	if Global.World.Player == null:
		return # player died in the meantime --> don't do anything...
	
	# grace period when player picks up a chest --> don't allow damage for 500ms
	var playerHealth = Global.World.Player.getChildNodeWithMethod("setInvincibleForTime")
	playerHealth.setInvincibleForTime(0.5)
	
	GlobalMenus.itemPickupUI.fill_chest(PickupType)
	GameState.SetState(GameState.States.ItemPickup)
	if DestroyOnEvent:
		_gameObject.queue_free()
