@tool
extends RichTextEffect
class_name RichTextNext


var bbcode = "next"
var start_time = null


func _process_custom_fx(char_fx: CharFXTransform):
	if !char_fx.visible:
		return true
	
	char_fx.offset = Vector2(abs(sin(char_fx.elapsed_time*5.0)*5), 0)
	
	if start_time == null:
		start_time = char_fx.elapsed_time
	
	var a = char_fx.elapsed_time - start_time
	
	if a > 1.0:
		return true
	
	char_fx.color.a = a
	return true


func reset():
	start_time = null
