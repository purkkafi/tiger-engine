class_name TestTEScriptCompiler extends TETest


var lexer: Lexer = Lexer.new()
var parser: Parser = Parser.new()


func compile(script: String) -> TEScriptCompiler:
	var script_to_compile: String = """
		\\script{test}{
			%s
		}
		""" % script
	
	var result = parser.parse(lexer.tokenize_string(script_to_compile, '<test>'))
	
	if result == null:
		push_error('syntax error in script: %s' % script)
		return
	
	var tag: Tag = result[0] as Tag
	
	var compiler = TEScriptCompiler.new()
	compiler.compile_script(tag)
	return compiler


func compiled_scripts(script: String) -> Dictionary:
	var compiler = compile(script)
	if compiler.has_errors():
		push_error('errors in script: %s' % [compiler.errors])
	return compiler.scripts


func instructions(script: String) -> Array[Variant]:
	var compiler = compile(script)
	if compiler.has_errors():
		push_error('errors in script: %s' % [compiler.errors])
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


func test_enter_default_values():
	assert_equals(
		instructions('\\enter{the_sprite}'),
		[ TEScript.IEnter.new('the_sprite', null, null, null, null, null, null, null) ]
	)


func test_enter_with_arguments():
	assert_equals(
		instructions('\\enter{the_sprite}{ \\as{state} \\x{1 of 1} \\y{0.5} \\zoom{1.5} \\order{3} \\with{trans} \\by{alt_id} }'),
		[ TEScript.IEnter.new('the_sprite', Tag.new('as', [['state']]), '1 of 1', '0.5', '1.5', '3', 'trans', 'alt_id') ]
	)


func test_enter_should_have_max_2_args():
	assert_equals(
		errors('\\enter{1}{2}{3}'),
		[ 'expected 1 or 2 arguments for \\enter, got \\enter[["1"], ["2"], ["3"]]' ]
	)


func test_enter_first_arg_should_be_sprite_id():
	assert_equals(
		errors('\\enter{\\no}'),
		[ 'expected sprite id in index 0 of \\enter, got \\enter[[\\no[]]]' ]
	)


func test_enter_x_should_take_string():
	assert_equals(
		errors('\\enter{spr}{ \\x{\\bad} }'),
		[ 'expected string for \\x, got \\enter[["spr"], [\\x[[\\bad[]]]]]' ]
	)


func test_enter_with_should_take_transition():
	assert_equals(
		errors('\\enter{spr}{ \\with{\\bad} }'),
		[ 'expected transition for \\with, got \\enter[["spr"], [\\with[[\\bad[]]]]]' ]
	)


func test_enter_by_should_take_sprite_id():
	assert_equals(
		errors('\\enter{spr}{ \\by{\\bad} }'),
		[ 'expected id for \\by, got \\enter[["spr"], [\\by[[\\bad[]]]]]' ]
	)


func test_move():
	assert_equals(
		instructions('\\move{spr}{ \\x{0.5} \\y{0} \\zoom{1.5} \\order{-2} }'),
		[ TEScript.IMove.new('spr', '0.5', '0', '1.5', '-2', null) ]
	)


func test_move_with():
	assert_equals(
		instructions('\\move{spr}{ \\x{0.5} \\with{trans} }'),
		[ TEScript.IMove.new('spr', '0.5', null, null, null, 'trans') ]
	)


func test_move_requires_properties():
	assert_equals(
		errors('\\move{spr}{ \\with{trans} }'),
		[ 'expected \\move to specify \\x, \\y, \\zoom, or \\order, got \\move[["spr"], [\\with[["trans"]]]]' ]
	)


func test_move_arg_0_should_be_sprite_id():
	assert_equals(
		errors('\\move{\\no}{ \\x{0.5} }'),
		[ 'expected sprite id in index 0 of \\move, got \\move[[\\no[]], [\\x[["0.5"]]]]' ]
	)


func test_move_with_should_take_transition():
	assert_equals(
		errors('\\move{spr}{ \\x{0.5}\\with{\\bad} }'),
		[ 'expected transition for \\with, got \\move[["spr"], [\\x[["0.5"]], \\with[[\\bad[]]]]]' ]
	)


func test_move_x_should_take_string():
	assert_equals(
		errors('\\move{spr}{ \\x{\\bad} }'),
		[ 'expected string for \\x, got \\move[["spr"], [\\x[[\\bad[]]]]]' ]
	)


