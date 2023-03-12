extends Node
# plays songs and sound effects defined in the definitions file


# tween used for fading song in
var music_tween: Tween = null
# id of currently playing song
var song_id: String


# plays a song with the given id, fading in with the given duration in seconds
# if another song is playing, it is faded out simultaneouslu
func play_song(new_song_id: String, duration: float):
	song_id = new_song_id
	var path = TE.defs.songs[song_id]
	var new_song = Assets.songs.get_resource('res://assets/music' + path)
	
	# if new song already fading in, end the transition
	if music_tween != null and music_tween.is_running():
		music_tween.kill()
		_swap_song_trans_finished()
	
	music_tween = create_tween()
	
	if $SongPlayer.get_stream() != null:
		music_tween.parallel().tween_method(Callable(self, '_set_song_volume'), 1.0, 0.0, duration)
	
	music_tween.parallel().tween_method(Callable(self, '_set_next_song_volume'), 0.0, 1.0, duration)
	$NextSongPlayer.set_stream(new_song)
	
	$NextSongPlayer.play()
	
	# wrong timing ?
	music_tween.parallel().tween_callback(Callable(self, '_swap_song_trans_finished')).set_delay(duration)


func _set_song_volume(val: float):
	$SongPlayer.volume_db = linear_to_db(val)


func _set_next_song_volume(val: float):
	$NextSongPlayer.volume_db = linear_to_db(val)


func _swap_song_trans_finished():
	var old_music: AudioStreamPlayer = $SongPlayer
	var new_music: AudioStreamPlayer = $NextSongPlayer
	
	old_music.stop()
	remove_child(old_music)
	old_music.queue_free()
	
	new_music.name = 'SongPlayer'
	new_music.bus = 'Music'
	
	var replacement = AudioStreamPlayer.new()
	replacement.name = 'NextSongPlayer'
	replacement.bus = 'Music'
	add_child(replacement, true)


# sets pause status of all playing audio
func set_paused(paused: bool):
	$SongPlayer.stream_paused = paused
	$NextSongPlayer.stream_paused = paused
	$SoundPlayer.stream_paused = paused


# plays a sound effect with the given id
func play_sound(id: String):
	var path = TE.defs.sounds[id]
	var sound = Assets.sounds.get_resource('res://assets/sound' + path)
	sound.set_loop(false)
	
	$SoundPlayer.stream = sound
	$SoundPlayer.play()


# returns debug text that displays volumes of audio buses
# and all playing sounds 
func debug_text() -> String:
	var msg: String = ''
	
	msg += 'Master: ' + str(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('Master'))) + ' dB\n'
	msg += 'Music: ' + str(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('Music'))) + ' dB\n'
	msg += 'SFX: ' + str(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('SFX'))) + ' dB\n'
	
	if $SongPlayer.get_stream() != null and $SongPlayer.playing:
		msg += 'SongPlayer (' + $SongPlayer.bus + '): ' + str(db_to_linear($SongPlayer.volume_db)) + '\n'
		msg += '  ' + $SongPlayer.get_stream().resource_path + '\n'
	
	if $NextSongPlayer.get_stream() != null and $NextSongPlayer.playing:
		msg += 'NextSongPlayer (' + $NextSongPlayer.bus + '): ' + str(db_to_linear($NextSongPlayer.volume_db)) + '\n'
		msg += '  ' + $NextSongPlayer.get_stream().resource_path + '\n'
	
	if $SoundPlayer.get_stream() != null and $SoundPlayer.playing:
		msg += 'SoundPlayer (' + $SoundPlayer.bus + '): ' + str(db_to_linear($SoundPlayer.volume_db)) + '\n'
		msg += '  ' + $SoundPlayer.get_stream().resource_path + '\n'
	
	return msg
