extends PathFollow3D

@export var speed: float = 5
@export var max_health:= 50

@onready var base = get_tree().get_first_node_in_group("base")
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_hilight: MeshInstance3D = $DamageHilight

var current_health: int:
	set(health_in):
		if health_in < current_health:
			animation_player.play("TakeDamage")
		current_health = health_in
		if current_health < 1:
			queue_free()

func _ready() -> void:
	damage_hilight.hide()
	current_health = max_health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	progress += speed*delta
	if progress_ratio >= 0.97:
		base.take_damage()
		set_process(false)
		queue_free()
