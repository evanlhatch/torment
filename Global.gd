extends Node

signal WorldReady
signal GoldAmountChanged(before:int, after:int)
signal MouseMovementChanged(mouse_only:bool, hold_only:bool)

const ProfilePass = "e4422259-b391-43d3-9284-5f37189420ed"
const ProfileXOR : int = 38481156
const ProfilePath = "HoT_profile.dat"
const PathSaveBackup = "HoT_profile_save_backup.dat"
const PathLoadBackup = "HoT_profile_load_backup.dat"
const PathPatchBackup = "HoT_profile_patch_backup.dat"
const MAX_VALUE : int = 9999999

# Set to true when the game is newly started.
# Used to show Title screen on startup.
var fresh_start : bool

var ChosenPlayerCharacterScene : PackedScene
var ChosenPlayerCharacterIdentifier : String

var QuestPool : Node
var ShrineBlessingPool : Node
var WellItemsPool : Node
var WorldsPool : Node
var PotionsPool : Node
var World : World
var SpriteAnimSys : SpriteAnimationControlSystem = SpriteAnimationControlSystem.new()

var PlayerProfile

var CurrentSettings
const SETTINGS_PATH = "user://settings.json"
const DEFAULT_SETTINGS = {
	"fullscreen" : true,
	"low_res": true,
	"cursor" : 1,
	"cursor_size" : 1,
	"volume_master" : 80.0,
	"volume_music" : 60.0,
	"volume_fx" : 80.0,
	"volume_voice" : 80.0,
	"aiming_line": false,
	"damage_numbers": true,
	"show_damage_numbers": true,
	"input_hint": true,
	"auto_aim": false,
	"auto_attack": false,
	"flash_modulation": 1.0,
	"pause_when_focus_lost": true,
	"mouse_only": false,
	"hold_only": false,
	"custom_keys": {},
	"ability_alpha": 1.0
}
@onready var FlashModulation : float = 1.0

var PlayerProfileSaveTimer : Timer
const MIN_PROFILE_SAVE_INTERVAL : float = 30.0
var _save_after_timeout_flag : bool

enum ApplyDamageResult {
	Invalid,
	Blocked,
	Invincible,
	DamagedButNotKilled,
	Killed,
	CheatedDeath
}

var _initializationDone := false
signal _initializationDoneSignal

var Cursors_Hand : Resource = preload("res://UI/Cursors/CursorCollection_Hand.tres")
var Cursors_Arrow : Resource = preload("res://UI/Cursors/CursorCollection_Arrow.tres")
var Cursors_Aim : Resource = preload("res://UI/Cursors/CursorCollection_Aim.tres")

enum PlatformInitResults {
	Initializing,
	SteamworksActive,
	SteamworksInitFailed,
	SteamNotRunning,
	InvalidAppIDOrNotInstalled
}
var PlatformInitResult : PlatformInitResults = PlatformInitResults.Initializing
func awaitPlatformInit():
	while PlatformInitResult == PlatformInitResults.Initializing:
		await get_tree().process_frame
var PlatformInitMessage : String

