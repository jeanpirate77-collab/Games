extends CanvasLayer

# Boutons tactiles ◀ ▶ ▲ dessinés en code.
# Ils simulent ui_left / ui_right / ui_accept, gèrent le multitouch
# et fonctionnent aussi à la souris.

const ACTIONS := ["ui_left", "ui_right", "ui_accept"]

var centers := {}        # action -> position du centre
var held := {}           # action -> bool
var pointers := {}       # id du doigt (ou "souris") -> position
var radius := 40.0
var drawer: Node2D


func _ready() -> void:
	layer = 10
	drawer = Node2D.new()
	add_child(drawer)
	drawer.draw.connect(_on_draw)
	for action in ACTIONS:
		held[action] = false
	get_viewport().size_changed.connect(layout)
	layout()


func layout() -> void:
	var s := get_viewport().get_visible_rect().size
	radius = s.y * 0.11  # taille relative à l'écran
	var margin := s.y * 0.05
	var y := s.y - margin - radius
	centers["ui_left"] = Vector2(margin + radius, y)
	centers["ui_right"] = Vector2(margin + radius * 3.0 + margin * 0.6, y)
	centers["ui_accept"] = Vector2(s.x - margin - radius, y)
	drawer.queue_redraw()


func _input(event: InputEvent) -> void:
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
	for action in ACTIONS:
		# zone de saut un peu plus large : plus facile à toucher
		var hit := radius * (1.5 if action == "ui_accept" else 1.15)
		var now := false
		for p in pointers.values():
			if p.distance_to(centers[action]) < hit:
				now = true
		if now != held[action]:
			held[action] = now
			changed = true
			if now:
				Input.action_press(action)
			else:
				Input.action_release(action)
	if changed:
		drawer.queue_redraw()


func release_all() -> void:
	pointers.clear()
	refresh()


func _notification(what: int) -> void:
	# L'app passe en arrière-plan : on relâche tout pour éviter un bouton « coincé »
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _exit_tree() -> void:
	release_all()


func _on_draw() -> void:
	for action in ACTIONS:
		var c: Vector2 = centers[action]
		var fill := Color(1, 1, 1, 0.35) if held[action] else Color(0, 0, 0, 0.6)
		drawer.draw_circle(c, radius, fill)
		drawer.draw_arc(c, radius, 0.0, TAU, 48, Color.WHITE, 3.0, true)
		var t := radius * 0.42
		var pts := PackedVector2Array()
		match action:
			"ui_left":
				pts = PackedVector2Array([c + Vector2(-t, 0), c + Vector2(t * 0.6, -t), c + Vector2(t * 0.6, t)])
			"ui_right":
				pts = PackedVector2Array([c + Vector2(t, 0), c + Vector2(-t * 0.6, -t), c + Vector2(-t * 0.6, t)])
			"ui_accept":
				pts = PackedVector2Array([c + Vector2(0, -t), c + Vector2(-t, t * 0.6), c + Vector2(t, t * 0.6)])
		drawer.draw_colored_polygon(pts, Color.WHITE)
