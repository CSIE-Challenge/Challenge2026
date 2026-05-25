extends Node

#當陷阱打到玩家時，就寫GlobalSignal.player_hit.emit([整數傷害])
signal player_hit(damage: int)
