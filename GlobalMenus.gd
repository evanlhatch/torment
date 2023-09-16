extends CanvasLayer

var title : Control
var worldUI : Control
var debugIU : Control
var pauseUI : Control
var traitSelectionUI : Control
var abilitySelectionUI : Control
var itemPickupUI : Control
var playerDiedUI : Control
var playerSurvivedUI : Control
var hud : Control
var hudOverworld : Control
var questsUI : Control
var questToast : Control
var blessingShrineUI : Control
var reviveScreenUI : Control
var pauseUIOverworld : Control
var storyDialogueUI : Control
var itemPurchaseUI : Control
var itemSacrificeUI : Control
var itemStashUI : Control
var registerOfHallsUI : Control
var creditsUI : Control
var potionsUI : Control

# Transition screen must always be on top (i.e. last in hierarchy)!
var transition : Control

# This is only for showing a transparent text in the bottom right corner
var watermark : CanvasLayer

# Called whenever a modal dialogue is opened or closed
signal ModalDialogStateChanged(modalDialogVisible:bool)

enum InputMethod { MouseAndKeyboard, Gamepad }
var currentInputMethod : InputMethod
signal InputMethodChanged(newInputMethod:InputMethod)

var _modal_dialog_state : bool
func _on_modal_dialog_state_changed(new_state : bool):
	_modal_dialog_state = new_state

