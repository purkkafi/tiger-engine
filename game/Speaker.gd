class_name Speaker extends RefCounted
# runtime object used to indicate how a speaker of a line should
# be displayed in different contexts

var name: String # the name
var name_color: Color # color of the speaker box
var bg_color: Color # background color of the speaker box
var variation: String # theme type variation of the speaker box
var log_color: Color # color in the log


# resolves a Speaker instance from a definition and a context
static func resolve(def: Definitions.SpeakerDef, ctxt: ControlExpr.BaseContext):
	var resolved_name: Array[String] = Blocks._resolve_parts(def.name, ctxt)
	if len(resolved_name) != 1:
		TE.log_error("expected name '%s' of speaker '%s' to resolve into a single line, got '%s'" % [def.name, def.id, resolved_name])
	
	return Speaker.new(
		resolved_name[0],
		def.name_color,
		def.bg_color,
		def.variation,
		_get_log_color(def)
	)


# returns the appropriate log color for a speaker definition
static func _get_log_color(def: Definitions.SpeakerDef):
	if def.name_color != Color.TRANSPARENT:
		return def.name_color
	if def.bg_color != Color.TRANSPARENT:
		return def.bg_color
	return TETheme.default_text_color


func _init(_name: String, _name_color: Color, _bg_color: Color, _variation: String, _log_color: Color):
	self.name = _name
	self.name_color = _name_color
	self.bg_color = _bg_color
	self.variation = _variation
	self.log_color = _log_color