func test_show():
	assert_equals(
		instructions('\\show{id}{ \\as{state} }'),
		[ TEScript.IShow.new('id', Tag.new('as', [[ 'state' ]]),  null) ]
	)


func test_show_with_transition():
	assert_equals(
		instructions('\\show{id}{ \\as{state} \\with{trans} }'),
		[ TEScript.IShow.new('id', Tag.new('as', [[ 'state' ]]),  'trans') ]
	)


func test_takes_max_2_args():
	assert_equals(
		errors('\\show{1}{ \\as{2} }{3}'),
		[ 'expected 2 arguments for \\show, got \\show[["1"], [\\as[["2"]]], ["3"]]' ]
	)


func test_should_have_args_at_index_1():
	assert_equals(
		errors('\\show{id}{bad}'),
		[ 'expected args in index 1 of \\show, got \\show[["id"], ["bad"]]' ]
	)


func test_show_requires_as():
	assert_equals(
		errors('\\show{spr}{ \\with{trans} }'),
		[ 'expected \\show to specify \\as, got \\show[["spr"], [\\with[["trans"]]]]' ]
	)


func test_show_with_takes_transition():
	assert_equals(
		errors('\\show{spr}{ \\with{\\bad} }'),
		[ 'expected transition for \\with, got \\show[["spr"], [\\with[[\\bad[]]]]]' ]
	)


func test_exit_default_args():
	assert_equals(
		instructions('\\exit{id}'),
		[ TEScript.IExit.new('id', null) ]
	)


func test_exit_all_and_with():
	assert_equals(
		instructions('\\exit{\\all}{ \\with{trans} }'),
		[ TEScript.IExit.new('', 'trans') ]
	)


func test_exit_takes_max_2_args():
	assert_equals(
		errors('\\exit{1}{2}{3}'),
		[ 'expected 1 or 2 arguments for \\exit, got \\exit[["1"], ["2"], ["3"]]' ]
	)


func test_exit_forbids_non_all_tags_in_arg_0():
	assert_equals(
		errors('\\exit{\\no}'),
		[ 'expected sprite id or \\all in index 0 of \\exit, got \\exit[[\\no[]]]' ]
	)


func test_exit_with_takes_transition():
	assert_equals(
		errors('\\exit{id}{ \\with{\\bad} }'),
		[ 'expected transition for \\with, got \\exit[["id"], [\\with[[\\bad[]]]]]' ]
	)


func test_if():
	var scripts = compiled_scripts('\\if{{CONDITION}}{ \\bg{possibly} } \n \\bg{after}')
	
	# test that the main script compiles to a conditional jump and then a jump to the after branch
	assert_equals(
		scripts['test'].instructions,
		[ TEScript.IJmpIf.new('CONDITION', 'test$2_if'), TEScript.IJmp.new('test$1_after_if', null) ]
	)
	
	# test that the after branch contains the test marker instruction
	assert_equals(
		scripts['test$1_after_if'].instructions,
		[ TEScript.IBG.new('after', '') ]
	)
	
	# test that the if branch contains the test marker instruction and then a jump to the after branch
	assert_equals(
		scripts['test$2_if'].instructions,
		[ TEScript.IBG.new('possibly', ''), TEScript.IJmp.new('test$1_after_if', null) ]
	)

func test_if_requires_2_args():
	assert_equals(
		errors('\\if{1}{2}{3}'),
		[ 'expected \\if to have condition and branch, got \\if[["1"], ["2"], ["3"]]' ]
	)


func test_if_requires_control_tag_at_index_0():
	assert_equals(
		errors('\\if{bad}{}'),
		[ 'expected index 0 of \\if to be control tag, got \\if[["bad"], []]' ]
	)


func test_match():
	var scripts = compiled_scripts("""
\\match{{CONDITION}}{
	\\case{{CASE1}}{ \\bg{case1_bg} }
	\\default{ \\bg{default_bg} }
}
\\bg{after_bg}
		""")
	
	assert_equals(
		scripts['test'].instructions,
		[
			TEScript.IJmpIf.new('(CONDITION) == (CASE1)', 'test$2_case'),
			TEScript.IJmp.new('test$3_default', null),
			TEScript.IJmp.new('test$1_after_match', null)
		]
	)
	
	assert_equals(
		scripts['test$1_after_match'].instructions,
		[ TEScript.IBG.new('after_bg', '') ]
	)
	
	assert_equals(
		scripts['test$2_case'].instructions,
		[ TEScript.IBG.new('case1_bg', ''), TEScript.IJmp.new('test$1_after_match', null) ]
	)
	
	assert_equals(
		scripts['test$3_default'].instructions,
		[ TEScript.IBG.new('default_bg', ''), TEScript.IJmp.new('test$1_after_match', null) ]
	)


