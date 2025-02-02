extends Camera3D
@export_range(100, 500) var clickable_range: float = 100

@onready var ray_cast_3d: RayCast3D = $RayCast3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	ray_cast_3d.target_position = project_local_ray_normal(mouse_position) * clickable_range
	ray_cast_3d.force_raycast_update()
