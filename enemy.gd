extends Area2D

# Ennemi créé par main.gd.
#   kind = "marcheur" : fait des allers-retours entre min_x et max_x
#   kind = "tireur"   : reste sur place et tire une boule toutes les 2 s

signal shoot(from_pos: Vector2, dir_x: float)

var kind := "marcheur"
var min_x := 0.0
var max_x := 0.0
var speed := 45.0
var dir_x := -1.0
var points := 100
var shoot_delay := 2.0
var shoot_range := 420.0   # ne tire que si le joueur est assez proche
var target: Node2D = null  # le joueur

var dead := false
var shoot_timer := 0.0
var anim_time := 0.0
var sprite: Sprite2D
var frames: Array[ImageTexture] = []

const WALKER_A := [
	"................",
	"................",
	"................",
	"......w..w......",
	".....w#ww#w.....",
	"....w######w....",
	"...w########w...",
	"..w###ww##ww#w..",
	"..w###w###w##w..",
	"..w##########w..",
	"..w##w####w##w..",
	"...w########w...",
	"....wwwwwwww....",
	"...w#w....w#w...",
	"...w#w....w#w...",
	"...www....www...",
]
const WALKER_B := [
	"................",
	"................",
	"................",
	"................",
	"......w..w......",
	".....w#ww#w.....",
	"....w######w....",
	"...w##ww##ww#w..",
	"..w###w###w##w..",
	"..w##########w..",
	"..w##w####w##w..",
	"...w########w...",
	"....wwwwwwww....",
	"....w#w..w#w....",
	"....w#w..w#w....",
	"....www..www....",
]
const SHOOTER_A := [
	"......wwww......",
	".....w####w.....",
	"....w######w....",
	"...w########w...",
	"...w##wwww##w...",
	"...w#ww##ww#w...",
	"...w##wwww##w...",
	"...w########w...",
	"..w##########w..",
	"..w##########w..",
	"..w###w##w###w..",
	"..w##########w..",
	"..w#w######w#w..",
	"..w##########w..",
	"..w#w#w##w#w#w..",
	"..ww.ww..ww.ww..",
]
const SHOOTER_B := [
	"......wwww......",
	".....w####w.....",
	"....w######w....",
	"...w########w...",
	"...w#wwwwww#w...",
	"...w#ww##ww#w...",
	"...w#wwwwww#w...",
	"...w########w...",
	"..w##########w..",
	"..w###wwww###w..",
	"..w###w##w###w..",
	"..w###wwww###w..",
	"..w#w######w#w..",
	"..w##########w..",
	"..w#w#w##w#w#w..",
	"..ww.ww..ww.ww..",
]


func _ready() -> void:
	add_to_group("ennemis")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 26)
	shape.shape = rect
	shape.position = Vector2(0, 3)
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	add_child(sprite)

	if kind == "tireur":
		frames = [make_texture(SHOOTER_A), make_texture(SHOOTER_B)]
		shoot_timer = shoot_delay
	else:
		frames = [make_texture(WALKER_A), make_texture(WALKER_B)]
	sprite.texture = frames[0]


func make_texture(rows: Array) -> ImageTexture:
	var w: int = rows[0].length()
	var h: int = rows.size()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var c := line[x]
			if c == "#":
				img.set_pixel(x, y, Color.BLACK)
			elif c == "w":
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if kind == "tireur":
		update_shooter(delta)
	else:
		update_walker(delta)


func update_walker(delta: float) -> void:
	position.x += dir_x * speed * delta
	if position.x < min_x:
		position.x = min_x
		dir_x = 1.0
	elif position.x > max_x:
		position.x = max_x
		dir_x = -1.0
	sprite.flip_h = dir_x > 0.0
	anim_time += delta
	sprite.texture = frames[int(anim_time * 6.0) % 2]


func update_shooter(delta: float) -> void:
	if target == null:
		return
	var dx := target.global_position.x - global_position.x
	dir_x = 1.0 if dx > 0.0 else -1.0
	sprite.flip_h = dir_x > 0.0
	if absf(dx) > shoot_range:
		sprite.texture = frames[0]
		return
	shoot_timer -= delta
	# ouvre la bouche juste avant de tirer
	sprite.texture = frames[1] if shoot_timer < 0.3 else frames[0]
	if shoot_timer <= 0.0:
		shoot_timer = shoot_delay
		shoot.emit(global_position + Vector2(dir_x * 18.0, 0), dir_x)


# Appelé par main.gd quand le joueur saute dessus
func squash() -> void:
	dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	sprite.scale = Vector2(2.4, 0.8)
	sprite.position.y = 10.0
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