func test_match_requires_control_tag_as_condition():
	assert_equals(
		errors('\\match{bad}{}'),
		[ 'expected index 0 of \\match to be control tag, got \\match[["bad"], []]' ]
	)


func test_match_takes_2_arguments():
	assert_equals(
		errors('\\match{{COND}}'),
		[ 'expected \\match to have condition and arms, got \\match[[{{COND}}]]' ]
	)


func test_match_rejects_unknown_arms():
	assert_equals(
		errors('\\match{{COND}}{ \\bad{} }'),
		[ 'unknown arm type for \\match, expected case or default: bad' ]
	)


func test_match_case_requires_control_tag():
	assert_equals(
		errors('\\match{{1}}{ \\case{bad}{} }'),
		[ 'expected control tag in index 0 of \\match arm, got \\match[[{{1}}], [\\case[["bad"], []]]]' ]
	)


func test_match_case_takes_correct_number_of_args():
	assert_equals(
		errors('\\match{{1}}{ \\case{{2}} }'),
		[ 'expected \\case arm of \\match to have condition and body, got \\match[[{{1}}], [\\case[[{{2}}]]]]' ]
	)
	
	assert_equals(
		errors('\\match{{1}}{ \\default{{2}}{} }'),
		[ 'expected \\default arm of \\match to have body, got \\match[[{{1}}], [\\default[[{{2}}], []]]]' ]
	)


func test_jmp_in_same_file():
	assert_equals(
		instructions('\\jmp{there}'),
		[ TEScript.IJmp.new('there', null) ]
	)


func test_jmp_to_other_file():
	assert_equals(
		instructions('\\jmp{otherfile:there}'),
		[ TEScript.IJmp.new('there', 'otherfile') ]
	)


func test_jmp_requires_single_argument():
	assert_equals(
		errors('\\jmp{destination}{bad}'),
		[ 'expected \\jmp to have destination, got \\jmp[["destination"], ["bad"]]' ]
	)


func test_jmp_rejects_malformed_destination():
	assert_equals(
		errors('\\jmp{a:b:c}'),
		[ 'bad \\jmp destination \'a:b:c\' in \\jmp[["a:b:c"]]' ]
	)


func test_vfx():
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{target} }{ \\arg{val} }'),
		[ TEScript.IVfx.new('vfx_id', 'target', 'id', { 'arg': Tag.new('arg', [['val']]) }) ]
	)


func test_vfx_requires_2_or_3_args():
	assert_equals(
		errors('\\vfx{vfx_id}'), ['expected \\vfx to be of form \\vfx{<vfx id>}{<target>}[{<state>}], got 1 args']
	)
	
	assert_equals(
		errors('\\vfx{vfx_idID}{}{}{}'), ['expected \\vfx to be of form \\vfx{<vfx id>}{<target>}[{<state>}], got 4 args']
	)


func test_vfx_args_mandatory():
	assert_equals(
		errors('\\vfx{vfx_id}{ \\as{as} }'), ['expected \\vfx to specify \\to, got \\vfx[[\"vfx_id\"], [\\as[[\"as\"]]]]']
	)


func test_vfx_targets():
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{\\stage} }'), [ TEScript.IVfx.new('vfx_id', '\\stage', 'id', {}) ]
	)
	
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{\\bg} }'), [ TEScript.IVfx.new('vfx_id', '\\bg', 'id', {}) ]
	)
	
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{\\fg} }'), [ TEScript.IVfx.new('vfx_id', '\\fg', 'id', {}) ]
	)
	
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{\\sprites} }'), [ TEScript.IVfx.new('vfx_id', '\\sprites', 'id', {}) ]
	)
	
	assert_equals(
		instructions('\\vfx{vfx_id}{ \\as{id} \\to{sprite_id} }'), [ TEScript.IVfx.new('vfx_id', 'sprite_id', 'id', {}) ]
	)