func _ready():
	var initReturn = Steam.steamInit(true)
	print("Steam Init: %s" % initReturn)
	PlatformInitMessage = initReturn.verbal
	match initReturn.status:
		1: # "Steamworks active"
			PlatformInitResult = PlatformInitResults.SteamworksActive
		20: # "Steam not running"
			PlatformInitResult = PlatformInitResults.SteamNotRunning
		79: # "Invalid app ID or app not installed"
			PlatformInitResult = PlatformInitResults.InvalidAppIDOrNotInstalled
		_:
			PlatformInitResult = PlatformInitResults.SteamworksInitFailed
	if PlatformInitResult != PlatformInitResults.SteamworksActive:
		return

	print("Host Audio Output Latency: %f" % AudioServer.get_output_latency())

	get_tree().set_auto_accept_quit(false)
	process_mode = PROCESS_MODE_ALWAYS

	fresh_start = true
	loadPlayerProfile()

	CurrentSettings = DEFAULT_SETTINGS.duplicate()
	load_settings_file()
	apply_settings()

	var questPoolScenePath := "res://GameElements/Quests/QuestPool.tscn"
	if OS.has_feature("demo"):
		questPoolScenePath = "res://GameElements/Quests/QuestPool_Demo.tscn"
	var shrineBlessingsPoolScenePath := "res://GameElements/ShrineBlessingsPool.tscn"
	var wellItemsPoolScenePath := "res://GameElements/WellItemsPool.tscn"
	var worldsPoolScenePath := "res://GameElements/WorldPool.tscn"
	var potionsPoolScenePath := "res://GameElements/PotionsPool.tscn"
	ResourceLoaderQueue.queueResource(questPoolScenePath)
	ResourceLoaderQueue.queueResource(shrineBlessingsPoolScenePath)
	ResourceLoaderQueue.queueResource(wellItemsPoolScenePath)
	ResourceLoaderQueue.queueResource(worldsPoolScenePath)
	ResourceLoaderQueue.queueResource(potionsPoolScenePath)

	await ResourceLoaderQueue.waitForLoadingFinished()

	var questPoolScene = ResourceLoaderQueue.getCachedResource(questPoolScenePath)
	QuestPool = questPoolScene.instantiate()
	add_child(QuestPool)

	var shrineBlessingsPoolScene = ResourceLoaderQueue.getCachedResource(shrineBlessingsPoolScenePath)
	ShrineBlessingPool = shrineBlessingsPoolScene.instantiate()
	add_child(ShrineBlessingPool)

	var wellItemsPoolScene = ResourceLoaderQueue.getCachedResource(wellItemsPoolScenePath)
	WellItemsPool = wellItemsPoolScene.instantiate()
	add_child(WellItemsPool)

	var worldsPoolScene = ResourceLoaderQueue.getCachedResource(worldsPoolScenePath)
	WorldsPool = worldsPoolScene.instantiate()
	add_child(WorldsPool)

	var potionsPoolScene = ResourceLoaderQueue.getCachedResource(potionsPoolScenePath)
	PotionsPool = potionsPoolScene.instantiate()
	add_child(PotionsPool)

	QuestPool.queue_resource_load()
	ShrineBlessingPool.queue_resource_load()
	WellItemsPool.queue_resource_load()

	await ResourceLoaderQueue.waitForLoadingFinished()

	QuestPool.instantiate_item_children()
	ShrineBlessingPool.instantiate_item_children()
	WellItemsPool.instantiate_item_children()

	PlayerProfileSaveTimer = Timer.new()
	add_child(PlayerProfileSaveTimer)
	PlayerProfileSaveTimer.one_shot = true
	PlayerProfileSaveTimer.stop()
	PlayerProfileSaveTimer.process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerProfileSaveTimer.connect("timeout", _on_profile_save_timer_timout)

	Patch.updateDevProfile()
	Patch.updateProfile()
	set_achievements_from_profile()
	Steam.storeStats()

	_initializationDone = true
	_initializationDoneSignal.emit()

	Steam.overlay_toggled.connect(overlay_toggled)

func _process(delta):
	Steam.run_callbacks()
	if not get_tree().paused:
		SpriteAnimSys.updateSpriteAnimationControl(delta)

func open_main_steam_page():
	print("steam button pressed")
	Steam.activateGameOverlayToStore(2218750)

func set_achievement(achievement : String):
	Steam.setAchievement(achievement)
	Steam.storeStats()

func set_achievements_from_profile():
	for quest in Global.QuestPool.get_all_quests():
		if quest.is_completed():
			Steam.setAchievement(quest.ID)

func open_discord_page():
	print("discord button pressed")
	OS.shell_open("https://discord.gg/chasingcarrots")

func overlay_toggled(active:bool):
	if active:
		GlobalMenus.pauseForOverlay()
	else:
		GlobalMenus.unpauseFromOverlay()

func awaitInitialization():
	if _initializationDone:
		return
	await _initializationDoneSignal

func attach_toWorld(node : Node, deferCall : bool = false):
	if World:
		# this is so that nodes can detach themselves from any
		# parent (add_child only works when the node doesn't already have a parent!)
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)

		if deferCall:
			World.call_deferred("add_child", node)
		else:
			World.add_child(node)


func get_gameObject_in_parents(node : Node) -> GameObject:
	while not node is GameObject:
		node = node.get_parent()
		if node == null:
			return null
	return node


func duplicate_gameObject_node(gameObject : GameObject) -> GameObject:
	var dupe : GameObject = gameObject.duplicate(
		Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_SIGNALS)
	var inheritMods : GameObject = gameObject.getInheritModifierFrom()
	if inheritMods != null:
		dupe.setInheritModifierFrom(inheritMods)
	return dupe


func is_world_ready() -> bool:
	return World != null

func awaitWorldReady():
	if World != null:
		return
	await WorldReady

