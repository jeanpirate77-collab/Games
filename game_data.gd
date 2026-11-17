extends RefCounted

# Données conservées entre les niveaux (pièces, achats, progression) et sauvegardées.
# Pas besoin d'Autoload : les autres scripts font
#     const GameData = preload("res://game_data.gd")
# puis GameData.coins, GameData.buy(...), etc.

const SAVE_PATH := "user://sauvegarde.cfg"

# Catalogue du magasin.
#   type "niveau" : amélioration à plusieurs niveaux (prix[i] = prix du niveau i+1)
#   type "arme" / "perso" : à acheter une fois, puis à équiper
const ITEMS := [
	{"id": "armure", "cat": "ARMURE", "nom": "Armure", "desc": "+1 coeur maximum par niveau", "prix": [60, 130, 220], "type": "niveau"},
	{"id": "bottes", "cat": "ARMURE", "nom": "Bottes légères", "desc": "+10 % de vitesse par niveau", "prix": [80, 170], "type": "niveau"},
	{"id": "epee", "cat": "ARMES", "nom": "Épée", "desc": "Rapide. Dégâts 1", "prix": [0], "type": "arme"},
	{"id": "hache", "cat": "ARMES", "nom": "Hache", "desc": "Lente mais dégâts 2", "prix": [110], "type": "arme"},
	{"id": "lance", "cat": "ARMES", "nom": "Lance", "desc": "Très longue portée. Dégâts 1", "prix": [130], "type": "arme"},
	{"id": "forge", "cat": "ARMES", "nom": "Forge", "desc": "+1 dégât pour toutes les armes", "prix": [90, 180, 300], "type": "niveau"},
	{"id": "feu", "cat": "POUVOIRS", "nom": "Boule de feu", "desc": "Niv 2 : recharge rapide. Niv 3 : triple tir", "prix": [0, 90, 200], "type": "niveau"},
	{"id": "double_saut", "cat": "POUVOIRS", "nom": "Double saut", "desc": "Sauter une 2e fois en l'air", "prix": [150], "type": "niveau"},
	{"id": "dash", "cat": "POUVOIRS", "nom": "Ruée", "desc": "Bouton >> : ruée rapide et invincible", "prix": [120], "type": "niveau"},
	{"id": "aimant", "cat": "POUVOIRS", "nom": "Aimant", "desc": "Attire les pièces proches", "prix": [70], "type": "niveau"},
	{"id": "ombre", "cat": "PERSOS", "nom": "Ombre", "desc": "Équilibré", "prix": [0], "type": "perso"},
	{"id": "lune", "cat": "PERSOS", "nom": "Lune", "desc": "Rapide, saute plus haut, feu plus rapide", "prix": [160], "type": "perso"},
	{"id": "roc", "cat": "PERSOS", "nom": "Roc", "desc": "+1 coeur, +1 dégât, mais plus lent", "prix": [220], "type": "perso"},
]

static var coins := 0
static var upgrades := {"epee": 1, "ombre": 1, "feu": 1}
static var character := "ombre"
static var weapon := "epee"
static var unlocked := 0          # dernier niveau débloqué
static var shards := {}           # index du niveau -> éclats trouvés (meilleur score)
static var screen := "titre"      # "titre", "carte", "magasin" ou "niveau"
static var current_level := 0
static var taps := {}             # appuis récents (pour ne jamais rater un tap)
static var loaded := false


# ---------- Sauvegarde ----------

static func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jeu", "coins", coins)
	cfg.set_value("jeu", "upgrades", upgrades)
	cfg.set_value("jeu", "character", character)
	cfg.set_value("jeu", "weapon", weapon)
	cfg.set_value("jeu", "unlocked", unlocked)
	cfg.set_value("jeu", "shards", shards)
	cfg.save(SAVE_PATH)


static func load_game() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("jeu", "coins", 0)
	upgrades = cfg.get_value("jeu", "upgrades", upgrades)
	character = cfg.get_value("jeu", "character", "ombre")
	weapon = cfg.get_value("jeu", "weapon", "epee")
	unlocked = cfg.get_value("jeu", "unlocked", 0)
	shards = cfg.get_value("jeu", "shards", {})


static func total_shards() -> int:
	var n := 0
	for k in shards:
		n += int(shards[k])
	return n


# ---------- Magasin ----------

static func get_level(id: String) -> int:
	return int(upgrades.get(id, 0))


static func next_price(item: Dictionary) -> int:
	var lvl := get_level(item["id"])
	var prices: Array = item["prix"]
	if lvl >= prices.size():
		return -1
	return int(prices[lvl])


static func buy(item: Dictionary) -> bool:
	var price := next_price(item)
	if price < 0 or coins < price:
		return false
	coins -= price
	upgrades[item["id"]] = get_level(item["id"]) + 1
	if item["type"] == "arme":
		weapon = item["id"]
	elif item["type"] == "perso":
		character = item["id"]
	save_game()
	return true


# ---------- Statistiques du joueur ----------

static func max_hearts() -> int:
	return 3 + get_level("armure") + (1 if character == "roc" else 0)


static func melee_damage() -> int:
	var dmg := 2 if weapon == "hache" else 1
	return dmg + get_level("forge") + (1 if character == "roc" else 0)


static func move_speed() -> float:
	var s := 170.0 * (1.0 + 0.1 * get_level("bottes"))
	if character == "lune":
		s *= 1.15
	elif character == "roc":
		s *= 0.9
	return s


static func jump_velocity() -> float:
	return -480.0 if character == "lune" else -440.0


static func fire_delay() -> float:
	var d := 1.0 if get_level("feu") >= 2 else 1.6
	if character == "lune":
		d *= 0.75
	return d


static func attack_length() -> float:
	match weapon:
		"hache":
			return 0.45
		"lance":
			return 0.36
	return 0.28


# ---------- Entrées ----------

static func setup_inputs() -> void:
	# Actions en plus de ui_left / ui_right / ui_accept (touches pour tester au clavier)
	var keys := {"attaque": KEY_X, "feu": KEY_C, "dash": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


# Un tap est mémorisé 0,15 s : même un appui très court n'est jamais perdu
static func tap(action: String) -> void:
	taps[action] = 0.15


static func has_tap(action: String) -> bool:
	return float(taps.get(action, 0.0)) > 0.0


static func clear_tap(action: String) -> void:
	taps[action] = 0.0


static func update_taps(delta: float) -> void:
	for k in taps.keys():
		taps[k] = maxf(0.0, float(taps[k]) - delta)


# ---------- Pixel art ----------

# Crée une texture à partir de lignes de texte.
# "." transparent, "#" noir, "w" blanc, "g" gris clair, "d" gris foncé
static func make_texture(rows: Array, invert := false) -> ImageTexture:
	var w: int = rows[0].length()
	var h: int = rows.size()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var c := line[x]
			var col := Color(0, 0, 0, 0)
			match c:
				"#":
					col = Color.WHITE if invert else Color.BLACK
				"w":
					col = Color.BLACK if invert else Color.WHITE
				"g":
					col = Color(0.62, 0.62, 0.62)
				"d":
					col = Color(0.3, 0.3, 0.3)
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
