extends CharacterBody2D

const SPEED := 170.0
const JUMP_VELOCITY := -430.0
const GRAVITY := 1000.0
const COYOTE_TIME := 0.1      # petit délai pour sauter juste après avoir quitté le bord
const STOMP_BOUNCE := -300.0  # rebond après avoir écrasé un ennemi
const ANIM_SPEED := 10.0      # images de marche par seconde

var can_control := true
var anim_time := 0.0
var air_time := 0.0

var tex_idle: ImageTexture
var tex_jump: ImageTexture
var walk_frames: Array[ImageTexture] = []

var sprite: Sprite2D

# Haut du corps commun à toutes les images (13 lignes).
# "." = transparent, "#" = noir, "w" = blanc
const BODY := [
	"................",
	"....########....",
	"...#wwwwwwww#...",
	"..#wwwwwwwwww#..",
	"..#wwww#ww#ww#..",
	"..#wwww#ww#ww#..",
	"..#wwwwwwwwww#..",
	"...#wwwwwwww#...",
	"....########....",
	"...#wwwwwwww#...",
	"..#ww#wwwwww#...",
	"..#ww#wwwwww#...",
	"...#wwwwwwww#...",
]

# Jambes (3 lignes) pour chaque pose.
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
const LEGS_CROSS := [
	".....#wwww#.....",
	"....#ww##ww#....",
	"...###....###...",
]
const LEGS_JUMP := [
	"...#ww#..#ww#...",
	"...###....###...",
	"................",
]


func _ready() -> void:
	sprite = $Sprite2D  # pas de @onready : main.gd peut rappeler _ready() si le script s'est détaché
	tex_idle = make_texture(BODY + LEGS_IDLE)
	tex_jump = make_texture(BODY + LEGS_JUMP)
	# Cycle de marche : écarté, joint, croisé, joint
	walk_frames = [
		make_texture(BODY + LEGS_SPREAD),
		tex_idle,
		make_texture(BODY + LEGS_CROSS),
		tex_idle,
	]
	sprite.texture = tex_idle
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	add_to_group("player")


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
	if is_on_floor():
		air_time = 0.0
	else:
		air_time += delta
		velocity.y += GRAVITY * delta

	var direction := 0.0
	if can_control:
		direction = Input.get_axis("ui_left", "ui_right")
		# is_action_pressed (et pas just_pressed) : le tap tactile n'est jamais raté
		if Input.is_action_pressed("ui_accept") and air_time < COYOTE_TIME and velocity.y >= 0.0:
			velocity.y = JUMP_VELOCITY
			air_time = COYOTE_TIME

	if direction != 0.0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
	update_animation(delta, direction)


func update_animation(delta: float, direction: float) -> void:
	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if not is_on_floor():
		sprite.texture = tex_jump
		sprite.position.y = 0.0
	elif absf(velocity.x) > 10.0:
		anim_time += delta
		var frame_index := int(anim_time * ANIM_SPEED) % walk_frames.size()
		sprite.texture = walk_frames[frame_index]
		# petit rebond du corps sur les images « jambes jointes »
		sprite.position.y = -1.0 if frame_index % 2 == 1 else 0.0
	else:
		anim_time = 0.0
		sprite.texture = tex_idle
		sprite.position.y = 0.0


# Appelé par main.gd quand on écrase un ennemi
func bounce() -> void:
	if Input.is_action_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY  # rebond plus haut si on garde ▲ appuyé
	else:
		velocity.y = STOMP_BOUNCE
	air_time = COYOTE_TIME
