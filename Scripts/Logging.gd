extends Node

const SessionLogPath = "user://session_logs/{year}_{month}_{day}____{hour}_{minute}.txt"
const LineFormat = "%04d.%03d;%s"

#===============================================================================#
#							GENERAL LOG SWITCH									#
const LOGGING_ACTIVE : bool = false
#===============================================================================#


const EVENT_HIT = 1
const EVENT_HIT_CRIT = 2
const EVENT_KILL = 3
const EVENT_BLOCK = 4
const EVENT_PICKUP = 5
const EVENT_ITEM_EQUIP = 6
const EVENT_ITEM_UNEQUIP = 7
const EVENT_LEVELUP = 8
const EVENT_HEAL = 9
const EVENT_ABILITY_GET = 10
const EVENT_TRAIT_GET = 11
const EVENT_SESSION_ABANDONED = 12

var log_data : Array
var log_file : FileAccess
var name_regex : RegEx

func _ready():
	if not LOGGING_ACTIVE: return
	name_regex = RegEx.new()
	name_regex.compile("@([a-zA-Z_0-9]*)@")
	Global.connect("WorldReady", _create_new_log)
	GameState.connect("StateChanged", _on_game_state_changed)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_logging()


func _create_new_log():
	log_data = []
	var date = Time.get_date_dict_from_system()
	var time = Time.get_time_dict_from_system()
	var log_path = SessionLogPath.format({
		"year": date.year,
		"month": "%02d" % date.month,
		"day": "%02d" % date.day,
		"hour": "%02d" % time.hour,
		"minute": "%02d" % time.minute
	})
	print("Writing session log to: %s" % log_path)
	
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("session_logs"):
		dir.make_dir("session_logs")
	
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	write_simple("%d-%02d-%02d %02d:%02d" % [
		date.year, date.month, date.day,
		time.hour, time.minute
	])
	write_simple("Halls of Torment, version %s" % ProjectSettings.get_setting("application/config/version"))
	write_simple("Playing as: %s" % Global.World.Player.name)
	write_simple("In world: %s" % Global.World.WorldName)

func _on_game_state_changed(newState, _oldState):
	if newState == GameState.States.Overworld:
		stop_logging()

func stop_logging():
	if log_file:
		log_file = null

func write_simple(log_line:String):
	if log_file == null: return
	log_file.store_line(log_line)


func log_damage_event(source:Node, target:Node, damageAmount:int, critical:bool, weapon_index:int):
	if not LOGGING_ACTIVE: return
	var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
	var actualDamageSource = source
	if actualDamageSource != null:
		if source.has_method("get_rootSourceGameObject"):
			actualDamageSource = source.get_rootSourceGameObject()
		elif source.has_method("get_externalSource"):
			actualDamageSource = source.get_externalSource()
	
	if critical:
		log_data.append([
			EVENT_HIT_CRIT,
			gameTime,
			(get_game_object_name(actualDamageSource) if actualDamageSource != null
			else "?MISSING SOURCE?: %s" % get_game_object_name(source)),
			get_game_object_name(target),
			damageAmount,
			weapon_index
		])
	else:
		log_data.append([
			EVENT_HIT,
			gameTime,
			(get_game_object_name(actualDamageSource) if actualDamageSource != null
			else "?MISSING SOURCE?: %s" % get_game_object_name(source)),
			get_game_object_name(target),
			damageAmount,
			weapon_index
		])

func log_kill_event(killer:Node, killed:Node):
	if not LOGGING_ACTIVE: return
	var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
	var actualKiller = killer
	if killer != null:
		var rootSourceProvider = killer.getChildNodeWithMethod("get_rootSourceGameObject")
		if rootSourceProvider != null:
			actualKiller = rootSourceProvider.get_rootSourceGameObject()
	log_data.append([
		EVENT_KILL,
		gameTime,
		get_game_object_name(actualKiller),
		get_game_object_name(killed)
	])


func log_block_event(attacker:Node, blocker:Node):
	if not LOGGING_ACTIVE: return
	var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
	var actualAttacker = attacker
	if attacker != null:
		var rootSourceProvider = attacker.getChildNodeWithMethod("get_rootSourceGameObject")
		if rootSourceProvider != null:
			actualAttacker = rootSourceProvider.get_rootSourceGameObject()
	log_data.append([
		EVENT_BLOCK,
		gameTime,
		get_game_object_name(actualAttacker),
		get_game_object_name(blocker)
	])

