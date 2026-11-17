extends CanvasLayer

const GameData = preload("res://game_data.gd")
const Levels = preload("res://levels.gd")
const PlayerScript = preload("res://player.gd")

# Écrans de menu construits en code : titre, carte des niveaux, magasin.

const WORLD_NAMES := ["LA FORÊT MORTE", "LA GROTTE", "LE CHÂTEAU"]
const TABS := ["COEURS", "ARMES", "POUVOIRS", "PERSOS"]

var root: Control
var current_tab := "PERSOS"
var message: Label


func _ready() -> void:
	layer = 20
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match GameData.screen:
		"carte":
			show_map()
		"magasin":
			show_shop()
		_:
			show_title()


# ---------- Styles (aussi utilisés par main.gd) ----------

static func make_style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func make_button(text: String, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", make_style(Color(0, 0, 0, 0.85), Color.WHITE))
	b.add_theme_stylebox_override("hover", make_style(Color(0.12, 0.12, 0.12, 0.9), Color.WHITE))
	b.add_theme_stylebox_override("pressed", make_style(Color.WHITE, Color.WHITE))
	b.add_theme_stylebox_override("disabled", make_style(Color(0, 0, 0, 0.6), Color(0.35, 0.35, 0.35)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	return b


static func make_label(text: String, font_size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", make_style(Color(0, 0, 0, 0.88), Color.WHITE))
	return p


# ---------- Outils ----------

func clear() -> void:
	for c in root.get_children():
		c.queue_free()


func full_center() -> CenterContainer:
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cc


func coins_text() -> String:
	return "PIÈCES : %d     ÉCLATS : %d" % [GameData.coins, GameData.total_shards()]


func item_name(id: String) -> String:
	for item in GameData.ITEMS:
		if item["id"] == id:
			return item["nom"]
	return id


# Personnage (et arme) dessinés en grand, avec un halo
func make_hero_preview(char_id: String, weapon_id: String, scale_k: float) -> Control:
	var tex: Texture2D = PlayerScript.build_frames(char_id)["idle"]
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(16, 18) * scale_k * 1.6
	ctrl.draw.connect(func():
		var c := ctrl.size * 0.5
		for k in 3:
			ctrl.draw_circle(c, (10.0 + k * 6.0) * scale_k, Color(1, 1, 1, 0.05))
		if weapon_id != "":
			ctrl.draw_set_transform(c, 0.0, Vector2(scale_k * 0.5, scale_k * 0.5))
			var rest := Vector2(cos(deg_to_rad(-65.0)), sin(deg_to_rad(-65.0)))
			PlayerScript.draw_weapon_shape(ctrl, Vector2(-4, 6) * 2.0, rest, weapon_id, 0.0)
			ctrl.draw_set_transform(Vector2.ZERO)
		var sz := Vector2(16, 16) * scale_k
		ctrl.draw_texture_rect(tex, Rect2(c - sz * 0.5, sz), false)
	)
	ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ctrl


# Icône d'arme pour le magasin
func make_weapon_icon(weapon_id: String) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(44, 44)
	ctrl.draw.connect(func():
		ctrl.draw_set_transform(ctrl.size * 0.5, 0.0, Vector2(1.1, 1.1))
		PlayerScript.draw_weapon_shape(ctrl, Vector2(-11, 11), Vector2(1, -1).normalized(), weapon_id, 0.0)
		ctrl.draw_set_transform(Vector2.ZERO)
	)
	return ctrl


func go_to_level(index: int) -> void:
	GameData.current_level = index
	GameData.screen = "niveau"
	get_tree().reload_current_scene()


# ---------- Titre ----------

func show_title() -> void:
	clear()
	GameData.screen = "titre"
	var cc := full_center()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	cc.add_child(box)

	var title := make_label("OMBRES", 58)
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "modulate:a", 0.6, 1.4)
	tw.tween_property(title, "modulate:a", 1.0, 1.4)

	var sub := make_label("Une aventure en noir et blanc", 16, Color(0.75, 0.75, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(make_hero_preview(GameData.character, GameData.weapon, 2.6))
	var equip_text := "%s  +  %s     COEURS : %d" % [item_name(GameData.character), item_name(GameData.weapon), GameData.max_hearts()]
	var eq := make_label(equip_text, 14, Color(0.8, 0.8, 0.8))
	eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eq)

	var play := make_button("JOUER", 26)
	play.custom_minimum_size = Vector2(220, 50)
	play.pressed.connect(show_map)
	box.add_child(play)
	var shop := make_button("MAGASIN", 22)
	shop.custom_minimum_size = Vector2(220, 44)
	shop.pressed.connect(show_shop)
	box.add_child(shop)

	var info := make_label(coins_text(), 16)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)


# ---------- Carte des niveaux ----------

func show_map() -> void:
	clear()
	GameData.screen = "carte"
	var cc := full_center()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	cc.add_child(box)

	var head := make_label("CHOISIS UN NIVEAU", 28)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var info := make_label(coins_text(), 15, Color(0.8, 0.8, 0.8))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	var levels: Array = Levels.LEVELS
	for w in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var wl := make_label(WORLD_NAMES[w], 15)
		wl.custom_minimum_size = Vector2(150, 0)
		wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(wl)
		for k in 3:
			var index := w * 3 + k
			if index >= levels.size():
				continue
			var data: Dictionary = levels[index]
			var label := "%d-%d" % [w + 1, k + 1]
			if data["boss"] != "":
				label = "BOSS"
			if index <= GameData.unlocked:
				if data["boss"] == "":
					label += "  %d/3" % int(GameData.shards.get(index, 0))
				elif int(GameData.shards.get(index, 0)) > 0:
					label += "  OK"
			var b := make_button(label if index <= GameData.unlocked else "- - -", 17)
			b.custom_minimum_size = Vector2(118, 42)
			b.disabled = index > GameData.unlocked
			b.pressed.connect(go_to_level.bind(index))
			row.add_child(b)

	var back := make_button("RETOUR", 18)
	back.pressed.connect(show_title)
	box.add_child(back)


# ---------- Magasin ----------

func show_shop() -> void:
	clear()
	GameData.screen = "magasin"
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var back := make_button("RETOUR", 16)
	back.pressed.connect(show_title)
	top.add_child(back)
	var head := make_label("  MAGASIN", 26)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	top.add_child(make_label("PIÈCES : %d" % GameData.coins, 18))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for tab in TABS:
		var tb := make_button(tab, 15)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tab == current_tab:
			tb.add_theme_stylebox_override("normal", make_style(Color.WHITE, Color.WHITE))
			tb.add_theme_color_override("font_color", Color.BLACK)
			tb.add_theme_color_override("font_hover_color", Color.BLACK)
		tb.pressed.connect(select_tab.bind(tab))
		tabs.add_child(tb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for item in GameData.ITEMS:
		if item["cat"] == current_tab:
			list.add_child(make_item_row(item))

	message = make_label("", 15, Color(0.8, 0.8, 0.8))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)


func select_tab(tab: String) -> void:
	current_tab = tab
	show_shop()


func make_item_row(item: Dictionary) -> Control:
	var panel := make_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	if item["type"] == "perso":
		var pic := make_hero_preview(item["id"], "", 2.0)
		pic.custom_minimum_size = Vector2(44, 44)
		row.add_child(pic)
	elif item["type"] == "arme":
		row.add_child(make_weapon_icon(item["id"]))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var lvl := GameData.get_level(item["id"])
	var title: String = item["nom"]
	var max_lvl: int = item["prix"].size()
	if item["type"] == "niveau" and max_lvl > 1:
		title += "   (niv %d/%d)" % [lvl, max_lvl]
	texts.add_child(make_label(title, 18))
	var desc := make_label(item["desc"], 13, Color(0.7, 0.7, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)

	var b := make_button("", 16)
	b.custom_minimum_size = Vector2(130, 40)
	var price := GameData.next_price(item)
	var equippable: bool = item["type"] == "arme" or item["type"] == "perso"
	var equipped: bool = (item["type"] == "arme" and GameData.weapon == item["id"]) or (item["type"] == "perso" and GameData.character == item["id"])
	if equippable and lvl > 0:
		if equipped:
			b.text = "ÉQUIPÉ"
			b.disabled = true
		else:
			b.text = "ÉQUIPER"
			b.pressed.connect(equip.bind(item))
	elif price < 0:
		b.text = "MAX"
		b.disabled = true
	else:
		b.text = "%d pièces" % price
		b.disabled = GameData.coins < price
		b.pressed.connect(purchase.bind(item))
	row.add_child(b)
	return panel


func purchase(item: Dictionary) -> void:
	if GameData.buy(item):
		show_shop()
		message.text = "Acheté : %s !" % item["nom"]


func equip(item: Dictionary) -> void:
	if item["type"] == "arme":
		GameData.weapon = item["id"]
	else:
		GameData.character = item["id"]
	GameData.save_game()
	show_shop()
	message.text = "Équipé : %s" % item["nom"]
