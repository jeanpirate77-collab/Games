extends CanvasLayer

const GameData = preload("res://game_data.gd")

# Boutons tactiles dessinés en code (noir, contour blanc).
#   à gauche : ◀ ▶          à droite : saut, attaque, feu, ruée (si achetée)
# Ils simulent les actions (Input.action_press), gèrent le multitouch
# et marchent aussi à la souris.

var player = null            # donné par main.gd (pour afficher la recharge du feu)
var actions: Array = []
var centers := {}            # action -> centre
var hit_radius := {}         # action -> rayon de la zone tactile
var held := {}               # action -> bool
var pointers := {}           # id du doigt (ou "souris") -> position
var radius := 36.0
var drawer: Node2D


func _ready() -> void:
	GameData.setup_inputs()
	layer = 10
	drawer = Node2D.new()
	add_child(drawer)
	drawer.draw.connect(_on_draw)
	get_viewport().size_changed.connect(layout)
	layout()


func layout() -> void:
	actions = ["ui_left", "ui_right", "ui_accept", "attaque", "feu"]
	if GameData.get_level("dash") > 0:
		actions.append("dash")
	for a in actions:
		if not held.has(a):
			held[a] = false
	var s := get_viewport().get_visible_rect().size
	radius = s.y * 0.085
	var r := radius
	var m := s.y * 0.04
	var y := s.y - m - r
	centers["ui_left"] = Vector2(m + r, y)
	centers["ui_right"] = Vector2(m + r * 3.4, y)
	centers["ui_accept"] = Vector2(s.x - m - r * 1.1, y - r * 0.1)
	centers["attaque"] = Vector2(s.x - m - r * 3.5, y + r * 0.1)
	centers["feu"] = Vector2(s.x - m - r * 3.1, y - r * 2.4)
	centers["dash"] = Vector2(s.x - m - r * 0.9, y - r * 2.6)
	hit_radius = {"ui_left": r * 1.2, "ui_right": r * 1.2, "ui_accept": r * 1.25, "attaque": r * 1.15, "feu": r * 1.1, "dash": r * 1.0}
	drawer.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			pointers[event.index] = event.position
		else:
			pointers.erase(event.index)
		refresh()
	elif event is InputEventScreenDrag:
		pointers[event.index] = event.position
		refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointers["souris"] = event.position
		else:
			pointers.erase("souris")
		refresh()
	elif event is InputEventMouseMotion and pointers.has("souris"):
		pointers["souris"] = event.position
		refresh()


func refresh() -> void:
	if centers.is_empty():
		return
	var changed := false
	for action in actions:
		var now := false
		for p in pointers.values():
			if p.distance_to(centers[action]) < hit_radius[action]:
				now = true
		if now != held[action]:
			held[action] = now
			changed = true
			if now:
				Input.action_press(action)
				GameData.tap(action)  # mémorisé : un tap très court n'est jamais perdu
			else:
				Input.action_release(action)
	if changed:
		drawer.queue_redraw()


func release_all() -> void:
	pointers.clear()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _exit_tree() -> void:
	release_all()


func _process(_delta: float) -> void:
	# redessine pendant la recharge du feu
	if player != null and player.fire_cd > 0.0:
		drawer.queue_redraw()


func _on_draw() -> void:
	for action in actions:
		var c: Vector2 = centers[action]
		var r := radius
		var fill := Color(1, 1, 1, 0.35) if held[action] else Color(0, 0, 0, 0.55)
		drawer.draw_circle(c, r, fill)
		drawer.draw_arc(c, r, 0.0, TAU, 48, Color.WHITE, 3.0, true)
		var t := r * 0.42
		match action:
			"ui_left":
				drawer.draw_colored_polygon(PackedVector2Array([c + Vector2(-t, 0), c + Vector2(t * 0.6, -t), c + Vector2(t * 0.6, t)]), Color.WHITE)
			"ui_right":
				drawer.draw_colored_polygon(PackedVector2Array([c + Vector2(t, 0), c + Vector2(-t * 0.6, -t), c + Vector2(-t * 0.6, t)]), Color.WHITE)
			"ui_accept":
				drawer.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -t), c + Vector2(-t, t * 0.6), c + Vector2(t, t * 0.6)]), Color.WHITE)
			"attaque":
				# épée
				var a := c + Vector2(-t * 0.8, t * 0.8)
				var b := c + Vector2(t * 0.9, -t * 0.9)
				drawer.draw_line(a, b, Color.WHITE, 4.0)
				drawer.draw_line(c + Vector2(-t * 0.75, t * 0.05), c + Vector2(-t * 0.05, t * 0.75), Color.WHITE, 4.0)
			"feu":
				# flamme
				var flame := PackedVector2Array([
					c + Vector2(0, -t * 1.1), c + Vector2(t * 0.45, -t * 0.3), c + Vector2(t * 0.7, t * 0.3),
					c + Vector2(t * 0.4, t * 0.8), c + Vector2(-t * 0.4, t * 0.8), c + Vector2(-t * 0.7, t * 0.3),
					c + Vector2(-t * 0.2, -t * 0.4),
				])
				drawer.draw_colored_polygon(flame, Color.WHITE)
				drawer.draw_circle(c + Vector2(0, t * 0.35), t * 0.3, Color.BLACK)
				if player != null and player.fire_cd > 0.0:
					var k: float = player.fire_cd / player.fire_delay
					drawer.draw_circle(c, r, Color(0, 0, 0, 0.5))
					drawer.draw_arc(c, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - k), 32, Color.WHITE, 4.0, true)
			"dash":
				for k in 2:
					var o := Vector2(-t * 0.5 + k * t * 0.7, 0)
					drawer.draw_polyline(PackedVector2Array([c + o + Vector2(-t * 0.3, -t * 0.6), c + o + Vector2(t * 0.3, 0), c + o + Vector2(-t * 0.3, t * 0.6)]), Color.WHITE, 4.0)
