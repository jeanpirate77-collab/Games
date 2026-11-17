extends Node2D

# Petites particules carrées (poussière, étincelles, débris, lucioles...)
# Créé par main.gd : fx.burst(...), fx.ring(...), fx.spawn(...)

const MAX_PARTS := 500

var parts: Array = []


func _ready() -> void:
	z_index = 20


func spawn(pos: Vector2, vel: Vector2, color: Color, life: float, size: float, gravity := 0.0) -> void:
	if parts.size() >= MAX_PARTS:
		return
	parts.append({"p": pos, "v": vel, "life": life, "max": life, "size": size, "c": color, "g": gravity, "ring": false})


func burst(pos: Vector2, count: int, spread: float, color: Color, life := 0.5, size := 2.0, gravity := 0.0, up := 0.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(spread * 0.3, spread) + Vector2(0, -up)
		spawn(pos, v, color, life * randf_range(0.6, 1.0), size * randf_range(0.7, 1.3), gravity)


# trait qui file (vent, vitesse)
func streak(pos: Vector2, vel: Vector2, color: Color, life: float) -> void:
	if parts.size() >= MAX_PARTS:
		return
	parts.append({"p": pos, "v": vel, "life": life, "max": life, "size": 1.0, "c": color, "g": 0.0, "ring": false, "streak": true})


func ring(pos: Vector2, radius: float, color: Color, life := 0.4) -> void:
	parts.append({"p": pos, "v": Vector2.ZERO, "life": life, "max": life, "size": radius, "c": color, "g": 0.0, "ring": true})


func _process(delta: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var q: Dictionary = parts[i]
		q["life"] = float(q["life"]) - delta
		if q["life"] <= 0.0:
			parts.remove_at(i)
		else:
			var v: Vector2 = q["v"]
			v.y += float(q["g"]) * delta
			q["v"] = v
			q["p"] = Vector2(q["p"]) + v * delta
		i -= 1
	queue_redraw()


func _draw() -> void:
	for q in parts:
		var k: float = float(q["life"]) / float(q["max"])
		var c: Color = q["c"]
		c.a *= k
		var p: Vector2 = q["p"]
		var s: float = q["size"]
		if q.get("streak", false):
			draw_line(p, p - Vector2(q["v"]) * 0.06, c, 1.0)
		elif q["ring"]:
			draw_arc(p, s * (1.0 + (1.0 - k) * 2.0), 0.0, TAU, 24, c, 2.0)
		else:
			draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), c)
