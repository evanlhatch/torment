extends Node

const ResetVersionLimit = 10
var DEFAULT_PLAYER_PROFILE = {
	"ProfileVersion" : 26,
	"LeaderBoardVersion" : 4,
	"Gold" : 0,
	"Quests" : [],
	"QuestBoards" : ["QuestsMain", "QuestsChapter1", "QuestsSwordman"],
	"Unlocked" : [],
	"ItemsInWell":[],
	"ItemStash": ["hand_longfinger", "hand_quickhand", "feet_platedboots", "feet_runnershoes", "body_platearmor", "body_chainmail"],
	"Equipped": {
		"Head": "",
		"Neck": "",
		"Ring_L": "",
		"Ring_R": "",
		"Body": "",
		"Feet": "",
		"Gloves": "",
		"Mark": ""
	},
	"Blessings": {},
	"Loadouts" : {},
	"NumTraitRerollPotions": 1,
	"NumTraitBanishPotions": 1,
	"NumTraitDoublePotions": 1,
	"NumTraitMemorizePotions": 1,
	"NumAbilityRerollPotions": 1,
	"NumItemChestRerollPotions": 1,
	"Ingredients":[]
}

var DEV_PROFILE = {
	"ProfileVersion" : 26,
	"LeaderBoardVersion" : 4,
	"Gold" : 1000000,
	"Quests" : [],
	"QuestBoards" : ["QuestsMain", "QuestsNorseman", "QuestsBeasthuntress", "QuestsChapter1", "QuestsNorseman", "QuestsChapter4", "QuestsChapter3", "QuestsSwordman", "QuestChapter2", "QuestChaper4", "QuestChaper3", "QuestsArcher", "QuestsWarlock", "QuestsCleric", "QuestsExterminator", "QuestsShieldmaiden", "QuestsSorceress"],
	"Unlocked" : [],
	"ItemsInWell":[],
	"ItemStash": ["hand_longfinger", "hand_quickhand", "feet_platedboots", "feet_runnershoes", "body_platearmor", "body_chainmail", "neck_gatherers_charm"],
	"Equipped": {
		"Head": "",
		"Neck": "",
		"Ring_L": "",
		"Ring_R": "",
		"Body": "",
		"Feet": "",
		"Gloves": "",
		"Mark": ""
	},
	"Blessings": {},
	"Loadouts" : {},
	"NumTraitRerollPotions": 1,
	"NumTraitBanishPotions": 1,
	"NumTraitDoublePotions": 1,
	"NumTraitMemorizePotions": 1,
	"NumAbilityRerollPotions": 1,
	"NumItemChestRerollPotions": 1,
	"Ingredients":[]
}

func checkForProfileReset():
	if not Global.PlayerProfile.has("ProfileVersion") or Global.PlayerProfile.ProfileVersion < ResetVersionLimit:
		Global.PlayerProfile = DEFAULT_PLAYER_PROFILE
		Global.savePlayerProfile(true)


func updateProfile():
	Global.PlayerProfile.LeaderBoardVersion = DEFAULT_PLAYER_PROFILE.LeaderBoardVersion
	if Global.PlayerProfile.ProfileVersion >= DEFAULT_PLAYER_PROFILE.ProfileVersion: return
	Patch.backupProfile(Global.ProfilePath, Global.PathPatchBackup, false)

	for current_version in range(Global.PlayerProfile.ProfileVersion, DEFAULT_PLAYER_PROFILE.ProfileVersion):
		updateVersion(current_version+1)
	Global.PlayerProfile.ProfileVersion = DEFAULT_PLAYER_PROFILE.ProfileVersion

	for key in DEFAULT_PLAYER_PROFILE:
		if !Global.PlayerProfile.has(key):
			Global.PlayerProfile[key] = DEFAULT_PLAYER_PROFILE[key]

	Global.savePlayerProfile(true)


func updateVersion(target_version):
	if ProjectSettings.get_setting("halls_of_torment/development/use_dev_save"): return
	print("updating profile to version: " + str(target_version))
	match(target_version):
		18:
			Global.PlayerProfile = removeDoubleQuestsFromProfile(Global.PlayerProfile)
			Global.PlayerProfile = mergeProfileQuests(Global.PlayerProfile, [Global.PathPatchBackup, Global.PathLoadBackup, Global.PathSaveBackup])
			Global.PlayerProfile = updateProfilesBasedOnAchievements(Global.PlayerProfile)
			validateAllQuests()
		19:
			replaceItems(Global.PlayerProfile, "ring_invocationsignet", "glove_invocatorsgrasp")
			Global.savePlayerProfile(true)
		26:
			validateAllQuests()

func replaceItems(profile, oldItem, newItem):
	print("replacing item: " + oldItem + " with " + newItem)
	for i in range(profile.ItemStash.size()):
		if profile.ItemStash[i] == oldItem:
			profile.ItemStash[i] = newItem
			break
	for i in range(profile.ItemsInWell.size()):
		if profile.ItemsInWell[i] == oldItem:
			profile.ItemsInWell[i] = newItem
			break
	for key in profile.Equipped:
		if profile.Equipped[key] == oldItem:
			profile.Equipped[key] = ""
			break
	if profile.has("Loadouts"):
		for loadoutKey in profile.Loadouts:
			var equipment = profile.Loadouts[loadoutKey]
			for key in equipment:
				equipment[key] = ""
				break

