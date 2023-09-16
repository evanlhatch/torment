extends GameObjectComponent

@export_enum("Collected", "Touched") var OnEvent : int
@export var DestroyOnEvent : bool

func _ready():
	initGameObjectComponent()
	if OnEvent == 0:
		_gameObject.connectToSignal("Collected", show_ability_pickup_screen)
	if OnEvent == 1:
		_gameObject.connectToSignal("Touched", show_ability_pickup_screen)


func show_ability_pickup_screen():
	if Global.World.Player == null:
		return # player died in the meantime --> don't do anything...

	# grace period when player picks up a chest --> don't allow damage for 500ms
	var playerHealth = Global.World.Player.getChildNodeWithMethod("setInvincibleForTime")
	playerHealth.setInvincibleForTime(0.5)

	GlobalMenus.abilitySelectionUI.roll_abilities()
	GameState.SetState(GameState.States.AbilitySelection)
	if DestroyOnEvent:
		_gameObject.queue_free()
