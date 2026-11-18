extends CanvasLayer
const GameData=preload("res://game_data.gd")
const Levels=preload("res://levels.gd")
const PlayerScript=preload("res://player.gd")
const WORLD_NAMES:=["LA FORÊT MORTE","LA GROTTE","LES MARAIS","LES NUAGES","LE CHÂTEAU"]
const TABS:=["COEURS","ARMES","POUVOIRS","PERSOS"]
var root:Control
var current_tab:="PERSOS"
var message:Label
func _ready()->void:
	layer=20
	root=Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	match GameData.screen:
		"carte":
			show_map()
		"magasin":
			show_shop()
		_:
			show_title()
static func make_style(bg:Color,border:Color,width:=2)->StyleBoxFlat:
	var sb:=StyleBoxFlat.new()
	sb.bg_color=bg
	sb.border_color=border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.content_margin_left=14
	sb.content_margin_right=14
	sb.content_margin_top=6
	sb.content_margin_bottom=6
	return sb
static func make_button(text:String,font_size:=20)->Button:
	var b:=Button.new()
	b.text=text
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_stylebox_override("normal",make_style(Color(0,0,0,0.85),Color.WHITE))
	b.add_theme_stylebox_override("hover",make_style(Color(0.12,0.12,0.12,0.9),Color.WHITE))
	b.add_theme_stylebox_override("pressed",make_style(Color.WHITE,Color.WHITE))
	b.add_theme_stylebox_override("disabled",make_style(Color(0,0,0,0.6),Color(0.35,0.35,0.35)))
	b.add_theme_color_override("font_color",Color.WHITE)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.BLACK)
	b.add_theme_color_override("font_disabled_color",Color(0.4,0.4,0.4))
	return b
static func make_label(text:String,font_size:=18,color:=Color.WHITE)->Label:
	var l:=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_outline_color",Color.BLACK)
	l.add_theme_constant_override("outline_size",6)
	return l
static func make_panel()->PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",make_style(Color(0,0,0,0.88),Color.WHITE))
	return p
func clear()->void:
	for c in root.get_children():
		c.queue_free()
func full_center()->CenterContainer:
	var cc:=CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return cc
func coins_text()->String:
	return "PIÈCES : %d     ÉCLATS : %d"%[GameData.coins,GameData.total_shards()]
func item_name(id:String)->String:
	for item in GameData.ITEMS:
		if item["id"]==id:
			return item["nom"]
	return id
func make_hero_preview(char_id:String,weapon_id:String,sk:float)->Control:
	var ctrl:=Control.new()
	ctrl.custom_minimum_size=Vector2(40,48)*sk
	ctrl.draw.connect(func():
		var t:=Time.get_ticks_msec()*0.001
		var c:=ctrl.size*0.5
		for k in 3:
			ctrl.draw_circle(c,(12.0+k*5.0)*sk,Color(1,1,1,0.05))
		var xf:=Transform2D(0.0,Vector2(sk,sk),0.0,c+Vector2(0,5.0*sk))
		var gun:=PlayerScript.is_gun(weapon_id)
		var st:={"t":t,"pose":"idle","facing":1.0}
		if weapon_id!="" and not gun:
			st["hand_b"]=Vector2(-4,6)
			ctrl.draw_set_transform_matrix(xf)
			PlayerScript.draw_weapon_shape(ctrl,Vector2(-4,6),Vector2(cos(deg_to_rad(-65.0)),sin(deg_to_rad(-65.0))),weapon_id,t)
		if gun:
			st["hand_f"]=Vector2(8,3)
		PlayerScript.draw_character(ctrl,char_id,st,xf)
		if gun:
			ctrl.draw_set_transform_matrix(xf)
			PlayerScript.draw_weapon_shape(ctrl,Vector2(8,3),Vector2(0.9,0.45).normalized(),weapon_id,t)
		ctrl.draw_set_transform(Vector2.ZERO)
	)
	get_tree().process_frame.connect(ctrl.queue_redraw)
	return ctrl
func make_weapon_icon(weapon_id:String)->Control:
	var ctrl:=Control.new()
	ctrl.custom_minimum_size=Vector2(44,44)
	ctrl.draw.connect(func():
		ctrl.draw_set_transform(ctrl.size*0.5,0.0,Vector2(1.1,1.1))
		PlayerScript.draw_weapon_shape(ctrl,Vector2(-11,11),Vector2(1,-1).normalized(),weapon_id,0.0)
		ctrl.draw_set_transform(Vector2.ZERO)
	)
	return ctrl
func go_to_level(index:int)->void:
	GameData.current_level=index
	GameData.screen="niveau"
	var main_node=get_tree().current_scene
	if main_node.has_method("fade_and_reload"):
		main_node.fade_and_reload()
	else:
		get_tree().reload_current_scene()
