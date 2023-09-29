class_name TestTEScriptCompiler extends TETest


var lexer: Lexer = Lexer.new()
var parser: Parser = Parser.new()


func compile(script: String) -> TEScriptCompiler:
	var script_to_compile: String = """
		\\script{test}{
			%s
		}
		""" % script
	
	var tag: Tag = parser.parse(lexer.tokenize_string(script_to_compile, '<test>'))[0] as Tag
	
	var compiler = TEScriptCompiler.new()
	compiler.silent = true
	compiler.compile_script(tag)
	return compiler


func instructions(script: String) -> Array[Variant]:
	var compiler = compile(script)
	return compiler.scripts['test'].instructions


func errors(script: String) -> Array[String]:
	var compiler = compile(script)
	return compiler.errors

# tests for \bg are not duplicated for \fg since they should be identical
# (tests could be added if this assumption ever turns out to not be true)

func test_argless_bg():
	assert_equals(
		instructions('\\bg{bg_id}'),
		[ TEScript.IBG.new('bg_id', '') ]
	)


func test_bg_with_args():
	assert_equals(
		instructions('\\bg{bg_id}{ \\with{trans_id} }'),
		[ TEScript.IBG.new('bg_id', 'trans_id') ]
	)


func test_bg_with_clear():
	assert_equals(
		instructions('\\bg{\\clear}'),
		[ TEScript.IBG.new('', '') ]
	)


func test_bg_should_have_id():
	assert_equals(
		errors('\\bg'),
		[ 'expected 1 or 2 arguments for \\bg, got \\bg[]' ]
	)


func test_bg_should_have_args_at_index_1():
	assert_equals(
		errors('\\bg{id}{bad}'),
		[ 'expected args in index 1 of \\bg, got \\bg[["id"], ["bad"]]' ]
	)

	
func test_bg_should_have_max_2_args():
	assert_equals(
		errors('\\bg{id}{ \\with{trans} }{bad}'),
		[ 'expected 1 or 2 arguments for \\bg, got \\bg[["id"], [\\with[["trans"]]], ["bad"]]' ]
	)


func test_bg_should_error_on_unknown_arguments():
	assert_equals(
		errors('\\bg{id}{ \\weird_arg }'),
		[ 'unknown argument \'weird_arg\' for \\bg: \\bg[["id"], [\\weird_arg[]]]' ]
	)


func test_bg_with_should_take_transition():
	assert_equals(
		errors('\\bg{id}{ \\with{\\bad} }'),
		[ 'expected transition for \\with, got \\bg[["id"], [\\with[[\\bad[]]]]]' ]
	)


func test_block():
	assert_equals(
		instructions('\\block{id}'),
		[ TEScript.IBlock.new('id') ]
	)


func test_block_error_messages():
	assert_equals(
		errors('\\block{1}{2}{3}'),
		[ 'expected block id for \\block, got \\block[["1"], ["2"], ["3"]]' ]
	)
	
	assert_equals(
		errors('\\block{\\bad}'),
		[ 'expected block id for \\block, got \\block[[\\bad[]]]' ]
	)


func test_pause():
	assert_equals(
		instructions('\\pause{5s}'),
		[ TEScript.IPause.new('5s') ]
	)


func test_pause_should_have_1_arg():
	assert_equals(
		errors('\\pause'),
		[ 'expected transition for \\pause, got \\pause[]' ]
	)


func test_pause_should_take_transition():
	assert_equals(
		errors('\\pause{\\bad}'),
		[ 'expected transition for \\pause, got \\pause[[\\bad[]]]' ]
	)


func test_hideui():
	assert_equals(
		instructions('\\hideui{fast}'),
		[ TEScript.IHideUI.new('fast') ]
	)


func test_hideui_should_have_1_arg():
	assert_equals(
		errors('\\hideui'),
		[ 'expected transition for \\hideui, got \\hideui[]' ]
	)


func test_hideui_should_take_transition():
	assert_equals(
		errors('\\hideui{\\bad}'),
		[ 'expected transition for \\hideui, got \\hideui[[\\bad[]]]' ]
	)


func test_sound():
	assert_equals(
		instructions('\\sound{sfx}'),
		[ TEScript.ISound.new('sfx') ]
	)


func test_sound_should_take_1_arg():
	assert_equals(
		errors('\\sound{a}{b}'),
		[ 'expected sound id for \\sound, got \\sound[["a"], ["b"]]' ]
	)


func test_sound_should_take_sound_id():
	assert_equals(
		errors('\\sound{\\bad}'),
		[ 'expected sound id for \\sound, got \\sound[[\\bad[]]]' ]
	)


func test_music_default_values():
	assert_equals(
		instructions('\\music{cool_song}'),
		[ TEScript.IMusic.new('cool_song', '', 1.0) ]
	)


func test_music_transition_and_volume():
	assert_equals(
		instructions('\\music{my_song}{ \\with{transition} \\volume{0.5} }'),
		[ TEScript.IMusic.new('my_song', 'transition', 0.5) ]
	)


func test_music_should_have_args_in_index_1():
	assert_equals(
		errors('\\music{id}{bad}'),
		[ 'expected args in index 1 of \\music, got \\music[["id"], ["bad"]]' ]
	)


func test_music_should_take_max_2_args():
	assert_equals(
		errors('\\music{1}{2}{3}'),
		[ 'expected 1 or 2 arguments for \\music, got \\music[["1"], ["2"], ["3"]]' ]
	)


func test_music_should_error_on_unknown_argument():
	assert_equals(
		errors('\\music{id}{ \\bad }'),
		[ 'unknown argument \'bad\' for \\music: \\music[["id"], [\\bad[]]]' ]
	)


func test_music_volume_should_be_float():
	assert_equals(
		errors('\\music{id}{ \\volume{not_a_volume} }'),
		[ 'expected float for \\volume, got \\music[["id"], [\\volume[["not_a_volume"]]]]' ]
	)


func test_music_only_accepts_id_or_clear():
	assert_equals(
		errors('\\music{\\bad}'),
		[ 'expected id or \\clear in index 0 of \\music, got \\music[[\\bad[]]]' ]
	)


func test_music_with_should_take_transition():
	assert_equals(
		errors('\\music{id}{ \\with{\\bad} }'),
		[ 'expected transition for \\with, got \\music[["id"], [\\with[[\\bad[]]]]]' ]
	)


func test_break():
	assert_equals(
		instructions('\\break'),
		[ TEScript.IBreak.new() ]
	)


func test_break_should_be_empty():
	assert_equals(
		errors('\\break{anything}'),
		[ 'expected \\break to have no arguments, got \\break[["anything"]]' ]
	)