var questsValidated : bool = false
func validateAllQuests():
	if questsValidated: return
	var quests = Global.QuestPool.get_all_quests()
	for quest in quests:
		if quest.is_completed():
			Global.QuestPool._on_quest_completed(quest, false)


	for i in range(Global.PlayerProfile["Quests"].size(), 0, -1):
		var q_found = false
		for quest in quests:
			if Global.PlayerProfile["Quests"][i-1].ID == quest.ID:
				if quest.CompletionCount > 0 and Global.PlayerProfile["Quests"][i-1].count < 0:
					print("resetting quest: " + Global.PlayerProfile["Quests"][i-1].ID)
					Global.PlayerProfile["Quests"][i-1].count = 0
					quest._count = 0
				q_found = true
				break
		if not q_found:
			print("removing quest from profile: " + Global.PlayerProfile["Quests"][i-1].ID)
			Global.PlayerProfile["Quests"].remove_at(i-1)
	Global.QuestPool.load_quests()
	questsValidated = true


func mergeProfileQuests(mainProfile, profilePathsToMerge):
	if mainProfile == null: return
	if profilePathsToMerge == null: return mainProfile
	for profilePath in profilePathsToMerge:
		var backup_profile = Global.loadFromProfileFileSTEAM(profilePath)
		if backup_profile != null:
			mainProfile["Quests"] = mergeQuestStatesToHighest(mainProfile, backup_profile)
			mainProfile["Quests"] = mergeQuestStatesToHighest(backup_profile, mainProfile)
	return mainProfile


func mergeQuestStatesToHighest(profile_a, profile_b):
	var quests = []
	for a in range(profile_a["Quests"].size()):
		var quest = profile_a["Quests"][a]
		for b in range(profile_b["Quests"].size()):
			if profile_a["Quests"][a].ID == profile_b["Quests"][b].ID:
				if profile_a["Quests"][a].count < profile_b["Quests"][b].count:
					quest = profile_b["Quests"][b]
				break
		quests.append(quest)
	return quests


func removeDoubleQuestsFromProfile(profile):
	var quests = []
	for a in range(profile["Quests"].size()):
		var quest_found = false
		for q in quests.size():
			if profile["Quests"][a].ID == quests[q].ID:
				quest_found = true
				if profile["Quests"][a].count > quests[q].count:
					quests[q].count = profile["Quests"][a].count
				break
		if not quest_found:
			quests.append(profile["Quests"][a])
	profile["Quests"] = quests
	return profile


func updateProfilesBasedOnAchievements(profile):
	for a in range(profile["Quests"].size()):
		var achievement = Steam.getAchievement(profile["Quests"][a].ID)
		if achievement != null && achievement.achieved:
			profile["Quests"][a].completed = true

	var quests = Global.QuestPool.get_all_quests()
	for quest in quests:
		for a in range(profile["Quests"].size()):
			if profile["Quests"][a].ID == quest.ID:
				if profile["Quests"][a].completed:
					if quest.AvoidTime > 0:
						profile["Quests"][a].count = quest.AvoidTime
					else:
						profile["Quests"][a].count = quest.CompletionCount
				quest._count = profile["Quests"][a].count

	for quest in quests:
		var profile_has_quest = false
		for a in range(profile["Quests"].size()):
			if profile["Quests"][a].ID == quest.ID and profile["Quests"][a].completed:
				profile_has_quest = true
				break
		if profile_has_quest:
			continue
		var achievement = Steam.getAchievement(quest.ID)
		if achievement != null && achievement.achieved:
			var quest_sample = {}
			quest_sample.ID = quest.ID
			quest_sample.completed = true
			quest_sample.hidden = false
			if quest.AvoidTime > 0:
				quest_sample.count = quest.AvoidTime
			else:
				quest_sample.count = quest.CompletionCount
			profile["Quests"].append(quest_sample)
			quest.set_data(quest_sample)
	return profile


func startDevProfile():
	Global.PlayerProfile = DEV_PROFILE


func updateDevProfile():
	if ProjectSettings.get_setting("halls_of_torment/development/set_quests_unhidden"):
		for quest in Global.QuestPool.get_all_quests():
			quest.set_hidden(false)

	if ProjectSettings.get_setting("halls_of_torment/development/set_quests_complete"):
		for quest in Global.QuestPool.get_all_quests():
			if quest.AvoidTime > 0: quest._count = quest.AvoidTime
			else: quest._count = quest.CompletionCount
			Global.QuestPool._on_quest_completed(quest, true)

	if ProjectSettings.get_setting("halls_of_torment/development/add_items_to_well"):
		for i in Global.WellItemsPool.Items:
			if i.ItemID not in Global.PlayerProfile["ItemsInWell"]:
				Global.PlayerProfile["ItemsInWell"].append(i.ItemID)

	if ProjectSettings.get_setting("halls_of_torment/development/add_items_to_stash"):
		for i in Global.WellItemsPool.Items:
			if i.ItemID not in Global.PlayerProfile["ItemStash"]:
				Global.PlayerProfile["ItemStash"].append(i.ItemID)


func backupProfile(source_file: String, target_file: String, check_source: bool = true):
	print("saving profile backup...")
	# currently not used, but if we are unsure our current profile is valid, we can check it
	if check_source:
		if not Steam.fileExists(source_file):	return
		var fileSize = Steam.getFileSize(source_file)
		var filereadRet = Steam.fileRead(source_file, fileSize)
		if not filereadRet["ret"]:
			return
		var byteBuf = filereadRet["buf"]
		for i in byteBuf.size():
			byteBuf[i] = byteBuf[i] ^ Global.ProfileXOR

		var data = bytes_to_var(byteBuf)

		if data == null: return

	var fileSize = Steam.getFileSize(source_file)
	var filereadRet = Steam.fileRead(source_file, fileSize)
	if not filereadRet["ret"]:
		return
	Steam.fileWriteAsync(target_file, filereadRet["buf"])
