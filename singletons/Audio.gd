@warning_ignore("unused_signal")
class_name Audio extends Node
# plays songs and sound effects defined in the definitions file


var bus_players: Array[BusPlayer] = []


# emitted with the audio id when audio is played
@warning_ignore("unused_signal")
signal audio_played(audio_id: String, bus_name: String)
# emitted when a non-looping audio finishes playing
@warning_ignore("unused_signal")
signal audio_finished(audio_id: String, bus_name: String)
# emitted when audio is paused
@warning_ignore("unused_signal")
signal audio_paused(audio_id: String, bus_name: String, paused: bool)


func _ready() -> void:
	for bus_id in range(AudioServer.bus_count):
		var bus_name: String = AudioServer.get_bus_name(bus_id)
		if bus_name not in ['Master', 'Music', 'SFX']:
			var bus_player: BusPlayer = preload('res://tiger-engine/singletons/BusPlayer.tscn').instantiate()
			bus_player.set_bus(bus_id)
			add_child(bus_player)
			bus_players.append(bus_player)


# returns the BusPlayer corresponding to the given bus name
func bus(by_bus_name: String) -> BusPlayer:
	for bus_player in bus_players:
		if bus_player.bus_name == by_bus_name:
			return bus_player
	return null


# sets pause status of all playing audio
func set_all_paused(paused: bool):
	for bus_player in bus_players:
		bus_player.set_paused(paused)


# interrupts all nonlooping, sound effect-like audio
func clear_transient():
	for bus_player in bus_players:
		bus_player.clear_if_transient()


# interrupts and stops all audio
func clear_all():
	for bus_player in bus_players:
		bus_player.clear()


# returns current state related to audio
func get_state() -> Dictionary:
	var dict: Dictionary = {}
	for bus_player in bus_players:
		dict[bus_player.bus_name] = {
				'audio_id': bus_player.audio_id,
				'local_volume': bus_player.local_volume
			}
	return dict


# restores audio state from a dict returned by get_state()
func set_state(state: Dictionary):
	for bus_name in state.keys():
		var audio_data: Dictionary = state[bus_name]
		bus(bus_name).play(audio_data['audio_id'], 0, audio_data['local_volume'])


# returns debug text that displays volumes of audio buses
# and all playing sounds 
func debug_text() -> String:
	var msg: String = ''
	
	var bus_msgs: Array[String] = []
	for bus_ind in AudioServer.bus_count:
		var vol_lin: float = AudioServer.get_bus_volume_linear(bus_ind)
		var vol_db: float = AudioServer.get_bus_volume_db(bus_ind)
		bus_msgs.append('%s: %.2f (%.2f dB)' % [AudioServer.get_bus_name(bus_ind), vol_lin, vol_db])
	
	msg += ', '.join(bus_msgs)
	msg += '\n---\n'
	
	for player in bus_players:
		msg += '%s: %s [AV: %s LV: %s]\n' % [player.bus_name, player.audio_id, TE.defs.audio_volume(player.audio_id), player.local_volume]
		var debug_current = _debug_for(player.current_player())
		if debug_current != '':
			msg += '    C: ' + debug_current + '\n'
		var debug_next = _debug_for(player.next_player())
		if debug_next != '':
			msg += '    N: ' + debug_next + '\n'
	
	return msg


func _debug_for(asp: AudioStreamPlayer):
	if (not asp.playing) or asp.get_playback_position() == 1.0:
		return ''
	var song: String = asp.get_stream().resource_path.split('/')[-1]
	var vol: String = ': %.2f (%.2f dB)' % [db_to_linear(asp.volume_db), asp.volume_db]
	var time: String = '%.2f / %.2f s' % [asp.get_playback_position(), asp.stream.get_length()]
	return '%s %s %s' % [time, vol, song]
