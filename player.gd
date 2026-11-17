extends CharacterBody2D

const GameData = preload("res://game_data.gd")

signal melee(hit_rect: Rect2, damage: int)
signal fire(from_pos: Vector2, dir_x: float)

const GRAVITY := 1000.0
const MAX_FALL := 700.0
const COYOTE_TIME := 0.1
const STOMP_BOUNCE := -320.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.18

var level = null            # main.gd (effets visuels), null dans les menus
var can_control := true
var dead := false
var speed := 170.0
var jump_velocity := -440.0
var facing := 1.0
var air_time := 0.0
var jumps_left := 0
var was_on_floor := true
var anim_time := 0.0

var attack_time := 0.0
var attack_length := 0.28
var attack_hit_done := false
var attack_cd := 0.0
var fire_cd := 0.0
var fire_delay := 1.6
var cast_time := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var hurt_time := 0.0
var ghost_timer := 0.0
var step_timer := 0.0

var sprite: Sprite2D
var weapon_layer: Node2D
var frames := {}

# ---------- Pixel art ----------
# Tête (9 lignes) propre à chaque personnage, puis torse (4 lignes) et jambes (3 lignes).
const HEAD_OMBRE := [
	"................",
	"....########....",
	"...#wwwwwwww#...",
	"..#wwwwwwwwww#..",
	"..#wwww#ww#ww#..",
	"..#wwww#ww#ww#..",
	"..#wwwwwwwwww#..",
	"...#wwwwwwww#...",
	"....########....",
]
const HEAD_LUNE := [
	"..........##....",
	".........#ww#...",
	"....#####www#...",
	"...#wwwwwwww#...",
	"..#wwww#ww#ww#..",
	"..#wwww#ww#ww#..",
	"..#wwwwwwwwww#..",
	"...#wwwwwwww#...",
	"....########....",
]
const HEAD_ROC := [
	".##..........##.",
	".#w#........#w#.",
	"..#w########w#..",
	"..#dddddddddd#..",
	"..#dddd#ww#ww#..",
	"..#dddd#ww#ww#..",
	"..#dddddddddd#..",
	"...#dddddddd#...",
	"....########....",
]
const TORSO := [
	"...#wwwwwwww#...",
	"..#ww#wwwwww#...",
	"..#ww#wwwwww#...",
	"...#wwwwwwww#...",
]
const TORSO_ATTACK := [
	"...#wwwwwwww#...",
	"...#wwwwwwww####",
	"...#wwwwwwwwwww#",
	"...#wwwwwwww####",
]
const TORSO_HURT := [
	".#.#wwwwwwww#.#.",
	".#w#wwwwwwww#w#.",
	"..##wwwwwwww##..",
	"...#wwwwwwww#...",
]
const LEGS_IDLE := [
	"....#ww##ww#....",
	"....#ww##ww#....",
	"....###..###....",
]
const LEGS_SPREAD := [
	"...#ww#..#ww#...",
	"..#ww#....#ww#..",
	"..###......###..",
]
const LEGS_PASS := [
	".....#wwww#.....",
	"....#ww##ww#....",
	"...###....###...",
]
const LEGS_JUMP := [
	"...#ww#..#ww#...",
	"...###....###...",
	"................",
]
const LEGS_FALL := [
	"....#ww##ww#....",
	"...#ww#..#ww#...",
	"...##......##...",
]


static func recolor(rows: Array, color: String) -> Array:
	var out := []
	for r in rows:
		out.append(String(r).replace("w", color))
	return out


static func build_frames(char_id: String) -> Dictionary:
	var head: Array = HEAD_OMBRE
	var body := "w"
	if char_id == "lune":
		head = HEAD_LUNE
		body = "g"
	elif char_id == "roc":
		head = HEAD_ROC
		body = "g"
	var torso := recolor(TORSO, body)
	var f := {}
	f["idle"] = GameData.make_texture(head + torso + LEGS_IDLE)
	f["run0"] = GameData.make_texture(head + torso + LEGS_SPREAD)
	f["run1"] = f["idle"]
	f["run2"] = GameData.make_texture(head + torso + LEGS_PASS)
	f["run3"] = f["idle"]
	f["jump"] = GameData.make_texture(head + torso + LEGS_JUMP)
	f["fall"] = GameData.make_texture(head + torso + LEGS_FALL)
	f["attack"] = GameData.make_texture(head + recolor(TORSO_ATTACK, body) + LEGS_SPREAD)
	f["hurt"] = GameData.make_texture(head + recolor(TORSO_HURT, body) + LEGS_FALL)
	return f


# ---------- Mise en place ----------

func _ready() -> void:
	GameData.setup_inputs()
	sprite = $Sprite2D  # pas de @onready : main.gd peut rappeler _ready() si le script s'est détaché
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	weapon_layer = Node2D.new()
	weapon_layer.z_index = 1
	add_child(weapon_layer)
	weapon_layer.draw.connect(draw_weapon)
	add_to_group("player")
	apply_stats()


