extends Node

#當陷阱打到玩家時，就寫Global.player_hit.emit([整數傷害])
signal player_hit(damage: int)

signal energyball_collected

var game_manager: Node2D
var stage: Node2D
var single_player: bool = false
var agent_file: String = ""
