extends AnimationPlayer

@export var anim = "daytime"
@export var speed = 1000
@export var offset = 0.0

func _ready():
	# Start at the current time of day, duration is one real day when speed is set to 1
	# The time can be randomly offset by a small amount, to prevent all lights turning on at the same time
	var duration = speed / float(60 * 60 * 24)
	var time = Time.get_time_dict_from_system()
	var time_day_clock = (float(1) / 24) * (time.hour + time.minute / float(60) + time.second / float(60 ^ 2))
	var time_day_ofs = (-1 + randf() * 2) * offset
	var time_day = min(max(time_day_clock + time_day_ofs, 0), 1)

	play(anim, 0, duration)
	seek(time_day, true)
