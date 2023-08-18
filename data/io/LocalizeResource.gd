class_name LocalizeResource extends Resource
# resource that represents a single file in the localize folder
# not meant to be used directly; call Localize.of_lang(<lang id>)
# to get a Localize object encompassing all localization data


# map of localize ids to the localized strings
var content: Dictionary


func _init(_content: Dictionary):
	self.content = _content
