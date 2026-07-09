@tool
extends Node

enum SFX {
	JUMP,
	BUTTON_PRESS,
	ENERGY_COLLECTED,
	GAMEPLAY_PHASE_CHANGE,
	TAKE_DAMAGE,
	SET_TRAP,
	TRAP1_MINE_EXPLODE,
	TRAP1_MINE_DISARM,
	TRAP3_BULLET_HIT_WALL
}

enum BGM {
	MENU,
	GAMEPLAY_PHASE_0,
	GAMEPLAY_PHASE_1,
	GAMEPLAY_PHASE_2,
	GAMEPLAY_PHASE_3,
	GAMEPLAY_PHASE_4,
	GAMEPLAY_PHASE_5,
	RESULT_SCREEN,
	HIDDEN_GAME,
}

@export var sfx_pool_size := 8
@export var bgm_fade_out_time := 0.3125

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_playlist: Array[AudioStream] = []
var _last_track_index: int = -1

var _sfx_streams: Dictionary = {}
var _bgm_playlists: Dictionary = {}

var _current_player: AudioStreamPlayer
var _next_player: AudioStreamPlayer
var _fade_tween: Tween

@onready var bgm_player: AudioStreamPlayer = $BgmPlayer1
@onready var bgm_player2: AudioStreamPlayer = $BgmPlayer2


func _ready() -> void:
	for i in range(sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)

	_current_player = bgm_player
	_next_player = bgm_player2
	_current_player.finished.connect(_play_random_bgm_track.bind(_current_player))
	_next_player.finished.connect(_play_random_bgm_track.bind(_next_player))


func set_bgm(bgm: BGM) -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # run even if game is paused
	_fade_tween.tween_property(_current_player, "volume_db", -80.0, bgm_fade_out_time)

	_bgm_playlist = _bgm_playlists.get(bgm, []) as Array[AudioStream]
	_last_track_index = -1
	_play_random_bgm_track(_next_player)

	await _fade_tween.finished
	_current_player.stop()
	_current_player.volume_db = 0

	# swap available players
	var tmp = _current_player
	_current_player = _next_player
	_next_player = tmp

	print("playing BGM.%s playlist" % BGM.keys()[bgm])


func play_sfx(sfx: SFX) -> AudioStreamPlayer:
	var stream := _sfx_streams.get(sfx) as AudioStream
	if stream == null:
		return
	# find free players to play effect audio
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return player
	# fallback to the first player
	_sfx_players[0].stream = stream
	_sfx_players[0].play()
	return _sfx_players[0]


func bgm_is_playing() -> bool:
	return _current_player.playing or _next_player.playing


func pause_bgm() -> void:
	if _current_player.playing:
		_current_player.stop()
	if _next_player.playing:
		_next_player.stop()


func resume_bgm() -> void:
	if _current_player.stream != null and not _current_player.playing:
		_current_player.play()


func set_phase_bgm(phase: int) -> void:
	play_sfx(SFX.GAMEPLAY_PHASE_CHANGE)
	match phase:
		0:
			set_bgm(BGM.GAMEPLAY_PHASE_0)
		1:
			set_bgm(BGM.GAMEPLAY_PHASE_1)
		2:
			set_bgm(BGM.GAMEPLAY_PHASE_2)
		3:
			set_bgm(BGM.GAMEPLAY_PHASE_3)
		4:
			set_bgm(BGM.GAMEPLAY_PHASE_4)
		5:
			set_bgm(BGM.GAMEPLAY_PHASE_5)


func _play_random_bgm_track(player: AudioStreamPlayer) -> void:
	var count := _bgm_playlist.size()
	if count == 0:
		player.stream = null
		return
	if count == 1:
		_last_track_index = 0
	else:
		var index := _last_track_index
		while index == _last_track_index:
			index = randi() % count
		_last_track_index = index
	player.stream = _bgm_playlist[_last_track_index]
	player.volume_db = 0
	player.play()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({"name": "BGM Tracks", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})

	for bgm_type in BGM.keys():
		properties.append(
			{
				"name": "%s_tracks" % bgm_type.to_lower(),
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "24/17:AudioStream"
			}
		)

	properties.append({"name": "Sound Effects", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})

	for sfx_name in SFX.keys():
		properties.append(
			{
				"name": "%s_sfx" % sfx_name.to_lower(),
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "AudioStream",
				"class_name": &"AudioStream"
			}
		)

	return properties


func _get(property):
	if property.ends_with("_tracks"):
		var bgm_type = property.left(-7)
		var bgm_key = BGM.get(bgm_type.to_upper())
		return _bgm_playlists.get(bgm_key, [])
	elif property.ends_with("_sfx"):
		var sfx_name = property.left(-4)
		var sfx_key = SFX.get(sfx_name.to_upper(), [])
		return _sfx_streams.get(sfx_key)
	return null


func _set(property, value):
	if property.ends_with("_tracks"):
		var bgm_type = property.left(-7)
		var bgm_key = BGM.get(bgm_type.to_upper())
		if not _bgm_playlists.has(bgm_key):
			_bgm_playlists[bgm_key] = [] as Array[AudioStream]
		_bgm_playlists[bgm_key].assign(value)
		return true
	elif property.ends_with("_sfx"):
		var sfx_name = property.left(-4)
		var sfx_key = SFX.get(sfx_name.to_upper())
		_sfx_streams.set(sfx_key, value)
		return true
	return false