func earnGold(goldAmount:int, saveImmediately:bool):
	PlayerProfile.Gold += goldAmount
	print("%d gold earned! You now have %d gold!" % [goldAmount, PlayerProfile.Gold])
	if saveImmediately: savePlayerProfile(true)
	else: schedulePlayerProfileSaving()
	GoldAmountChanged.emit(PlayerProfile.Gold - goldAmount, PlayerProfile.Gold)


func payGold(goldAmount:int, saveImmediately:bool) -> bool:
	if PlayerProfile.Gold < goldAmount:
		return false
	PlayerProfile.Gold -= goldAmount
	print("%d gold paid! You now have %d gold!" % [goldAmount, PlayerProfile.Gold])
	if saveImmediately: savePlayerProfile(true)
	else: schedulePlayerProfileSaving()

	GoldAmountChanged.emit(PlayerProfile.Gold + goldAmount, PlayerProfile.Gold)
	return true


func schedulePlayerProfileSaving():
	if PlayerProfileSaveTimer.time_left <= 0:
		savePlayerProfile(true)
		PlayerProfileSaveTimer.start(MIN_PROFILE_SAVE_INTERVAL)
	else:
		_save_after_timeout_flag = true


func _on_profile_save_timer_timout():
	if _save_after_timeout_flag:
		_save_after_timeout_flag = false
		savePlayerProfile(false)


func savePlayerProfile(backup:bool):
	if ProjectSettings.get_setting("halls_of_torment/development/use_dev_save"): return

	if backup:
		Patch.backupProfile(ProfilePath, PathSaveBackup, false)
	else:
		print("saving profile without backup")

	var byteBuf := var_to_bytes(PlayerProfile)
	for i in byteBuf.size():
		byteBuf[i] = byteBuf[i] ^ ProfileXOR
	Steam.fileWriteAsync(ProfilePath, byteBuf)


func loadPlayerProfile():
	# if we are in development mode, we don't load the profile
	if ProjectSettings.get_setting("halls_of_torment/development/use_dev_save"):
		Patch.startDevProfile()
		return

	# trying to load profile and backup files if the main file is valid
	var profile_data = loadFromProfileFile(ProfilePath)
	if profile_data != null: Patch.backupProfile(ProfilePath, PathLoadBackup, false)

	# if the main file is invalid, we try loading from the backup files
	if profile_data == null: profile_data = loadFromProfileFile(PathSaveBackup)
	if profile_data == null: profile_data = loadFromProfileFile(PathLoadBackup)
	if profile_data == null: profile_data = loadFromProfileFile(PathPatchBackup)
	# final try: load the old local prelude profile
	if profile_data == null: profile_data = loadFromProfileFileLOCAL("user://HoT_progress_profile.dat")

	# all files are either not found or invalid, no help but to create a new profile
	if profile_data == null:
		print("LOADING PROFILE: Player profile does not exist, creating new default profile.")
		PlayerProfile = Patch.DEFAULT_PLAYER_PROFILE
		savePlayerProfile(true)
		return

	# if we got here, we have a valid profile
	PlayerProfile = profile_data
	Patch.checkForProfileReset()


func loadFromProfileFile(profile_path:String):
	var profile = loadFromProfileFileSTEAM(profile_path)
	if profile != null:
		print("LOADING PROFILE: successfully loaded profile from steam cloudsave.")
		return profile
	return null

func loadFromProfileFileSTEAM(profile_path:String):
	if not Steam.fileExists(profile_path):
		print("LOADING PROFILE: Player profile does not exist in steam cloudsave: %s" % profile_path)
		return null

	var profileContentSize := Steam.getFileSize(profile_path)
	var profileReadDict = Steam.fileRead(profile_path, profileContentSize)
	if not profileReadDict["ret"]:
		printerr("LOADING PROFILE: Tried to load profile from steam cloudsave, but was unsuccessful")
		return null

	var byteBuf = profileReadDict["buf"]
	for i in byteBuf.size():
		byteBuf[i] = byteBuf[i] ^ ProfileXOR

	var data = bytes_to_var(byteBuf)

	if data == null:
		printerr("LOADING PROFILE: ERROR - Player profile was null: %s" % profile_path)
		return null
	return data

func doesLocalProfileExist() -> bool:
	var profile_path = "user://HoT_progress_profile.dat"
	return FileAccess.file_exists(profile_path)

