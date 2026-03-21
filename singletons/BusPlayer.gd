class_name BusPlayer extends Node


# bus data, set with set_bus() when instantiated by Audio
var bus_id: int
var bus_name: String

var audio_id: String = ''
var local_volume: float = 1.0
var crossfade_tween: Tween = null


# sets bus_id and bus_name and points the players to the right bus
func set_bus(new_bus_id):
	bus_id = new_bus_id
	bus_name = AudioServer.get_bus_name(bus_id)
	$CurrentPlayer.bus = bus_name
	$NextPlayer.bus = bus_name


# pauses or unapuses this BusPlayer
func set_paused(paused: bool):
	$CurrentPlayer.stream_paused = paused
	$NextPlayer.stream_paused = paused
	if $CurrentPlayer.stream != null or $NextPlayer.stream != null:
		TE.audio.audio_paused.emit(audio_id, bus_name, paused)


# clears the audio if it is non-looping
func clear_if_transient():
	if audio_id == '' and ($CurrentPlayer.stream != null or $NextPlayer.stream != null):
		clear()


# stops the audio
func clear():
	$CurrentPlayer.set_stream(null)
	$NextPlayer.set_stream(null)
	TE.audio.audio_finished.emit(audio_id, bus_name)


# plays audio with the given id, crossfade duration (optional) and local volume multiplier (optional)
# if 'new_id' is empty, silence is played instead
func play(new_audio_id: String, crossfade_duration: float = 0.0, with_local_volume: float = 1.0):
	audio_id = new_audio_id
	self.local_volume = with_local_volume
	var new_stream: AudioStream
	
	if new_audio_id != '':
		var path = TE.defs.audio[new_audio_id]
		new_stream = Assets.audio.get_resource(path, 'res://assets/audio', false)
		
		# do not save ID of non-looping streams
		if not _is_looping(new_stream):
			audio_id = ''
	else:
		new_stream = null
	
	# if new audio already fading in, end the transition
	if crossfade_tween != null and crossfade_tween.is_running():
		crossfade_tween.kill()
		_swap_players()
	
	crossfade_tween = create_tween()
	
	if $CurrentPlayer.get_stream() != null:
		# fade out currently playing audio
		crossfade_tween.parallel().tween_method(_set_current_volume, db_to_linear($CurrentPlayer.volume_db), 0.0, crossfade_duration)
	
	crossfade_tween.parallel().tween_method(_set_next_volume, 0.0, TE.defs.audio_volume(new_audio_id) * local_volume, crossfade_duration)
	
	$NextPlayer.set_stream(new_stream)
	
	# if switching to the same audio, continue from playback position
	# (for situations where we are transitioning to the same audio at a different volume)
	var from_position: float = 0
	if $NextPlayer.get_stream() == $CurrentPlayer.get_stream():
		from_position = $CurrentPlayer.get_playback_position()
	
	$NextPlayer.play(from_position)
	
	# hook for supporting custom AudioStreamPolyphonic resources by initializing them with 'set_playback'
	if new_stream is AudioStreamPolyphonic and 'intialize' in new_stream:
		new_stream.intialize($NextPlayer)
	
	# TODO wrong timing ? investigate?
	crossfade_tween.parallel().tween_callback(_swap_players).set_delay(crossfade_duration)
	
	# unlock possible unlockable
	if new_audio_id in TE.defs.unlocked_by_audio:
		for unlockable in TE.defs.unlocked_by_audio[new_audio_id]:
			TE.persistent.unlock(unlockable)
	
	TE.audio.audio_played.emit(new_audio_id, bus_name)
	
	$NextPlayer.finished.connect(func(): TE.audio.audio_finished.emit(new_audio_id, bus_name))


func _set_current_volume(val: float):
	$CurrentPlayer.volume_db = linear_to_db(val)


func _set_next_volume(val: float):
	$NextPlayer.volume_db = linear_to_db(val)


# concludes transition between CurrentPlayer and NextPlayer, turning Next into Current
# and creating a fresh Next
func _swap_players():
	var current_player: AudioStreamPlayer = $CurrentPlayer
	var new_player: AudioStreamPlayer = $NextPlayer
	
	current_player.stop()
	remove_child(current_player)
	current_player.queue_free()
	
	new_player.name = 'CurrentPlayer'
	
	var replacement = AudioStreamPlayer.new()
	replacement.name = 'NextPlayer'
	replacement.bus = bus_name
	add_child(replacement, true)


func _is_looping(stream: AudioStream):
	if stream is AudioStreamOggVorbis:
		return stream.loop
	if stream is AudioStreamMP3:
		return stream.loop
	if stream is AudioStreamWAV:
		return stream.loop_mode != AudioStreamWAV.LoopMode.LOOP_DISABLED
	if stream is AudioStreamPlaylist:
		return stream.loop
	return true # assume loop otherwise