func apply_stats() -> void:
	frames = build_frames(GameData.character)
	speed = GameData.move_speed()
	jump_velocity = GameData.jump_velocity()
	fire_delay = GameData.fire_delay()
	attack_length = GameData.attack_length()
	sprite.texture = frames["idle"]


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(10, 15), Vector2(20, 31))


func is_invulnerable() -> bool:
	return dash_time > 0.0 or dead


func _unhandled_input(event: InputEvent) -> void:
	# clavier : mémorise les appuis comme les boutons tactiles
	for action in ["ui_accept", "attaque", "feu", "dash"]:
		if event.is_action_pressed(action):
			GameData.tap(action)


# ---------- Boucle physique ----------

func _physics_process(delta: float) -> void:
	GameData.update_taps(delta)

	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		position += velocity * delta
		sprite.rotation += 8.0 * delta
		return

	var on_floor := is_on_floor()
	if on_floor:
		air_time = 0.0
		jumps_left = 1 if GameData.get_level("double_saut") > 0 else 0
		if not was_on_floor:
			landed()
	else:
		air_time += delta
	was_on_floor = on_floor

	attack_cd = maxf(0.0, attack_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	cast_time = maxf(0.0, cast_time - delta)

	if attack_time > 0.0:
		attack_time -= delta
		var progress := 1.0 - attack_time / attack_length
		if not attack_hit_done and progress >= 0.3:
			attack_hit_done = true
			melee.emit(get_attack_rect(), GameData.melee_damage())

	# Ruée : vitesse fixe, pas de gravité
	if dash_time > 0.0:
		dash_time -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.03
			spawn_ghost()
		move_and_slide()
		update_animation(delta)
		return

	if not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	var direction := 0.0
	if can_control and hurt_time <= 0.0:
		direction = Input.get_axis("ui_left", "ui_right")
		handle_jump()
		handle_attack()
		handle_fire()
		handle_dash()

	if hurt_time > 0.0:
		hurt_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif direction != 0.0:
		velocity.x = direction * speed
		facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)

	move_and_slide()
	update_animation(delta)


func handle_jump() -> void:
	# Saut au sol : is_action_pressed (jamais raté au tactile)
	var wants := Input.is_action_pressed("ui_accept") or GameData.has_tap("ui_accept")
	if wants and air_time < COYOTE_TIME and velocity.y >= 0.0:
		do_jump()
	elif GameData.has_tap("ui_accept") and air_time >= COYOTE_TIME and jumps_left > 0:
		# double saut : il faut un nouvel appui
		jumps_left -= 1
		do_jump()
		if level:
			level.fx.ring(global_position + Vector2(0, 14), 12.0, Color.WHITE, 0.3)


func do_jump() -> void:
	velocity.y = jump_velocity
	air_time = COYOTE_TIME
	GameData.clear_tap("ui_accept")
	sprite.scale = Vector2(1.5, 2.5)
	dust(4)


func handle_attack() -> void:
	if attack_cd > 0.0:
		return
	if Input.is_action_pressed("attaque") or GameData.has_tap("attaque"):
		GameData.clear_tap("attaque")
		attack_time = attack_length
		attack_cd = attack_length + 0.06
		attack_hit_done = false


func handle_fire() -> void:
	if fire_cd > 0.0:
		return
	if Input.is_action_pressed("feu") or GameData.has_tap("feu"):
		GameData.clear_tap("feu")
		fire_cd = fire_delay
		cast_time = 0.25
		sprite.scale = Vector2(2.4, 1.8)
		fire.emit(global_position + Vector2(facing * 16.0, -2.0), facing)


func handle_dash() -> void:
	if GameData.get_level("dash") <= 0 or dash_cd > 0.0:
		return
	if Input.is_action_pressed("dash") or GameData.has_tap("dash"):
		GameData.clear_tap("dash")
		dash_time = DASH_TIME
		dash_cd = 0.7
		attack_time = 0.0
		if level:
			level.fx.burst(global_position, 10, 90.0, Color.WHITE, 0.35, 2.0)


func get_attack_rect() -> Rect2:
	var w := 40.0
	var h := 38.0
	match GameData.weapon:
		"hache":
			w = 38.0
			h = 48.0
		"lance":
			w = 66.0
			h = 18.0
	var x0 := global_position.x + 6.0 if facing > 0.0 else global_position.x - 6.0 - w
	return Rect2(x0, global_position.y - h * 0.5, w, h)


func landed() -> void:
	sprite.scale = Vector2(2.6, 1.5)
	dust(6)


func dust(count: int) -> void:
	if level:
		level.fx.burst(global_position + Vector2(0, 15), count, 50.0, Color(0.85, 0.85, 0.85), 0.35, 2.0, 0.0, 20.0)


func spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.flip_h = sprite.flip_h
	g.scale = sprite.scale
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.global_position = sprite.global_position
	g.modulate = Color(1, 1, 1, 0.5)
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


# ---------- Appelé par main.gd ----------

