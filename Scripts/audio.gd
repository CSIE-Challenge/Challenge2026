@tool
extends Node

enum SFX { JUMP, BUTTON_PRESS, ENERGY_COLLECTED }
enum BGM { MENU, GAMEPLAY, HIDDEN_GAME, RESULT }

@export var sfx_pool_size := 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_playlist: Array[AudioStream] = []
var _last_track_index: int = -1

var _sfx_streams: Dictionary = {}
var _bgm_playlists: Dictionary = {}

@onready var bgm_player: AudioStreamPlayer = $BgmPlayer


func _ready() -> void:
	for i in range(sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)

	bgm_player.finished.connect(_play_random_bgm_track)


func set_bgm(bgm: BGM) -> void:
	bgm_player.stop()
	_bgm_playlist = _bgm_playlists.get(bgm, []) as Array[AudioStream]
	_last_track_index = -1
	_play_random_bgm_track()
	print("playing BGM.%s playlist" % BGM.keys()[bgm])


func play_sfx(sfx: SFX) -> void:
	var stream := _sfx_streams.get(sfx) as AudioStream
	if stream == null:
		return
	# find free players to play effect audio
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# fallback to the first player
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func pause_bgm() -> void:
	if bgm_player.playing:
		bgm_player.stop()


func resume_bgm() -> void:
	if bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()


func _play_random_bgm_track() -> void:
	var count := _bgm_playlist.size()
	if count == 0:
		bgm_player.stream = null
		return
	if count == 1:
		_last_track_index = 0
	else:
		var index := _last_track_index
		while index == _last_track_index:
			index = randi() % count
		_last_track_index = index
	bgm_player.stream = _bgm_playlist[_last_track_index]
	bgm_player.play()


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