func _ready():
	ModalDialogStateChanged.connect(_on_modal_dialog_state_changed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# await Global.awaitInitialization()

	worldUI = load("res://UI/WorldUI.tscn").instantiate()
	add_child(worldUI)
	worldUI.visible = false

	debugIU = load("res://UI/DebugMenuUI.tscn").instantiate()
	add_child(debugIU)
	debugIU.visible = false

	pauseUI = load("res://UI/PauseMenuUI.tscn").instantiate()
	add_child(pauseUI)
	pauseUI.visible = false

	itemPickupUI = load("res://UI/PickUpItemUI.tscn").instantiate()
	add_child(itemPickupUI)
	itemPickupUI.visible = false

	playerDiedUI = load("res://UI/PlayerDiedUI.tscn").instantiate()
	add_child(playerDiedUI)
	playerDiedUI.visible = false

	playerSurvivedUI = load("res://UI/PlayerSurvivedUI.tscn").instantiate()
	add_child(playerSurvivedUI)
	playerSurvivedUI.visible = false

	traitSelectionUI = load("res://UI/TraitSelection.tscn").instantiate()
	add_child(traitSelectionUI)
	traitSelectionUI.visible = false

	abilitySelectionUI = load("res://UI/AbilitySelection.tscn").instantiate()
	add_child(abilitySelectionUI)
	abilitySelectionUI.visible = false

	itemSacrificeUI = load("res://UI/SacrificeItemUI.tscn").instantiate()
	add_child(itemSacrificeUI)
	itemSacrificeUI.visible = false

	hud = load("res://UI/HUD_vertical.tscn").instantiate()
	add_child(hud)
	hud.visible = false

	questsUI = load("res://UI/QuestsMenu.tscn").instantiate()
	add_child(questsUI)
	questsUI.visible = false

	blessingShrineUI = load("res://UI/BlessingShrineMenu.tscn").instantiate()
	add_child(blessingShrineUI)
	blessingShrineUI.visible = false

	itemPurchaseUI = load("res://UI/ItemPurchaseUI.tscn").instantiate()
	add_child(itemPurchaseUI)
	itemPurchaseUI.visible = false

	itemStashUI = load("res://UI/ItemStashUI.tscn").instantiate()
	add_child(itemStashUI)
	itemStashUI.visible = false

	registerOfHallsUI = load("res://UI/RegisterofHallsMenu.tscn").instantiate()
	add_child(registerOfHallsUI)
	registerOfHallsUI.visible = false

	creditsUI = load("res://UI/CreditsMenu.tscn").instantiate()
	add_child(creditsUI)
	creditsUI.visible = false

	potionsUI = load("res://UI/PotionsUI.tscn").instantiate()
	add_child(potionsUI)
	potionsUI.visible = false

	hudOverworld = load("res://UI/HUD_Overworld.tscn").instantiate()
	add_child(hudOverworld)

	pauseUIOverworld = load("res://UI/OverworldMenuUI.tscn").instantiate()
	add_child(pauseUIOverworld)
	pauseUIOverworld.visible = false

	storyDialogueUI = load("res://UI/StoryDialogueUI.tscn").instantiate()
	add_child(storyDialogueUI)
	storyDialogueUI.visible = false

	reviveScreenUI = load("res://UI/ReviveScreen.tscn").instantiate()
	add_child(reviveScreenUI)
	reviveScreenUI.visible = false

	questToast = load("res://UI/QuestToast.tscn").instantiate()
	add_child(questToast)

	title = load("res://UI/Logo/Logo.tscn").instantiate()
	add_child(title)

	transition = load("res://UI/Transition.tscn").instantiate()
	add_child(transition)

	watermark = load("res://UI/watermark.tscn").instantiate()
	add_child(watermark)

	GameState.connect("StateChanged", onStateChanged)


# We need to use this flag to check whether the player has tried changed the pause
# state recently, to avoid interference with coroutines when unpausing.
var _pause_flag : bool

func pauseGame():
	_pause_flag = true
	get_tree().paused = true


func pauseForOverlay():
	get_tree().paused = true

func unpauseFromOverlay():
	if _pause_flag: return

	await get_tree().create_timer(0.3, true, false, true).timeout
	if _pause_flag:
		return
	get_tree().paused = false
	Engine.time_scale = 0.1
	while Engine.time_scale < 1.0:
		await get_tree().process_frame
		Engine.time_scale = clamp(Engine.time_scale + 0.03, 0.1, 1.0)


func unpauseGame(unpause_delay:float = 0.3, ramp_up_time_scale:bool = true):
	if not _pause_flag:
		return # don't do anything if the game is already being unpaused (by another previous coroutine)

	_pause_flag = false
	if unpause_delay > 0.0:
		await get_tree().create_timer(unpause_delay, true, false, true).timeout
		if _pause_flag:
			return # Player has paused the game again in the meantime --> do nothing
	get_tree().paused = false

	# ramp up time_scale after leaving pause
	if ramp_up_time_scale:
		Engine.time_scale = 0.1
		while Engine.time_scale < 1.0:
			await get_tree().process_frame
			Engine.time_scale = clamp(Engine.time_scale + 0.03, 0.1, 1.0)


func onStateChanged(newState:GameState.States, oldState:GameState.States):
	if newState == GameState.States.Debug:
		pauseGame()
		debugIU.visible = true
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.Debug:
		unpauseGame()
		debugIU.visible = false

	if newState == GameState.States.Paused:
		pauseGame()
		pauseUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.Paused:
		unpauseGame()
		pauseUI.visible = false

	if newState == GameState.States.StoryDialogue:
		pauseGame()
		storyDialogueUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.StoryDialogue:
		unpauseGame()
		storyDialogueUI.visible = false

	if newState == GameState.States.TraitSelection and oldState != GameState.States.PlayerDied:
		pauseGame()
		traitSelectionUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() -1)
	elif oldState == GameState.States.TraitSelection:
		unpauseGame()
		traitSelectionUI.visible = false

	if newState == GameState.States.AbilitySelection and oldState != GameState.States.PlayerDied:
		pauseGame()
		abilitySelectionUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() -1)
	elif oldState == GameState.States.AbilitySelection:
		unpauseGame()
		abilitySelectionUI.visible = false

	if newState == GameState.States.ItemPickup and oldState != GameState.States.PlayerDied:
		pauseGame()
		itemPickupUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() -1)
	elif oldState == GameState.States.ItemPickup:
		unpauseGame()
		itemPickupUI.visible = false

	if newState == GameState.States.ItemSacrifice and oldState != GameState.States.PlayerDied:
		pauseGame()
		itemSacrificeUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() -1)
	elif oldState == GameState.States.ItemSacrifice:
		unpauseGame()
		itemSacrificeUI.visible = false

	if newState == GameState.States.PlayerDied:
		playerDiedUI.visible = true
		playerDiedUI.fadeIn()
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.PlayerDied:
		playerDiedUI.visible = false

	if newState == GameState.States.PlayerSurvived:
		playerSurvivedUI.visible = true
		playerSurvivedUI.fadeIn()
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.PlayerSurvived:
		playerSurvivedUI.visible = false

	if newState == GameState.States.ReviveScreen:
		reviveScreenUI.visible = true
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	elif oldState == GameState.States.ReviveScreen:
		reviveScreenUI.visible = false

	if newState == GameState.States.OverworldMenu:
		pauseUIOverworld.visible = true
	elif oldState == GameState.States.OverworldMenu:
		pauseUIOverworld.visible = false

	if newState == GameState.States.ItemPurchase:
		itemPurchaseUI.visible = true
	elif oldState == GameState.States.ItemPurchase:
		itemPurchaseUI.visible = false

	if newState == GameState.States.ItemStash:
		itemStashUI.visible = true
	elif oldState == GameState.States.ItemStash:
		itemStashUI.visible = false

	if newState == GameState.States.RegisterOfHalls:
		registerOfHallsUI.visible = true
	elif oldState == GameState.States.RegisterOfHalls:
		registerOfHallsUI.visible = false

	if newState == GameState.States.Credits:
		creditsUI.visible = true
	elif oldState == GameState.States.Credits:
		creditsUI.visible = false

	if newState == GameState.States.Potions:
		potionsUI.visible = true
	elif oldState == GameState.States.Potions:
		potionsUI.visible = false

	hud.visible = (
		newState == GameState.States.Paused or
		newState == GameState.States.InGame or
		newState == GameState.States.TraitSelection or
		newState == GameState.States.AbilitySelection or
		newState == GameState.States.ItemPickup or
		newState == GameState.States.StoryDialogue or
		newState == GameState.States.ItemSacrifice)
	worldUI.visible = hud.visible

	if (newState == GameState.States.StoryDialogue and
		oldState == GameState.States.Overworld):
		hud.visible = false

	hudOverworld.visible = (
		newState == GameState.States.Overworld or
		newState == GameState.States.Quests or
		newState == GameState.States.BlessingShrine or
		newState == GameState.States.StoryDialogue or
		newState == GameState.States.ItemPurchase or
		newState == GameState.States.ItemStash or
		newState == GameState.States.RegisterOfHalls or
		newState == GameState.States.Credits or
		newState == GameState.States.Potions)

	if (newState == GameState.States.StoryDialogue and
		oldState == GameState.States.InGame):
		hudOverworld.visible = false

	questsUI.visible = newState == GameState.States.Quests
	blessingShrineUI.visible = newState == GameState.States.BlessingShrine