func loadFromProfileFileLOCAL(profile_path:String):
	if not FileAccess.file_exists(profile_path):
		PlayerProfile = Patch.DEFAULT_PLAYER_PROFILE
		print("LOADING PROFILE: Player profile does not exist locally: %s" % profile_path)
		return null

	var profile = FileAccess.open_encrypted_with_pass(profile_path, FileAccess.READ, ProfilePass)
	if profile == null:
		profile = FileAccess.open(profile_path, FileAccess.READ)

	var jsonString = profile.get_as_text()
	var json = JSON.new()
	var error = json.parse(jsonString)
	if error == OK:
		var data = json.get_data()
		if data == null:
			printerr("LOADING PROFILE: ERROR - Player profile was null: %s" % profile_path)
			return null
		return data
	else:
		printerr("LOADING PROFILE: ERROR - data parsing failed: %s - %d" % [profile_path, error])
		return null


func integer_to_roman_string(integer:int) -> String:
	match(integer):
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
		6: return "VI"
		7: return "VII"
		8: return "VIII"
		9: return "IX"
		10: return "X"
		11: return "XI"
		12: return "XII"
		13: return "XIII"
		14: return "XIV"
		15: return "XV"
		16: return "XVI"
		17: return "XVII"
		18: return "XVIII"
		19: return "XIX"
		20: return "XX"
	return ""

func formatLargeNumber(num:int) -> String:
	var n : String = str(num)
	var size : int = n.length()
	var s : String
	for i in range(size):
		if((size - i) % 3 == 0 and i > 0):
			s = str(s," ", n[i])
		else:
			s = str(s,n[i])
	return s

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

@onready var _quitting : bool = false

func quit_game():
	if _quitting: return
	_quitting = true
	savePlayerProfile(true)
	await get_tree().process_frame
	if OS.has_feature("linux"):
		get_tree().quit()
	else:
		get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		await get_tree().process_frame
		OS.kill(OS.get_process_id())


#===============================================================================#
#							SETTINGS PERSISTENCE								#
#===============================================================================#
func load_settings_file():
	if not FileAccess.file_exists(SETTINGS_PATH):
		CurrentSettings = DEFAULT_SETTINGS.duplicate()
		save_settings_file()
		return
	var settings_file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var jsonString = settings_file.get_as_text()
	var json = JSON.new()
	var error = json.parse(jsonString)
	if error == OK:
		var data = json.get_data()
		if data != null:
			CurrentSettings = data
			for k in DEFAULT_SETTINGS.keys():
				if not CurrentSettings.has(k):
					CurrentSettings[k] = DEFAULT_SETTINGS[k]

	# move cursor to bottom right of viewport, in case player wants to play
	# with gamepad and not have the cursor obstruct the view.
	await get_tree().process_frame
	if CurrentSettings["fullscreen"]:
		var corner_pos = DisplayServer.window_get_position() + DisplayServer.window_get_size()
		Input.warp_mouse(corner_pos - Vector2i.ONE)


func save_settings_file():
	var settings_file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	var json = JSON.new()
	var json_string = JSON.stringify(CurrentSettings, "\t")
	settings_file.store_string(json_string)


