extends Node3D

@export var projectile: PackedScene
@onready var marker_3d: Marker3D = $base/turret/Marker3D

var enemy_path: Path3D

func _physics_process(delta: float) -> void:
	var enemy = enemy_path.get_children().back()
	look_at(enemy.global_position, Vector3.UP, true)


func _on_timer_timeout() -> void:
	shoot()


func shoot():
	var shot = projectile.instantiate()
	add_child(shot)
	shot.global_position = marker_3d.global_position
	shot.direction = global_transform.basis.z