func show_title()->void:
	clear()
	GameData.screen="titre"
	var cc:=full_center()
	var box:=VBoxContainer.new()
	box.alignment=BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",6)
	cc.add_child(box)
	var title:=make_label("OMBRES",50)
	title.add_theme_constant_override("outline_size",12)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tw:=title.create_tween().set_loops()
	tw.tween_property(title,"modulate:a",0.6,1.4)
	tw.tween_property(title,"modulate:a",1.0,1.4)
	var sub:=make_label("Une aventure en noir et blanc",16,Color(0.75,0.75,0.75))
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(make_hero_preview(GameData.character,GameData.weapon,1.3))
	var equip_text:="%s  +  %s     COEURS : %d"%[item_name(GameData.character),item_name(GameData.weapon),GameData.max_hearts()]
	var eq:=make_label(equip_text,14,Color(0.8,0.8,0.8))
	eq.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eq)
	var play:=make_button("JOUER",26)
	play.custom_minimum_size=Vector2(220,50)
	play.pressed.connect(show_map)
	box.add_child(play)
	var shop:=make_button("MAGASIN",22)
	shop.custom_minimum_size=Vector2(220,44)
	shop.pressed.connect(show_shop)
	box.add_child(shop)
	var info:=make_label(coins_text(),16)
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var snd:=make_button("SON : OUI" if GameData.sfx_on else "SON : NON",14)
	snd.pressed.connect(func():
		GameData.sfx_on=not GameData.sfx_on
		GameData.music_on=GameData.sfx_on
		GameData.save_game()
		var main_node=get_tree().current_scene
		if main_node.sfx:
			if GameData.music_on:
				main_node.sfx.play_music(0,false)
			else:
				main_node.sfx.stop_music()
		show_title()
	)
	box.add_child(snd)
func show_map()->void:
	clear()
	GameData.screen="carte"
	var cc:=full_center()
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",5)
	cc.add_child(box)
	var head:=make_label("CHOISIS UN NIVEAU",24)
	head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var info:=make_label(coins_text(),15,Color(0.8,0.8,0.8))
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var levels:Array=Levels.all()
	if levels.is_empty():
		var warn:=make_label("Fichier niveaux.txt introuvable :\najoute-le à la racine du projet (res://).",16,Color(1,0.5,0.5))
		warn.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(warn)
	for w in WORLD_NAMES.size():
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		box.add_child(row)
		var wl:=make_label(WORLD_NAMES[w],15)
		wl.custom_minimum_size=Vector2(130,0)
		wl.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		row.add_child(wl)
		for k in 4:
			var index:=w*4+k
			if index>=levels.size():
				continue
			var data:Dictionary=levels[index]
			var label:="%d-%d"%[w+1,k+1]
			if data["boss"]!="":
				label="BOSS"
			if index<=GameData.unlocked:
				if data["boss"]=="":
					label+="  %d/3"%int(GameData.shards.get(index,0))
				elif int(GameData.shards.get(index,0))>0:
					label+="  OK"
			var b:=make_button(label if index<=GameData.unlocked else "- - -",15)
			b.custom_minimum_size=Vector2(100,36)
			b.disabled=index>GameData.unlocked
			b.pressed.connect(go_to_level.bind(index))
			row.add_child(b)
	var back:=make_button("RETOUR",18)
	back.pressed.connect(show_title)
	box.add_child(back)
func show_shop()->void:
	clear()
	GameData.screen="magasin"
	var margin:=MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side,16)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	margin.add_child(box)
	var top:=HBoxContainer.new()
	box.add_child(top)
	var back:=make_button("RETOUR",16)
	back.pressed.connect(show_title)
	top.add_child(back)
	var head:=make_label("  MAGASIN",26)
	head.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(head)
	top.add_child(make_label("PIÈCES : %d"%GameData.coins,18))
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	box.add_child(tabs)
	for tab in TABS:
		var tb:=make_button(tab,15)
		tb.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if tab==current_tab:
			tb.add_theme_stylebox_override("normal",make_style(Color.WHITE,Color.WHITE))
			tb.add_theme_color_override("font_color",Color.BLACK)
			tb.add_theme_color_override("font_hover_color",Color.BLACK)
		tb.pressed.connect(select_tab.bind(tab))
		tabs.add_child(tb)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	for item in GameData.ITEMS:
		if item["cat"]==current_tab:
			list.add_child(make_item_row(item))
	message=make_label("",15,Color(0.8,0.8,0.8))
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)
func select_tab(tab:String)->void:
	current_tab=tab
	show_shop()
func make_item_row(item:Dictionary)->Control:
	var panel:=make_panel()
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	panel.add_child(row)
	if item["type"]=="perso":
		var pic:=make_hero_preview(item["id"],"",0.95)
		row.add_child(pic)
	elif item["type"]=="arme":
		row.add_child(make_weapon_icon(item["id"]))
	var texts:=VBoxContainer.new()
	texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var lvl:=GameData.get_level(item["id"])
	var title:String=item["nom"]
	var max_lvl:int=item["prix"].size()
	if item["type"]=="niveau" and max_lvl>1:
		title+="   (niv %d/%d)"%[lvl,max_lvl]
	texts.add_child(make_label(title,18))
	var desc:=make_label(item["desc"],13,Color(0.7,0.7,0.7))
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)
	var b:=make_button("",16)
	b.custom_minimum_size=Vector2(130,40)
	var price:=GameData.next_price(item)
	var equippable:bool=item["type"]=="arme" or item["type"]=="perso"
	var equipped:bool=(item["type"]=="arme" and GameData.weapon==item["id"])or(item["type"]=="perso" and GameData.character==item["id"])
	if equippable and lvl>0:
		if equipped:
			b.text="ÉQUIPÉ"
			b.disabled=true
		else:
			b.text="ÉQUIPER"
			b.pressed.connect(equip.bind(item))
	elif price<0:
		b.text="MAX"
		b.disabled=true
	else:
		b.text="%d pièces"%price
		b.disabled=GameData.coins<price
		b.pressed.connect(purchase.bind(item))
	row.add_child(b)
	return panel
func purchase(item:Dictionary)->void:
	if GameData.buy(item):
		show_shop()
		message.text="Acheté : %s !"%item["nom"]
func equip(item:Dictionary)->void:
	if item["type"]=="arme":
		GameData.weapon=item["id"]
	else:
		GameData.character=item["id"]
	GameData.save_game()
	show_shop()
	message.text="Équipé : %s"%item["nom"]