func _notification(what):

	if GameState.CurrentState == GameState.States.InGame:
		if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and Global.CurrentSettings["pause_when_focus_lost"]:
			GameState.SetState(GameState.States.Paused)


func _process(_delta):
#ifdef USE_STATISTICS
#	if ProjectSettings.get_setting("halls_of_torment/development/use_statistics"):
#		if Input.is_action_just_pressed("LeftBalancingNext"):
#			hud.BalanceDisplayLeft.switch_through_types(1)
#		elif Input.is_action_just_pressed("LeftBalancingPrev"):
#			hud.BalanceDisplayLeft.switch_through_types(-1)
#		elif Input.is_action_just_pressed("RightBalancingNext"):
#			hud.BalanceDisplayRight.switch_through_types(1)
#		elif Input.is_action_just_pressed("RightBalancingPrev"):
#			hud.BalanceDisplayRight.switch_through_types(-1)
#		elif Input.is_action_just_pressed("ToggleLeftStatistics"):
#			hud.toggle_left_statistics()
#		elif Input.is_action_just_pressed("ToggleRightStatistics"):
#			hud.toggle_right_statistics()
#endif

	if Input.is_action_just_pressed("DebugMenu") and ProjectSettings.get_setting("halls_of_torment/development/use_debug"):
		if GameState.CurrentState == GameState.States.InGame:
			GameState.SetState(GameState.States.Debug)
			print("totalDPS: %s" % Stats.GetDPS())
			var statWeapons = Stats.GetDamagingWeaponIndices()
			for weapon in statWeapons:
				print("weapon %s: TotalDamage=%s  MaxDPS=%s" % [weapon, Stats.GetTotalDamageOfWeapon(weapon), Stats.GetMaxDPSOfWeapon(weapon)])
		elif GameState.CurrentState == GameState.States.Debug:
			GameState.SetState(GameState.States.InGame)

	if Input.is_action_just_pressed("Pause"):
		if title != null and not title.is_queued_for_deletion() and title.reveal_finished:
			if GameState.CurrentState == GameState.States.Overworld:
				GameState.SetState(GameState.States.OverworldMenu)
				return
		if title == null or title.is_queued_for_deletion():
			if GameState.CurrentState == GameState.States.InGame:
				GameState.SetState(GameState.States.Paused)
			elif (GameState.CurrentState == GameState.States.Paused and not _modal_dialog_state):
				GameState.SetState(GameState.States.InGame)
			elif GameState.CurrentState == GameState.States.Overworld:
				GameState.SetState(GameState.States.OverworldMenu)
			elif (GameState.CurrentState == GameState.States.BlessingShrine or
				GameState.CurrentState == GameState.States.Quests or
				GameState.CurrentState == GameState.States.ItemPurchase or
				GameState.CurrentState == GameState.States.RegisterOfHalls or
				GameState.CurrentState == GameState.States.Credits or
				GameState.CurrentState == GameState.States.Potions):
					GameState.SetState(GameState.States.Overworld)
			elif ((GameState.CurrentState == GameState.States.ItemStash and not _modal_dialog_state) or
				(GameState.CurrentState == GameState.States.OverworldMenu and not _modal_dialog_state)):
				GameState.SetState(GameState.States.Overworld)

	# Additionally use cancel button in overworld to close menus.
	if Input.is_action_just_pressed("cancel"):
		if (GameState.CurrentState == GameState.States.BlessingShrine or
			GameState.CurrentState == GameState.States.Quests or
			GameState.CurrentState == GameState.States.ItemPurchase or
			GameState.CurrentState == GameState.States.RegisterOfHalls or
			GameState.CurrentState == GameState.States.Credits or
			GameState.CurrentState == GameState.States.Potions):
				GameState.SetState(GameState.States.Overworld)
		if ((GameState.CurrentState == GameState.States.ItemStash and not _modal_dialog_state) or
				(GameState.CurrentState == GameState.States.OverworldMenu and not _modal_dialog_state)):
			GameState.SetState(GameState.States.Overworld)

	if Input.is_action_just_pressed("Fullscreen"):
		pauseUIOverworld.SettingsUI.toggle_fullscreen()
		pauseUI.SettingsUI.FullscreenSwitch.button_pressed = (
			pauseUIOverworld.SettingsUI.FullscreenSwitch.button_pressed)
	check_input_method()


var keyboardUsed : bool
var gamepadUsed : bool
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			keyboardUsed = true
			return
		keyboardUsed = false
	elif event is InputEventJoypadButton:
		if event.pressed:
			gamepadUsed = true
			return
		gamepadUsed = false
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.2:
			gamepadUsed = true
			return
		gamepadUsed = false


func check_input_method():
	if currentInputMethod == InputMethod.Gamepad:
		if (keyboardUsed or
			Input.get_last_mouse_velocity().length_squared() > 64.0 or
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			keyboardUsed = false
			currentInputMethod = InputMethod.MouseAndKeyboard
			InputMethodChanged.emit(currentInputMethod)
	elif currentInputMethod == InputMethod.MouseAndKeyboard:
		if gamepadUsed:
			currentInputMethod = InputMethod.Gamepad
			InputMethodChanged.emit(currentInputMethod)
