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
	"""
	var msg: String = ''
	
	var buses: Array[String] = ['Master', 'Music', 'SFX']
	
	for bus in buses:
		var vol: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
		msg += '%s: %.2f dB\n' % [bus, vol]
	
	msg += '\n'
	
	var players: Array = [$SongPlayer, $NextSongPlayer, $SoundPlayer]
	
	msg += 'Song volume: %s / Local volume: %s\n' % [TE.defs.song_volume(song_id), local_volume]
	for player in players:
		var active = player.playing and player.get_playback_position() != 1.0
		var song: String = player.get_stream().resource_path.split('/')[-1] if active else ''
		var vol: String = ': %.2f (%.2f dB)' % [db_to_linear(player.volume_db), player.volume_db] if active else ''
		var time: String = '%.2f / %.2f s' % [player.get_playback_position(), player.stream.get_length()] if active else ''
		msg += '%s (%s): %s %s %s\n' % [player.name, player.bus, song, vol, time]
	
	return msg
	"""
	return "" # TODO reimplement
