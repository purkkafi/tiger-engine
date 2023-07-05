extends Node
# plays songs and sound effects defined in the definitions file


# tween used for fading song in
var music_tween: Tween = null
# id of currently playing song; will be the empty string if no song is playing
var song_id: String = ''


# emitted with the song id when a song is played
signal song_played
# emitted when audio is paused with id of current song & whether paused or unapaused
signal song_paused


# plays a song with the given id, fading in with the given duration in seconds
# if another song is playing, it is faded out simultaneously
# an empty string can be passed to stop playing a song
func play_song(new_song_id: String, duration: float, warn_not_queued: bool = true):
	song_id = new_song_id
	var new_song: AudioStream
	if new_song_id != '':
		var path = TE.defs.songs[song_id]
		new_song = Assets.songs.get_resource(path, 'res://assets/music', warn_not_queued)
		
		if not _is_looping(new_song):
			TE.log_warning("looping disabled for song '%s'" % new_song_id)
	else:
		new_song = null
	
	# if new song already fading in, end the transition
	if music_tween != null and music_tween.is_running():
		music_tween.kill()
		_swap_song_trans_finished()
	
	music_tween = create_tween()
	
	if $SongPlayer.get_stream() != null:
		music_tween.parallel().tween_method(Callable(self, '_set_song_volume'), db_to_linear($SongPlayer.volume_db), 0.0, duration)
	
	music_tween.parallel().tween_method(Callable(self, '_set_next_song_volume'), 0.0, TE.defs.song_volume(song_id), duration)
	$NextSongPlayer.set_stream(new_song)
	
	$NextSongPlayer.play()
	
	# TODO wrong timing ? investigate?
	music_tween.parallel().tween_callback(Callable(self, '_swap_song_trans_finished')).set_delay(duration)
	
	# unlock possible unlockable
	if song_id in TE.defs.unlocked_by_song:
		for unlockable in TE.defs.unlocked_by_song[song_id]:
			TE.settings.unlock(unlockable)
	
	# emit signal
	emit_signal('song_played', song_id)


func _is_looping(stream: AudioStream):
	if stream is AudioStreamOggVorbis:
		return stream.loop
	elif stream is AudioStreamMP3:
		return stream.loop
	elif stream is AudioStreamWAV:
		return stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false # unknown type


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
	emit_signal('song_paused', song_id, paused)


# plays a sound effect with the given id
func play_sound(id: String):
	var path = TE.defs.sounds[id]
	var sound: AudioStream = Assets.sounds.get_resource(path, 'res://assets/sound')
	
	if _is_looping(sound):
			TE.log_warning("looping enabled for sound '%s'" % id)
	
	$SoundPlayer.stream = sound
	$SoundPlayer.play()


# returns the AudioStreamPlayer of currently playing song or null
func song_player():
	if $SongPlayer.get_stream() != null:
		return $SongPlayer
	return null


# returns debug text that displays volumes of audio buses
# and all playing sounds 
func debug_text() -> String:
	var msg: String = ''
	
	var buses: Array[String] = ['Master', 'Music', 'SFX']
	
	for bus in buses:
		var vol: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
		msg += '%s: %.2f dB\n' % [bus, vol]
	
	msg += '\n'
	
	var players: Array = [$SongPlayer, $NextSongPlayer, $SoundPlayer]
	
	for player in players:
		var active = player.playing and player.get_playback_position() != 1.0
		var song: String = player.get_stream().resource_path.split('/')[-1] if active else ''
		var vol: String = ': %.2f (%.2f dB)' % [db_to_linear(player.volume_db), player.volume_db] if active else ''
		var time: String = '%.2f / %.2f s' % [player.get_playback_position(), player.stream.get_length()] if active else ''
		msg += '%s (%s): %s %s %s\n' % [player.name, player.bus, song, vol, time]
	
	return msg
