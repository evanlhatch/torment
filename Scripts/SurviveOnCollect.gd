extends GameObjectComponent

@export_enum("Collected", "Touched") var OnEvent : int
@export var DestroyOnEvent : bool

func _ready():
	initGameObjectComponent()
	if OnEvent == 0:
		_gameObject.connectToSignal("Collected", show_survive_screen)
	if OnEvent == 1:
		_gameObject.connectToSignal("Touched", show_survive_screen)


func show_survive_screen():
	Global.World.GainExperience = false
	var playerHealth = Global.World.Player.getChildNodeWithMethod("setInvincibleForTime")
	if playerHealth != null: playerHealth.setInvincibleForTime(99999)
	GameState.SetState(GameState.States.PlayerSurvived)

	# put all bottles in player's bag into stash, they've earned it!
	for item in Global.World.ItemPool.StoredItems:
		if item.SlotType == 6:
			var potion : PotionResource = Global.PotionsPool.get_potion_for_item(item.ItemID)
			if potion == null:
				printerr("Could not find potion for item %s!" % item.ItemID)
				continue
			else:
				var currentAmount : int = 0
				if Global.PlayerProfile.has(potion.AmountProfileFieldName):
					currentAmount = Global.PlayerProfile[potion.AmountProfileFieldName]
				if currentAmount >= potion.MaxAmount:
					printerr("Cannot acquire %s, max amount has been reached." % potion.PotionName)
					continue
				currentAmount += 1
				Global.PlayerProfile[potion.AmountProfileFieldName] = currentAmount
				Global.savePlayerProfile(true)

	if DestroyOnEvent:
		_gameObject.queue_free()
