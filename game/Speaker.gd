class_name Speaker extends RefCounted
# runtime object used to indicate how a speaker of a line should
# be displayed in different contexts

var name: String # the name
var name_color: Color # color of the speaker box
var bg_color: Color # background color of the speaker box
var textbox_variation: String # theme type variation of the ADV mode text box
var label_variation: String # theme type variation of the speaker label
var log_color: Color # color in the log


static var EXTRACT_ID: RegEx = RegEx.create_from_string('(\\w+)')
static var EXTRACT_ARG: RegEx = RegEx.create_from_string('\\[(?<tag>.+?)\\](?<content>.+?)\\[\\/(?P=tag)\\]')


# resolves a Speaker instance from a definition and a context
static func resolve(declaration: String, ctxt: ControlExpr.BaseContext) -> Speaker:
	var id: String = EXTRACT_ID.search(declaration).get_string(0)
	var def: Definitions.SpeakerDef = TE.defs.speakers[id]
	@warning_ignore("shadowed_variable")
	var name: Variant = def.name
	
	for arg in EXTRACT_ARG.search_all(declaration):
		match arg.get_string('tag'):
			'as_name':
				name = arg.get_string('content')
			'as_ctrltag':
				name = Tag.ControlTag.new(arg.get_string('content'))
			_:
				print('illegal speaker declaration: %s (unknown argument %s)' % [declaration, arg.get_string('tag')])
	
	var resolved_name: String = ''
	if name is String:
		resolved_name = name.strip_edges()
	else:
		resolved_name = ControlExpr.exec((name as Tag.ControlTag).string, ctxt).strip_edges()
	
	return Speaker.new(
		resolved_name,
		def.name_color,
		def.bg_color,
		def.label_variation,
		def.textbox_variation,
		_get_log_color(def)
	)


# returns the appropriate log color for a speaker definition
static func _get_log_color(def: Definitions.SpeakerDef):
	if def.name_color != Color.TRANSPARENT:
		return def.name_color
	if def.bg_color != Color.TRANSPARENT:
		return def.bg_color
	return TETheme.default_text_color


func _init(_name: String, _name_color: Color, _bg_color: Color, _label_variation: String, _textbox_variation: String, _log_color: Color):
	self.name = _name
	self.name_color = _name_color
	self.bg_color = _bg_color
	self.label_variation = _label_variation
	self.textbox_variation = _textbox_variation
	self.log_color = _log_color
