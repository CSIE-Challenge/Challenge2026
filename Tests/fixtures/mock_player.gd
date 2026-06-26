# Test fixture: minimal player-like node for StateSerializer tests.
# Extends CharacterBody2D with the same custom properties as Player.
extends CharacterBody2D

var isjumping := false
var current_sprite_y: float = 0.0
var isinvincible := false
var health: float = 100.0
