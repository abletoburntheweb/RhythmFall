extends Node2D

const _HitParticlePresets = preload("res://logic/domain/rhythm/hit_particle_presets.gd")


func burst(preset: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	var cfg := _HitParticlePresets.merge_with_defaults(preset)
	var color := _HitParticlePresets.preview_color_from_preset(cfg)
	_HitParticlePresets.spawn(self, Vector2.ZERO, color, true, cfg)
