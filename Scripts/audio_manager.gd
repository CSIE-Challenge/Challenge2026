extends Node

enum SFX { JUMP, BUTTON_PRESS }
enum BGM { MENU, GAMEPLAY, HIDDEN_GAME, RESULT }

@export var sfx_pool_size := 8

@export var menu_bgm_tracks: Array[AudioStream] = [
	preload("res://assets/audio/SmashTheCoconuts.mp3"),
]
@export var gameplay_bgm_tracks: Array[AudioStream] = []
@export var hidden_game_bgm_tracks: Array[AudioStream] = []
@export var result_bgm_tracks: Array[AudioStream] = []

@export var jump_effect: AudioStream = preload("res://assets/audio/Jump2.mp3")
@export var button_press_effect: AudioStream = preload("res://assets/audio/Press1.mp3")

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_playlist: Array[AudioStream] = []
var _last_track_index: int = -1

var _sfx_streams: Dictionary = {
	SFX.JUMP: jump_effect,
	SFX.BUTTON_PRESS: button_press_effect,
}
var _bgm_playlists: Dictionary = {
	BGM.MENU: menu_bgm_tracks,
	BGM.GAMEPLAY: gameplay_bgm_tracks,
	BGM.HIDDEN_GAME: hidden_game_bgm_tracks,
	BGM.RESULT: result_bgm_tracks,
}

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
	_bgm_playlist = _bgm_playlists.get(bgm, [])
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
