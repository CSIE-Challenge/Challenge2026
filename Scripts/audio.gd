@tool
extends Node

enum SFX {
	JUMP,
	LAND_SAND,
	LAND_JUICE,
	LAND_WATER,
	BUTTON_PRESS,
	ENERGY_COLLECTED,
	GAMEPLAY_PHASE_CHANGE,
	TAKE_DAMAGE,
	PLAYER_DIE,
	SET_TRAP,
	SCENE_TRANSITION_WAVE,
	TRAP1_MINE_EXPLODE,
	TRAP1_MINE_DISARM,
	TRAP2_ELECTRIC_RING,
	TRAP3_SEAGULL_HIT,
	TRAP5_JUICE_SPLASH,
	TRAP9_WATERMELON_FALL,
	SIX_SEVEN,
	TRAP3_BULLET_HIT_WALL,
	HIDDEN_GAME_ATTACK,
	HIDDEN_GAME_COMPLETE,
	HIDDEN_GAME_LASER_READY,
	HIDDEN_GAME_LASER_EMIT,
	HIDDEN_GAME_TYPEWRITER,
	HIDDEN_GAME_TYPEWRITER_2,
	HIDDEN_GAME_ACHIEVEMENT,
	HIDDEN_GAME_BIGBALL_HITWALL,
	HIDDEN_GAME_BOOMERANG,
	HIDDEN_GAME_GET_ATTACKBALL,
	HIDDEN_GAME_NOTES_GLIDING_1,
	HIDDEN_GAME_NOTES_GLIDING_2,
	HIDDEN_GAME_NOTES_GLIDING_3,
	HIDDEN_GAME_NOTES_HIT,
	HIDDEN_GAME_ROCKET_EXPLODE,
	HIDDEN_GAME_ROCKET_FLYING,
	HIDDEN_GAME_SLASH,
	SCENE_TRANSITION,
	PREGAME_COUNTDOWN
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
	HIDDEN_GAME_UNDERTALE,
}

@export var sfx_pool_size := 8
@export var bgm_fade_out_time := 0.3125

# the audio collection
var _sfx_streams: Dictionary = {}
var _bgm_playlists: Dictionary = {}

# sfx player pool
var _sfx_players: Array[AudioStreamPlayer] = []

# current state
var _current_bgm: BGM = -1 as BGM

# for bgm fading
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

	bgm_player.finished.connect(func(): bgm_player.play())
	bgm_player2.finished.connect(func(): bgm_player2.play())

	_current_player = bgm_player
	_next_player = bgm_player2


func set_bgm(bgm: BGM) -> void:
	if _current_bgm == bgm:
		return

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # run even if game is paused
	_fade_tween.tween_property(_current_player, "volume_db", -80.0, bgm_fade_out_time)

	_current_bgm = bgm
	var stream := _bgm_playlists.get(BGM.find_key(bgm)) as AudioStream
	_next_player.stream = stream
	_next_player.volume_db = 0
	_next_player.play()

	await _fade_tween.finished
	_current_player.stop()
	_current_player.volume_db = 0

	# swap available players
	var tmp = _current_player
	_current_player = _next_player
	_next_player = tmp


func play_sfx(sfx: SFX) -> AudioStreamPlayer:
	var stream := _sfx_streams.get(SFX.find_key(sfx)) as AudioStream
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


func stop_all_sfx() -> void:
	for player in _sfx_players:
		if player.playing:
			player.stop()


func stop_all_audio() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _current_player != null:
		_current_player.stop()
	if _next_player != null:
		_next_player.stop()
	for player in _sfx_players:
		player.stop()
		player.stream = null


func stop_all_audio_2d(node: Node = null) -> void:
	if node == null:
		node = get_tree().root

	if node is AudioStreamPlayer2D:
		var player := node as AudioStreamPlayer2D
		player.stop()

	for child in node.get_children():
		stop_all_audio_2d(child)


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


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({"name": "BGM Tracks", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})

	for bgm_type in BGM.keys():
		properties.append(
			{
				"name": "%s_tracks" % bgm_type.to_lower(),
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "AudioStream",
				"class_name": &"AudioStream"
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
		return _bgm_playlists.get(bgm_type.to_upper())
	elif property.ends_with("_sfx"):
		var sfx_name = property.left(-4)
		return _sfx_streams.get(sfx_name.to_upper())
	return null


func _set(property, value):
	if property.ends_with("_tracks"):
		var bgm_type = property.left(-7)
		_bgm_playlists[bgm_type.to_upper()] = value as AudioStream
		return true
	elif property.ends_with("_sfx"):
		var sfx_name = property.left(-4)
		_sfx_streams[sfx_name.to_upper()] = value as AudioStream
		return true
	return false
