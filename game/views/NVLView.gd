class_name NVLView extends View
# TODO scrolling text smoothly


# RichTextLabels containing the displayed lines
@onready var paragraphs: VBoxContainer = %Paragraphs
@onready var scroll: ScrollContainer = %Scroll
# these will be set from options
var hcenter: bool = false
var vcenter: bool = false
var outline_size: float = 0
var outline_color: Variant = null # Color or null
var text_color: Variant = null # Color or null
var type_variation: String = 'NVLView' # theme type variation to fetch measurements from


# indent that appears at the start of lines after the first
var INDENT: String = '        '


func parse_options(tags: Array[Tag]):
	for opt in tags:
		match opt.name:
			'hcenter':
				hcenter = true
			'vcenter':
				vcenter = true
			'outline':
				outline_color = TE.defs.color(opt.get_string_at(0))
				outline_size = float(opt.get_string_at(1))
			'text_color':
				text_color = TE.defs.color(opt.get_string())
			_:
				TE.log_error(TE.Error.SCRIPT_ERROR, 'unknown option for NVLView: %s' % opt)			


func _ready():
	scroll.get_v_scroll_bar().connect('changed', Callable(self, '_scroll_to_bottom'))


func initialize(_ctxt: InitContext):
	if vcenter:
		paragraphs.alignment = BoxContainer.ALIGNMENT_CENTER


func adjust_size(controls: VNControls):
	var controls_height = controls.size.y if controls != null else 0.0
	
	var top_margin: float = 50
	if has_theme_constant('top_margin', type_variation):
		top_margin = get_theme_constant('top_margin', type_variation)
	
	var bottom_margin: float = 50
	if has_theme_constant('bottom_margin', type_variation):
		bottom_margin = get_theme_constant('bottom_margin', type_variation)
	
	var width: float = 1200
	if has_theme_constant('width', type_variation):
		width = get_theme_constant('width', type_variation)
	
	if has_theme_stylebox('panel', type_variation):
		%Panel.add_theme_stylebox_override('panel', get_theme_stylebox('panel', type_variation))
	
	%Panel.size.y = (TE.SCREEN_HEIGHT - controls_height - top_margin - bottom_margin)
	%Panel.position.y = top_margin
	
	var w = width
	%Panel.size.x = w
	%Panel.position.x = (TE.SCREEN_WIDTH - w)/2
	
	for child in paragraphs.get_children():
		if child is TextureRect:
			_set_full_img_size(child)


# Speakers are not handled right now
func _display_line(line: String, _speaker: Speaker = null):
	var label: RichTextLabel = create_label()
	label.fit_content = true
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	
	if outline_size != 0:
		line = '[outline_size=%s][outline_color=%s]%s[/outline_color][/outline_size]' % [outline_size, outline_color.to_html(), line]
	
	if text_color != null:
		line = '[color=%s]%s[/color]' % [text_color.to_html(), line]
	
	if hcenter: # if centered: no indent and lines are farther apart
		line = '[center]%s[/center]' % line
		INDENT = ''
	else:
		# if not centered, there will be an indent & lines will be closer
		paragraphs.add_theme_constant_override('separation', 4)
	
	# remove the '[next] ▶[/next]' from previous paragraph
	if paragraphs.get_child_count() > 0 and paragraphs.get_child(-1) is RichTextLabel:
		var old_par: RichTextLabel = paragraphs.get_child(-1)
		old_par.text = old_par.text.replace(line_end_string(), '')
		# it may have been centered so remove leftover tags
		old_par.text = old_par.text.replace('[center][/center]', '')
	
	# indent lines that come after non-empty lines
	if paragraphs.get_child_count() > 0 and not _is_previous_line_empty():
		label.text = INDENT + line
	else:
		label.text = line
	
	paragraphs.add_child(label)


func _is_previous_line_empty():
	var prev = paragraphs.get_child(-1)
	if prev is RichTextLabel:
		return len(prev.text.strip_edges()) == 0
	return false


func _current_label() -> RichTextLabel:
	if paragraphs.get_child_count() == 0:
		return null
	return paragraphs.get_child(-1)


func _scroll_to_bottom():
	scroll.get_v_scroll_bar().value = scroll.get_v_scroll_bar().max_value


func _supported_custom_tags() -> Array[String]:
	return [ 'fullimg' ]


func _parse_custom_tag_line(_line: String, tag_bbcode: RegExMatch, loading_from_save: bool):
	_display_line('')
	
	var path: String
	var width: float
	
	for inner_tag in GET_BBCODE.search_all(tag_bbcode.get_string('content')):
		match inner_tag.get_string('tag'):
			'id':
				path = Assets._resolve(TE.defs.imgs[inner_tag.get_string('content')], 'res://assets/img')
			'width':
				width = float(inner_tag.get_string('content'))
	
	var rect: TextureRect = TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_meta('width_ratio', width)
	_set_full_img_size(rect)
	
	paragraphs.add_child(rect)
	
	if not loading_from_save:
		TETheme.anim_full_image_in.call(rect)
	
	_display_line('[center]%s[/center]' % line_end_string())


func _set_full_img_size(img: TextureRect):
	var width: float = get_theme_constant('width', 'NVLView') * img.get_meta('width_ratio')
	var height = width / img.texture.get_width() * img.texture.get_height()
	img.custom_minimum_size = Vector2(width, height)


func previous_block_policy() -> View.PreviousBlocksPolicy:
	return View.PreviousBlocksPolicy.RETAIN


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	if hcenter:
		savestate['hcenter'] = hcenter
	if vcenter:
		savestate['vcenter'] = vcenter
	if outline_color != null:
		savestate['outline_color'] = outline_color.to_html()
	if outline_size != 0:
		savestate['outline_size'] = outline_size
	if text_color != null:
		savestate['text_color'] = text_color.to_html()
	return savestate


func from_state(savestate: Dictionary):
	if 'hcenter' in savestate:
		hcenter = savestate['hcenter']
	if 'vcenter' in savestate:
		vcenter = savestate['vcenter']
	if 'outline_color' in savestate:
		outline_color = Color.html(savestate['outline_color'])
	if 'outline_size' in savestate:
		outline_size = savestate['outline_size']
	if 'text_color' in savestate:
		text_color = Color.html(savestate['text_color'])
	
	super.from_state(savestate)
