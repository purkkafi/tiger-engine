class_name Captions extends Control


const caption_stylebox: StyleBox = preload('res://tiger-engine/resources/caption_stylebox.tres')


# toggles whether audio captions are shown
func set_captions_on(turned_on: bool):
	self.visible = turned_on


# displays a new caption
# – text: the caption to display
# – caption_id: an id that will be used to replace the old caption for the same id, if present
func show_caption(text: String, caption_id):
	var label: Label = null
	
	# get old caption object, if any
	if caption_id != '':
		for old_caption in %List.get_children():
			if old_caption.has_meta('id') and old_caption.get_meta('id') == caption_id:
				label = old_caption
				break
	
	# else, create new one
	if label == null:
		label = Label.new()
		label.theme_type_variation = 'CaptionLabel'
		label.add_theme_stylebox_override('normal', caption_stylebox)
		label.set_meta('id', caption_id)
		%List.add_child(label)
	
	label.text = text
	
	# only actually show the caption if a translated description is found; print a warning if not
	if TE.localize.has_translation(text):
		TE.localize.translate(label)
	else:
		_hide_caption(label)
		TE.log_warning('missing audio caption: %s' % text)


# hides a previously shown caption based on its id
func hide_caption(caption_id: String):
	var found: Label = null
	for caption in %List.get_children():
		if caption.has_meta('id') and caption.get_meta('id') == caption_id:
			found = caption
	
	if found != null:
		_hide_caption(found)


func _hide_caption(caption: Label):
	%List.remove_child(caption)
	caption.queue_free()