func log_pickup(pickup_type:String, value:float):
	if not LOGGING_ACTIVE: return
	var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
	log_data.append([EVENT_PICKUP, gameTime, pickup_type, value])

func log_levelup(level:int):
	if not LOGGING_ACTIVE: return
	var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
	log_data.append([EVENT_LEVELUP, gameTime, level])

func log_item_equip(item_name:String):
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready():
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_ITEM_EQUIP, gameTime, item_name])

func log_item_unequip(item_name:String):
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready():
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_ITEM_UNEQUIP, gameTime, item_name])

func log_heal(heal_source:String, heal_amount:int):
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready():
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_HEAL, gameTime, heal_source, heal_amount])

func log_ability_get(ability_name:String):
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready():
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_ABILITY_GET, gameTime, ability_name])

func log_trait_get(trait_name:String):
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready():
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_TRAIT_GET, gameTime, trait_name])

func log_session_abandoned():
	if not LOGGING_ACTIVE: return
	if Global.is_world_ready() and log_file != null:
		var gameTime = Global.World.DEFAULT_GAME_TIME - Global.World.GameTime
		log_data.append([EVENT_SESSION_ABANDONED, gameTime])

func data_to_file():
	if not LOGGING_ACTIVE: return
	if log_file == null: return
	print("writing log to file: %d entries" % len(log_data))
	for e in log_data:
		var entry = e
		var envent_type = entry.pop_front()
		var game_time = entry.pop_front()
		entry.push_front(int(floor(game_time * 1000)) % 1000)
		entry.push_front(floor(game_time))
		match(envent_type):
			EVENT_HIT:
				if entry[5] < 1000: # We agreed upon that ability weapon indices are always >= 1000
					entry[5] = Global.World.ItemPool.get_item_name_from_weapon_index(entry[5])
				else:
					entry[5] = Global.World.AbilityPool.get_ability_name_from_weapon_index(entry[5])
				entry[2] = get_clean_game_object_name(entry[2])
				entry[3] = get_clean_game_object_name(entry[3])
				Logging.write_simple("%04d.%03d;HIT;%s;%s;%d;%s" % entry)
			EVENT_HIT_CRIT:
				if entry[5] < 1000: # We agreed upon that ability weapon indices are always >= 1000
					entry[5] = Global.World.ItemPool.get_item_name_from_weapon_index(entry[5])
				else:
					entry[5] = Global.World.AbilityPool.get_ability_name_from_weapon_index(entry[5])
				entry[2] = get_clean_game_object_name(entry[2])
				entry[3] = get_clean_game_object_name(entry[3])
				Logging.write_simple("%04d.%03d;HIT (CRIT);%s;%s;%d;%s" % entry)
			EVENT_KILL:
				entry[2] = get_clean_game_object_name(entry[2])
				entry[3] = get_clean_game_object_name(entry[3])
				Logging.write_simple("%04d.%03d;KILL;%s;%s" % entry)
			EVENT_BLOCK:
				entry[2] = get_clean_game_object_name(entry[2])
				entry[3] = get_clean_game_object_name(entry[3])
				Logging.write_simple("%04d.%03d;BLOCK;%s;%s" % entry)
			EVENT_PICKUP: Logging.write_simple("%04d.%03d;PICKUP;%s;%d" % entry)
			EVENT_ITEM_EQUIP: Logging.write_simple("%04d.%03d;ITEM UNEQUIP;%s" % entry)
			EVENT_ITEM_UNEQUIP: Logging.write_simple("%04d.%03d;ITEM EQUIP;%s" % entry)
			EVENT_LEVELUP: Logging.write_simple("%04d.%03d;LEVEL UP;%d" % entry)
			EVENT_HEAL: Logging.write_simple("%04d.%03d;HEAL;%s;%d" % entry)
			EVENT_ABILITY_GET :Logging.write_simple("%04d.%03d;ABILITY GET;%s" % entry)
			EVENT_TRAIT_GET :Logging.write_simple("%04d.%03d;TRAIT GET;%s" % entry)
			EVENT_SESSION_ABANDONED : Logging.write_simple("%04d.%03d;SESSION ABANDONED")


func get_game_object_name(node:Node) -> String:
	if node == null:
		return "?DECEASED NODE?"
	if Global.World != null:
		if Global.World.Player == node:
			return "PLAYER"
	return node.name

func get_clean_game_object_name(object_name:String) -> String:
	var result = name_regex.search(object_name)
	if result:
		return result.get_string(1)
	return str(object_name)
