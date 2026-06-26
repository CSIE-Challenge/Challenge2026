# Minimal test fixture that mimics a trap node without Global references.
# Used by state_serializer_test.gd to verify trap serialization.
extends Node2D

var is_armed := false
