extends Node3D

@export var turret_range := 10.0
@export var projectile: PackedScene
@onready var marker_3d: Marker3D = $base/turret/Marker3D

var enemy_path: Path3D
var target: PathFollow3D

func _process(delta: float) -> void:
	target = find_best_target()
	
func _physics_process(delta: float) -> void:
	var target = find_best_target()
	if target:
		look_at(target.global_position, Vector3.UP, true)


func _on_timer_timeout() -> void:
	if target:
		shoot()


func shoot():
	var shot = projectile.instantiate()
	add_child(shot)
	shot.global_position = marker_3d.global_position
	shot.direction = global_transform.basis.z



func find_best_target() -> PathFollow3D:
	var best_target = null
	var best_progress = 0
	for enemy in enemy_path.get_children():
		if enemy is PathFollow3D:
			if enemy.progress > best_progress:
				var distance := global_position.distance_to(enemy.global_position)
				if distance < turret_range:
					best_target = enemy
					best_progress = enemy.progress
	return best_target
