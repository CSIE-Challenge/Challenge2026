class_name Util

##### This part is for layer #####
const LAYERS = {
	"Trap3TracingBullet/Seagull": 30,
	"Trap3TracingBullet/FeatherEffect": 30,
	"Trap9Mortar/Shell": 30,
	"Trap1Mine/MineWarning": 25,
	"Trap1Mine/ExplosionParticle": 25,
	"Trap5IceFloor/JuiceGlass": 25,
	"Trap7SpreadingRipples/WarningSprite": 15,  # +10 relative to its parent SpreadingRipples
	"Trap9Mortar/Shadow": 25,
	"Player/LandParticle": 21,
	"Player/BodySprite": 20,
	"Trap6Scanline/Hulas": 20,
	"Player/WalkParticle": 19,
	"Player/JumpParticle": 19,
	"Player/ShadowSprite": 18,
	"EnergyBall": 15,
	"Trap8ElectricArc/Cone": 10,
	"Trap7SpreadingRipples/SpreadingRipples": 10,
	"Trap7SpreadingRipples/WaterParticles": 0,  # +10 relative to its parent SpreadingRipples
	"Trap1Mine/MineBody": 10,
	"Trap1Mine/SpawnParticle": 10,
	"Trap2ElectricRing/ElectricRing": 10,
	"Trap2ElectricRing/ElectricRingWarning": 10,
	"Trap10Shotgun/AimingLines": 10,
	"Trap10Shotgun/Bullets": 10,
	"Trap10Shotgun/Baskets": 10,
	"Walls": 5,
	"Trap4Conveyor/AnimatedSprite2D": 5,
	"Trap5IceFloor/SpilledJuice": 5,
	"Trap9Mortar/Explosion": 5,
	"Trap8ElectricArc/Crack": 0
}
##### End of layer #####


static func load_json(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(
			"[Util] Failed to open file: %s, reason: %d" % [file_path, FileAccess.get_open_error()]
		)
		return null

	var content = file.get_as_text()
	file.close()

	var json_parsed = JSON.parse_string(content)
	if json_parsed == null:
		push_error("[Util] Failed to parse JSON from file: ", file_path)
		return null

	return json_parsed


static func save_json(file_path: String, data: Variant) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error(
			"[Util] Failed to open file: %s, reason: %d" % [file_path, FileAccess.get_open_error()]
		)
		return

	var dumped = JSON.stringify(data, "  ")
	if not file.store_string(dumped):
		push_error("[Util] Failed to write data to file: ", file_path)
	file.close()