signal SettingsApplied(setting_key:String)
func apply_settings(setting_key:String = ""):
	if setting_key.is_empty() or setting_key == "fullscreen":
		if CurrentSettings["fullscreen"]:
			if OS.get_name() == "Windows":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				# DisplayServer.window_set_position(Vector2.ZERO)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if setting_key.is_empty() or setting_key == "low_res":
		get_viewport().snap_2d_transforms_to_pixel = CurrentSettings["low_res"]
		get_tree().root.content_scale_mode = (
			Window.CONTENT_SCALE_MODE_VIEWPORT if CurrentSettings["low_res"]
			else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)

	if setting_key.is_empty() or setting_key == "volume_master":
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"),
			get_volume_in_db(CurrentSettings["volume_master"]))

	if setting_key.is_empty() or setting_key == "volume_music":
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Music"),
			get_volume_in_db(CurrentSettings["volume_music"]))
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Music_or_FX"),
			max(
				AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),
				AudioServer.get_bus_volume_db(AudioServer.get_bus_index("FX"))))

	if setting_key.is_empty() or setting_key == "volume_fx":
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("FX"),
			get_volume_in_db(CurrentSettings["volume_fx"]))
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Music_or_FX"),
			max(
				AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),
				AudioServer.get_bus_volume_db(AudioServer.get_bus_index("FX"))))

	if setting_key.is_empty() or setting_key == "volume_voice":
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Voice"),
			get_volume_in_db(CurrentSettings["volume_voice"]))

	if setting_key.is_empty() or setting_key == "cursor" or setting_key == "cursor_size":
		var cursor : CursorData = Cursors_Hand.Cursors[CurrentSettings["cursor_size"]]
		var cursor_index : int = CurrentSettings["cursor"]
		match(cursor_index):
			0: cursor = Cursors_Hand.Cursors[CurrentSettings["cursor_size"]]
			1: cursor = Cursors_Arrow.Cursors[CurrentSettings["cursor_size"]]
			2: cursor = Cursors_Aim.Cursors[CurrentSettings["cursor_size"]]
		if cursor != null:
			Input.set_custom_mouse_cursor(cursor.CursorImage, Input.CURSOR_ARROW, cursor.CursorHotspotOffset)

	if setting_key.is_empty() or setting_key == "damage_numbers":
		Fx._text_indicators_enabled = CurrentSettings["damage_numbers"]

	if setting_key.is_empty() or setting_key == "aiming_line":
		set_aiming_line_visibility(CurrentSettings["aiming_line"])

	if setting_key.is_empty() or setting_key == "auto_aim":
		set_auto_aim(CurrentSettings["auto_aim"])

	if setting_key.is_empty() or setting_key == "auto_attack":
		set_auto_attack(CurrentSettings["auto_attack"])

	if setting_key.is_empty() or setting_key == "mouse_only":
		set_mouse_only_mode(CurrentSettings["mouse_only"])

	if setting_key.is_empty() or setting_key == "hold_only":
		set_hold_only_movement_mode(CurrentSettings["hold_only"])

	if setting_key.is_empty() or setting_key == "flash_modulation":
		FlashModulation = ease(CurrentSettings["flash_modulation"], 2)

	if setting_key.is_empty() or setting_key == "ability_alpha":
		RenderingServer.global_shader_parameter_set("ABILITY_ALPHA", CurrentSettings["ability_alpha"])

	if setting_key.is_empty() or setting_key == "pause_when_focus_lost":
		pass

	SettingsApplied.emit(setting_key)


func get_volume_in_db(settings_value:float) -> float:
	var volume_factor = ease(settings_value * 0.01, 0.6)
	var volume = lerp(-40.0, 0.0, volume_factor)
	if volume <=-40.0: volume = -80.0
	return volume

func set_aiming_line_visibility(aim_line_active:bool):
	if Global.is_world_ready() and Global.World.Player != null:
		var player = Global.World.Player
		if player.has_node("KinematicMover/AimLine"):
			var aim_line = player.get_node("KinematicMover/AimLine")
			aim_line.visible = aim_line_active

func set_auto_aim(auto_aim_active:bool):
	if Global.is_world_ready() and Global.World.Player != null:
		var player = Global.World.Player
		if player.has_node("PlayerInput"):
			var playerInput = player.get_node("PlayerInput")
			playerInput.auto_aim = auto_aim_active
			#if not auto_aim_active:
			#	for emitter in playerInput._bulletEmitter:
			#		emitter.set_emitting(false)

func set_auto_attack(auto_attack_active:bool):
	if Global.is_world_ready() and Global.World.Player != null:
		var player = Global.World.Player
		if player.has_node("PlayerInput"):
			var playerInput = player.get_node("PlayerInput")
			playerInput.autoEmitToggle = auto_attack_active
			for emitter in playerInput._bulletEmitter:
				emitter.set_emitting(auto_attack_active)

func set_mouse_only_mode(mouse_only_mode_active:bool):
	MouseMovementChanged.emit(mouse_only_mode_active, CurrentSettings["hold_only"])

func set_hold_only_movement_mode(hold_only_mode_active:bool):
	MouseMovementChanged.emit(CurrentSettings["mouse_only"], hold_only_mode_active)

func write_scene_tree_info():
	var objects : Dictionary = {}
	var allObjects : Array[Node] = get_parent().get_children()
	var currentIndex : int = 0
	while currentIndex < allObjects.size():
		var currentName : String = allObjects[currentIndex].name
		if currentName[0] == "@":
			currentName = currentName.substr(1, currentName.rfind("@")-1)
		if objects.has(currentName):
			objects[currentName] += 1
		else:
			objects[currentName] = 1
		allObjects.append_array(allObjects[currentIndex].get_children())
		currentIndex += 1
	var file := FileAccess.open("scenetreeinfo.csv", FileAccess.WRITE)
	if file == null:
		printerr("cannot write to scenetreeinfo.csv. is it opened elsewhere?")
	for objectName in objects:
		file.store_line("%s,%d"%[objectName, objects[objectName]])