func bounce() -> void:
	if Input.is_action_pressed("ui_accept"):
		velocity.y = jump_velocity  # rebond plus haut si on garde le saut appuyé
	else:
		velocity.y = STOMP_BOUNCE
	air_time = COYOTE_TIME
	sprite.scale = Vector2(1.5, 2.5)


func take_hit(from_x: float) -> void:
	var dir := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(dir * 220.0, -260.0)
	hurt_time = 0.3
	attack_time = 0.0
	dash_time = 0.0


func die() -> void:
	dead = true
	can_control = false
	attack_time = 0.0
	velocity = Vector2(0, -380)
	sprite.texture = frames["hurt"]
	weapon_layer.queue_redraw()


# ---------- Animation ----------

func update_animation(delta: float) -> void:
	sprite.flip_h = facing < 0.0
	sprite.scale = sprite.scale.lerp(Vector2(2, 2), minf(1.0, 12.0 * delta))
	sprite.position.y = 0.0
	sprite.rotation = 0.0
	anim_time += delta
	var tex: Texture2D = frames["idle"]

	if hurt_time > 0.0:
		tex = frames["hurt"]
		sprite.rotation = -0.2 * facing
	elif attack_time > 0.0 or cast_time > 0.0:
		tex = frames["attack"]
	elif dash_time > 0.0:
		tex = frames["run0"]
		sprite.rotation = 0.15 * facing
	elif not is_on_floor():
		tex = frames["jump"] if velocity.y < 0.0 else frames["fall"]
	elif absf(velocity.x) > 10.0:
		var i := int(anim_time * 12.0) % 4
		tex = frames["run%d" % i]
		if i % 2 == 1:
			sprite.position.y = -1.0  # petit rebond du corps
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.25
			dust(2)
	else:
		# respiration
		if int(anim_time * 2.0) % 2 == 1:
			sprite.position.y = 1.0

	sprite.texture = tex
	weapon_layer.queue_redraw()


func draw_weapon() -> void:
	if attack_time <= 0.0 or dead:
		return
	var p := clampf(1.0 - attack_time / attack_length, 0.0, 1.0)
	var hand := Vector2(facing * 7.0, 3.0)
	var weapon_id := GameData.weapon

	if weapon_id == "lance":
		var reach := 12.0 + 48.0 * sin(p * PI)
		var tip := hand + Vector2(facing * reach, 0)
		var back := hand - Vector2(facing * 12.0, 0)
		weapon_layer.draw_line(back, tip, Color.BLACK, 5.0)
		weapon_layer.draw_line(back, tip, Color.WHITE, 3.0)
		var head := PackedVector2Array([tip + Vector2(facing * 10.0, 0), tip + Vector2(0, -5), tip + Vector2(0, 5)])
		weapon_layer.draw_colored_polygon(head, Color.WHITE)
		weapon_layer.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), Color.BLACK, 1.0)
		# traits de vitesse
		for k in 3:
			var yy := -6.0 + k * 6.0
			weapon_layer.draw_line(tip + Vector2(-facing * (20.0 + k * 6.0), yy), tip + Vector2(-facing * 6.0, yy), Color(1, 1, 1, 0.3 * sin(p * PI)), 1.0)
		return

	# épée et hache : arc de cercle de haut en bas
	var a0 := deg_to_rad(-115.0)
	var a1 := deg_to_rad(65.0)
	var s := p * p * (3.0 - 2.0 * p)
	var a := lerpf(a0, a1, s)
	var length := 26.0 if weapon_id == "epee" else 22.0
	# traînée blanche
	var trail := PackedVector2Array()
	var steps := 10
	for k in steps + 1:
		var ta := lerpf(maxf(a0, a - 1.6), a, float(k) / steps)
		trail.append(hand + Vector2(cos(ta) * facing, sin(ta)) * (length + 4.0))
	if trail.size() >= 2:
		weapon_layer.draw_polyline(trail, Color(1, 1, 1, 0.35), 7.0, true)
		weapon_layer.draw_polyline(trail, Color(1, 1, 1, 0.8), 2.0, true)
	var dir := Vector2(cos(a) * facing, sin(a))
	var tip := hand + dir * length
	weapon_layer.draw_line(hand, tip, Color.BLACK, 5.0)
	weapon_layer.draw_line(hand, tip, Color.WHITE, 3.0)
	var side := Vector2(-dir.y, dir.x)
	weapon_layer.draw_line(hand + dir * 5.0 - side * 5.0, hand + dir * 5.0 + side * 5.0, Color.WHITE, 2.0)
	if weapon_id == "hache":
		var c := hand + dir * (length - 4.0)
		var blade := PackedVector2Array([c - dir * 6.0, c + side * 10.0 - dir * 3.0, c + side * 11.0 + dir * 5.0, c + dir * 6.0])
		weapon_layer.draw_colored_polygon(blade, Color.WHITE)
		weapon_layer.draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3]]), Color.BLACK, 1.5)
