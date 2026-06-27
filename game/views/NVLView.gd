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


func _display_line(line: String, speaker: Speaker = null, skip_animations: bool = false):
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
	if paragraphs.get_child_count() > 0 and _current_label() != null:
		var old_par: RichTextLabel = _current_label()
		old_par.text = old_par.text.replace(line_end_string(), '')
		# it may have been centered so remove leftover tags
		old_par.text = old_par.text.replace('[center][/center]', '')
		old_par.custom_minimum_size.y = 0
	
	var tag_bbcode: RegExMatch = GET_BBCODE.search(line)
	
	# handle nvl img line
	if tag_bbcode != null and tag_bbcode.get_string('tag') == 'nvl_img':
		_handle_nvl_img_line(tag_bbcode, skip_animations)
		
	elif speaker != null: # handle speaker line
		_handle_speaker_line(speaker, line)
		
	else: # handle normal narration line
		var label: RichTextLabel = create_label()
		label.fit_content = true
		label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	
		if paragraphs.get_child_count() == 0: # don't indent initial line
			label.text = line
		elif not _is_previous_narration(): # no indent after non-standard text
			label.text = '[br]' + line
		else: # indent othwrerwise
			label.text = INDENT + line
		
		add_paragraph(label)


func add_paragraph(par: Control):
	par.set_meta('blockfile', block.blockfile_path)
	par.set_meta('block', block.id)
	par.set_meta('line_index', line_index)
	paragraphs.add_child(par)


func _is_previous_narration() -> bool:
	var prev = paragraphs.get_child(-1)
	return prev is RichTextLabel


func _previous_speaker_line_or_null() -> Variant:
	if paragraphs.get_child_count() == 0:
		return null
	var prev = paragraphs.get_child(-1)
	return prev if prev is SpeakerNVLLine else null


func _handle_nvl_img_line(tag_bbcode: RegExMatch, skip_animations: bool):
	var path: String
	
	for inner_tag in GET_BBCODE.search_all(tag_bbcode.get_string('content')):
		match inner_tag.get_string('tag'):
			'id':
				path = Assets._resolve(TE.defs.imgs[inner_tag.get_string('content')], 'res://assets/img')
	
	var img_line = ImageNVLLine.new(load(path), create_label)
	img_line.next_label.text = line_end_string()
	
	if not skip_animations:
		TETheme.anim_nvl_image_in.call(img_line.rect)
	
	add_paragraph(img_line)


func _handle_speaker_line(speaker: Speaker, line: String):
		var speaker_line: SpeakerNVLLine = SpeakerNVLLine.new(speaker, line, create_label)
		
		var prev_speaker: SpeakerNVLLine = _previous_speaker_line_or_null()
		var is_same_speaker: bool = prev_speaker != null and speaker_line.speaker.id == prev_speaker.speaker.id
		
		if paragraphs.get_child_count() == 0:
			pass
		elif is_same_speaker: # don't show name twice in consecutive dialogue
			speaker_line.speaker_label.modulate.a = 0
		else: # line break between different speakers or narration and dialogue
			speaker_line.add_line_break()
		
		add_paragraph(speaker_line)


func _current_label() -> RichTextLabel:
	if paragraphs.get_child_count() == 0:
		return null
	var current = paragraphs.get_child(-1)
	if current is RichTextLabel:
		return current
	if current is SpeakerNVLLine:
		return current.line_label
	if current is ImageNVLLine:
		return current.next_label
	return null


func _scroll_to_bottom():
	scroll.get_v_scroll_bar().value = scroll.get_v_scroll_bar().max_value


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
	
	if paragraphs.get_child_count() != 0:
		# fast path when using view from cache
		from_state_fast_path(savestate)
	else:
		# slow path for when using fresh view instance
		super.from_state(savestate)


# TODO optimize further by not clearing the entire block
func from_state_fast_path(savestate: Dictionary):
	var blockfile = savestate['blockfile']
	var block_id = savestate['block']
	var index = savestate['line_index']
	
	var has_matching: bool = false
	for par in paragraphs.get_children():
		if par.get_meta('blockfile') == blockfile and par.get_meta('block') == block_id:
			has_matching = true
			break
	
	if has_matching: # this means we're going back
		
		# if present, first remove everything that doesn't match current block
		while paragraphs.get_child_count() > 0:
			var last = paragraphs.get_children().back()
			if not (last.get_meta('blockfile') == blockfile and last.get_meta('block') == block_id):
				paragraphs.remove_child(last)
				last.queue_free()
			else:
				break
		
		# then remove current block because it will be re-displayed
		while paragraphs.get_child_count() > 0:
			var last = paragraphs.get_children().back()
			if last.get_meta('blockfile') == blockfile and last.get_meta('block') == block_id and last.get_meta('line_index') >= index-1:
				paragraphs.remove_child(last)
				last.queue_free()
			else:
				break
		
	else: # going forward, NOP
		pass
	
	# show fresh block if necessary
	if block != _resolve_block(savestate):
		block = _resolve_block(savestate)
		_lines = Blocks.resolve_parts(block, game.context)
	
	line_index = index-1
	
	# go forward to the correct line
	next_line(true)
	_to_end_of_line()
