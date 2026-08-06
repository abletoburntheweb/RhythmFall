# scenes/profile/share/profile_share_card_preview_host.gd
extends Control

var forced_size := Vector2.ZERO


func set_forced_size(size: Vector2) -> void:
	forced_size = size
	custom_minimum_size = size
	size = size
	# Control has no queue_sort() (that's Container); refresh min-size for parents.
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if forced_size.x > 0.0 and forced_size.y > 0.0:
		return forced_size
	if custom_minimum_size.x > 0.0 or custom_minimum_size.y > 0.0:
		return custom_minimum_size
	return Vector2.ZERO
