class_name RoundTimer
extends Node

# Reusable countdown. Emits tick(time_left) every frame and finished() at zero.

signal tick(time_left)
signal finished

var time_left: float = 0.0
var running: bool = false

func start(seconds: float) -> void:
	time_left = seconds
	running = true

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	time_left = max(0.0, time_left - delta)
	tick.emit(time_left)
	if time_left <= 0.0:
		running = false
		finished.emit()
