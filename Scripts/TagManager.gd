extends RefCounted

class_name TagManager

signal TagsUpdated

var _activeTags : Dictionary = {}

func setTagActive(tagName:String):
	if not _activeTags.has(tagName):
		_activeTags[tagName] = true
		TagsUpdated.emit()

func setTagsActive(tagArray:Array[String]):
	# add the non-existing tags to _activeTags and remove the
	# existing ones from the tagArray parameter (for the TagsUpdated signal)
	for i in range(tagArray.size(), 0, -1):
		Global.QuestPool.notify_tag_unlocked(tagArray[i-1])
		if _activeTags.has(tagArray[i-1]):
			tagArray.remove_at(i-1)
		else:
			_activeTags[tagArray[i-1]] = true

	if tagArray.size() > 0:
		TagsUpdated.emit()

func deactivateTags(tagArray:Array[String]):
	for i in range(tagArray.size()):
		if _activeTags.has(tagArray[i]):
			_activeTags.erase(tagArray[i])
	TagsUpdated.emit()

func isTagActive(tag:String) -> bool:
	return _activeTags.has(tag)

func isAnyTagActive(tagArray:Array[String]) -> bool:
	for tag in tagArray:
		if _activeTags.has(tag):
			return true
	return false

func getTagsActiveCount(tagArray:Array[String]) -> int:
	var count = 0
	for tag in tagArray:
		if _activeTags.has(tag):
			count += 1
	return count

func areAllTagsActive(tagArray:Array[String]) -> bool:
	for tag in tagArray:
		if !_activeTags.has(tag):
			return false
	return true
