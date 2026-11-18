extends Node2D
const GameData=preload("res://game_data.gd")
const Levels=preload("res://levels.gd")
const EnemyScript=preload("res://enemy.gd")
const BossScript=preload("res://boss.gd")
const ProjectileScript=preload("res://fireball.gd")
const PickupScript=preload("res://pickup.gd")
const FxScript=preload("res://fx.gd")
const MenuScript=preload("res://menu.gd")
const ObstacleScript=preload("res://obstacle.gd")
const SfxScript=preload("res://sfx.gd")
const TILE:=32
const INVINCIBLE_TIME:=1.2
const PARALLAX_W:=1200.0
const ENEMY_CHARS:={"w":"marcheur","s":"tireur","f":"chauve-souris","j":"sauteur","g":"spectre","e":"oeil","K":"chevalier"}
const OBSTACLE_CHARS:={"a":"acide","x":"fragile","k":"ressort","r":"scie","l":"flammes","u":"stalactite","q":"pendule","T":"torche","O":"boule","n":"canon","V":"vent"}
const VIEW_HEIGHT:=384.0
const HEART_RED:=Color(0.92,0.16,0.22)
const HEART:=[".##.##.","#######","#######",".#####.","..###..","...#..."]
const POST_FX:=true
const DARKNESS:=[0.62,0.42,0.55,0.5,0.8]
var grid:Array=[]
var cols:=0
var rows:=0
var world:=0
var level_data:Dictionary={}
var in_level:=false
var hearts:=3
var max_hearts:=3
var level_coins:=0
var shards_found:Array=[false,false,false]
var shard_count:=0
var invincible:=0.0
var finished:=false
var respawn_point:=Vector2.ZERO
var checkpoints:Array=[]
var exit_pos:=Vector2(-1000,-1000)
var exit_open:=true
var exit_alpha:=1.0
var boss=null
var movers:Array=[]
var crates:={}
var time:=0.0
var look:=0.0
var shake_amount:=0.0
var flash_alpha:=0.0
var next_lightning:=5.0
var ambient_timer:=0.0
var rain:Array=[]
var camera:Camera2D
var fx
var sky:Node2D
var deco:Node2D
var weather:Node2D
var hud_layer:CanvasLayer
var hud_draw:Node2D
var coin_label:Label
var banner:Label
var boss_label:Label
var pause_button:Button
var panel:Control=null
var touch=null
var light_tex:GradientTexture2D
var door_light:PointLight2D
var fog_art:Node2D
var sfx=null
var water_cells:Array=[]
var water_layer:Node2D
var tile_chunks:Array=[]
var canvas:CanvasItem=null
@onready var player=$Player
func _ready()->void:
	Engine.time_scale=1.0
	get_tree().paused=false
	GameData.load_game()
	GameData.setup_inputs()
	GameData.taps.clear()
	var win:=get_window()
	win.content_scale_size=Vector2i(640,360)
	win.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	light_tex=make_light_texture()
	ensure_script(player,"res://player.gd")
	ensure_script($CanvasLayer,"res://canvas_layer.gd")
	touch=$CanvasLayer
	if has_node("StaticBody2D"):
		$StaticBody2D.queue_free()
	fx=FxScript.new()
	add_child(fx)
	sfx=SfxScript.new()
	add_child(sfx)
	get_viewport().size_changed.connect(on_resize)
	if GameData.screen=="niveau":
		start_level()
	else:
		start_menu()
	setup_fade()
var fade_rect:ColorRect
func setup_fade()->void:
	var layer:=CanvasLayer.new()
	layer.layer=100
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	fade_rect=ColorRect.new()
	fade_rect.color=Color.BLACK
	fade_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw:=fade_rect.create_tween()
	tw.tween_property(fade_rect,"color:a",0.0,0.4)
func fade_and_reload()->void:
	get_tree().paused=false
	fade_rect.mouse_filter=Control.MOUSE_FILTER_STOP
	var tw:=fade_rect.create_tween()
	tw.tween_property(fade_rect,"color:a",1.0,0.25)
	tw.tween_callback(func():get_tree().reload_current_scene())
func ensure_script(node:Node,path:String)->void:
	if node.get_script()!=null:
		return
	push_warning("Script manquant sur %s : rattaché automatiquement."%node.name)
	node.set_script(load(path))
	node.call("_ready")
	node.set_physics_process(true)
	node.set_process(true)
	node.set_process_input(true)
	node.set_process_unhandled_input(true)
func start_menu()->void:
	in_level=false
	world=0
	player.visible=false
	player.process_mode=Node.PROCESS_MODE_DISABLED
	touch.visible=false
	touch.process_mode=Node.PROCESS_MODE_DISABLED
	setup_background()
	camera=Camera2D.new()
	camera.position=Vector2(0,192)
	add_child(camera)
	camera.make_current()
	update_zoom()
	setup_foreground()
	setup_vignette()
	add_child(MenuScript.new())
	sfx.play_music(0,false)
func start_level()->void:
	var all:Array=Levels.all()
	if all.is_empty():
		GameData.screen="carte"
		start_menu()
		return
	in_level=true
	GameData.current_level=clampi(GameData.current_level,0,all.size()-1)
	level_data=all[GameData.current_level]
	world=int(level_data["monde"])
	grid=[]
	for line in level_data["carte"]:
		grid.append(unpack_row(line))
	rows=grid.size()
	cols=String(grid[0]).length()
	max_hearts=GameData.max_hearts()
	hearts=max_hearts
	player.level=self
	player.apply_stats()
	player.melee.connect(_on_player_melee)
	player.fire.connect(_on_player_fire)
	touch.player=player
	touch.layout()
	setup_background()
	build_level()
	deco=Node2D.new()
	add_child(deco)
	move_child(deco,0)
	deco.draw.connect(draw_deco)
	build_tile_chunks()
	if not water_cells.is_empty():
		water_layer=Node2D.new()
		water_layer.z_index=5
		add_child(water_layer)
		water_layer.draw.connect(draw_water)
	sfx.play_music(world,level_data["boss"]!="")
	setup_camera()
	setup_hud()
	setup_foreground()
	setup_lighting()
	setup_vignette()
	if world==2:
		setup_rain()
	show_banner(level_data["nom"])
static func unpack_row(packed:String)->String:
	var out:=""
	var n:=0
	for ch in packed:
		if ch>="0" and ch<="9":
			n=n*10+int(ch)
		else:
			out+=ch.repeat(maxi(n,1))
			n=0
	return out
func build_level()->void:
	var solid_body:=StaticBody2D.new()
	add_child(solid_body)
	var mover_index:=0
	for r in rows:
		var line:String=grid[r]
		var c:=0
		while c<cols:
			var ch:=line[c]
			if ch=="#" or ch=="=":
				var start:=c
				while c<cols and line[c]==ch:
					c+=1
				add_run(solid_body,start,c,r,ch=="=")
				continue
			var center:=Vector2(c*TILE+16,r*TILE+16)
			match ch:
				"P":
					player.global_position=center
					respawn_point=center
					set_cell(c,r,".")
				"E":
					exit_pos=center
					set_cell(c,r,".")
				"C":
					checkpoints.append({"pos":center,"on":false})
					set_cell(c,r,".")
				"o":
					spawn_pickup("piece",center)
					set_cell(c,r,".")
				"h":
					spawn_pickup("coeur",center)
					set_cell(c,r,".")
				"*":
					var p=spawn_pickup("eclat",center)
					p.shard_id=shard_count
					shard_count+=1
					set_cell(c,r,".")
				"B","D","c":
					add_crate(c,r)
				"/","\\":
					add_slope(solid_body,c,r,ch)
				"m","M":
					add_mover(center,mover_index,ch=="M")
					mover_index+=1
					set_cell(c,r,".")
				"$":
					spawn_pickup("tresor",center)
					set_cell(c,r,".")
				"~":
					water_cells.append(Vector2i(c,r))
				"Z":
					spawn_boss(center)
					set_cell(c,r,".")
				_:
					if ENEMY_CHARS.has(ch):
						spawn_enemy(ENEMY_CHARS[ch],center)
						set_cell(c,r,".")
					elif OBSTACLE_CHARS.has(ch):
						spawn_obstacle(OBSTACLE_CHARS[ch],center)
						set_cell(c,r,".")
			c+=1
func add_run(body:StaticBody2D,c0:int,c1:int,r:int,one_way:bool)->void:
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	var h:=12.0 if one_way else float(TILE)
	rect.size=Vector2((c1-c0)*TILE,h)
	shape.shape=rect
	shape.position=Vector2(c0*TILE+rect.size.x*0.5,r*TILE+h*0.5)
	shape.one_way_collision=one_way
	body.add_child(shape)
func add_slope(body:StaticBody2D,c:int,r:int,ch:String)->void:
	var shape:=CollisionShape2D.new()
	var poly:=ConvexPolygonShape2D.new()
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	if ch=="/":
		poly.points=PackedVector2Array([Vector2(x,y+TILE),Vector2(x+TILE,y),Vector2(x+TILE,y+TILE)])
	else:
		poly.points=PackedVector2Array([Vector2(x,y),Vector2(x+TILE,y+TILE),Vector2(x,y+TILE)])
	shape.shape=poly
	body.add_child(shape)
func add_crate(c:int,r:int)->void:
	var body:=StaticBody2D.new()
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=Vector2(TILE,TILE)
	shape.shape=rect
	body.position=Vector2(c*TILE+16,r*TILE+16)
	body.add_child(shape)
	add_child(body)
	crates[Vector2i(c,r)]=body
func add_mover(center:Vector2,index:int,vertical:=false)->void:
	var body:=AnimatableBody2D.new()
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=Vector2(96,12)
	shape.shape=rect
	shape.one_way_collision=true
	body.add_child(shape)
	body.position=Vector2(center.x,center.y-10.0)
	add_child(body)
	body.draw.connect(draw_mover.bind(body))
	movers.append({"body":body,"base":body.position,"phase":PI*(index%2),"vertical":vertical})
func spawn_boss(center:Vector2)->void:
	var gy:=center.y
	var gc:=int(center.x/TILE)
	while gy<rows*TILE and not "#a/\\=".contains(cell(gc,int(gy/TILE))):
		gy+=TILE
	boss=BossScript.new()
	boss.kind=level_data["boss"]
	boss.level=self
	boss.target=player
	boss.arena_left=TILE
	boss.arena_right=(cols-1)*TILE
	boss.ground_y=floor(gy/TILE)*TILE
	boss.position=center
	add_child(boss)
	add_light(boss,1.6,0.7)
	sound("boss",0.0)
	exit_open=false
	exit_alpha=0.0
func cell(c:int,r:int)->String:
	if c<0 or c>=cols or rows==0:
		return "#"
	var line:String=grid[clampi(r,0,rows-1)]
	return line[c]
func set_cell(c:int,r:int,ch:String)->void:
	var line:String=grid[r]
	grid[r]=line.substr(0,c)+ch+line.substr(c+1)
func is_solid(p:Vector2,platforms:=false)->bool:
	var c:=int(floor(p.x/TILE))
	var r:=int(floor(p.y/TILE))
	if c<0 or c>=cols:
		return true
	if r<0 or r>=rows:
		return false
	var line:String=grid[r]
	var ch:=line[c]
	if ch=="/" or ch=="\\":
		var lx:=p.x-c*TILE
		var ly:=p.y-r*TILE
		return ly>=TILE-lx if ch=="/" else ly>=lx
	return ch=="#" or ch=="B" or ch=="D" or ch=="c" or(platforms and ch=="=")
func is_water(p:Vector2)->bool:
	var c:=int(floor(p.x/TILE))
	var r:=int(floor(p.y/TILE))
	if c<0 or c>=cols or r<0 or r>=rows:
		return false
	var line:String=grid[r]
	return line[c]=="~"
func ground_at(c:int,r:int)->bool:
	var ch:=cell(c,r)
	return ch=="#" or ch=="/" or ch=="\\"
func sound(sound_name:String,jitter:=0.06)->void:
	if sfx:
		sfx.play(sound_name,jitter)
func world_bottom()->float:
	return float(rows*TILE)
func spawn_enemy(kind:String,pos:Vector2):
	var e=EnemyScript.new()
	e.kind=kind
	e.level=self
	e.target=player
	e.position=pos
	add_child(e)
	return e
func spawn_projectile(pos:Vector2,vel:Vector2,team:String,kind:String,damage:=1):
	var p=ProjectileScript.new()
	p.level=self
	p.team=team
	p.kind=kind
	p.velocity=vel
	p.damage=damage
	p.position=pos
	add_child(p)
	return p
func spawn_pickup(kind:String,pos:Vector2,pop:=false):
	var p=PickupScript.new()
	p.kind=kind
	p.level=self
	p.target=player
	p.position=pos
	if pop:
		p.falling=true
		p.vel=Vector2(randf_range(-90,90),randf_range(-280,-180))
	add_child(p)
	return p
func spawn_obstacle(kind:String,pos:Vector2):
	var o=ObstacleScript.new()
	o.kind=kind
	o.level=self
	o.player=player
	o.position=pos
	add_child(o)
	return o
func count_enemies(kind:String)->int:
	var n:=0
	for e in group("ennemis"):
		if not e.dead and e.kind==kind:
			n+=1
	return n
func group(group_name:String)->Array:
	return get_tree().get_nodes_in_group(group_name)
func boss_alive()->bool:
	return boss!=null and is_instance_valid(boss)and not boss.dead
func setup_camera()->void:
	camera=Camera2D.new()
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=cols*TILE
	camera.limit_bottom=rows*TILE
	camera.position_smoothing_enabled=true
	camera.position_smoothing_speed=7.0
	camera.drag_vertical_enabled=true
	camera.drag_top_margin=0.3
	camera.drag_bottom_margin=0.15
	player.add_child(camera)
	camera.make_current()
	update_zoom()
func update_zoom()->void:
	var h:=get_viewport().get_visible_rect().size.y
	var view_h:=VIEW_HEIGHT
	var z:=h/view_h
	camera.zoom=Vector2(z,z)
func on_resize()->void:
	if sky:
		sky.queue_redraw()
	if camera:
		update_zoom()
	if hud_layer:
		layout_hud()
func shake(amount:float)->void:
	shake_amount=maxf(shake_amount,amount)
func freeze(duration:float)->void:
	Engine.time_scale=0.05
	await get_tree().create_timer(duration,true,false,true).timeout
	Engine.time_scale=1.0
func setup_vignette()->void:
	var layer:=CanvasLayer.new()
	layer.layer=4
	add_child(layer)
	var grad:=Gradient.new()
	grad.set_color(0,Color(0,0,0,0))
	grad.set_color(1,Color(0,0,0,0.7))
	grad.add_point(0.55,Color(0,0,0,0))
	var tex:=GradientTexture2D.new()
	tex.gradient=grad
	tex.fill=GradientTexture2D.FILL_RADIAL
	tex.fill_from=Vector2(0.5,0.5)
	tex.fill_to=Vector2(0.5,1.25)
	tex.width=256
	tex.height=256
	var rect:=TextureRect.new()
	rect.texture=tex
	rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode=TextureRect.STRETCH_SCALE
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if POST_FX:
		setup_post_fx()
const POST_SHADER:="""
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.05;
uniform float bloom_amount = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 blur = textureLod(screen_tex, SCREEN_UV, 3.0).rgb * 0.6 + textureLod(screen_tex, SCREEN_UV, 5.0).rgb * 0.4;
	vec3 glow = max(blur - vec3(0.45), vec3(0.0)) * 1.8;
	vec3 col = base + glow * bloom_amount;
	float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(fract(TIME * 7.0) * 113.0));
	col += (n - 0.5) * grain_amount;
	COLOR = vec4(col, 1.0);
}
"""
func setup_post_fx()->void:
	var layer:=CanvasLayer.new()
	layer.layer=3
	add_child(layer)
	var shader:=Shader.new()
	shader.code=POST_SHADER
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	var rect:=ColorRect.new()
	rect.material=mat
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func make_light_texture()->GradientTexture2D:
	var grad:=Gradient.new()
	grad.set_color(0,Color(1,1,1,1))
	grad.set_color(1,Color(1,1,1,0))
	grad.add_point(0.35,Color(1,1,1,0.55))
	var tex:=GradientTexture2D.new()
	tex.gradient=grad
	tex.fill=GradientTexture2D.FILL_RADIAL
	tex.fill_from=Vector2(0.5,0.5)
	tex.fill_to=Vector2(1.0,0.5)
	tex.width=256
	tex.height=256
	return tex
func add_light(node:Node,size:float,energy:float)->PointLight2D:
	var l:=PointLight2D.new()
	l.texture=light_tex
	l.texture_scale=size
	l.energy=energy
	l.color=Color.WHITE
	node.add_child(l)
	return l
func setup_lighting()->void:
	var cm:=CanvasModulate.new()
	var v:float=DARKNESS[world]
	cm.color=Color(v,v,v)
	add_child(cm)
	add_light(player,2.4,0.85)
	for cp in checkpoints:
		var holder:=Node2D.new()
		holder.position=cp["pos"]+Vector2(0,-18)
		add_child(holder)
		cp["light"]=add_light(holder,1.2,0.25)
	var door:=Node2D.new()
	door.position=exit_pos+Vector2(0,-12)
	add_child(door)
	door_light=add_light(door,1.8,0.0)
func setup_foreground()->void:
	var px:=Parallax2D.new()
	px.scroll_scale=Vector2(1.3,1.0)
	px.repeat_size=Vector2(900,0)
	px.repeat_times=3
	px.z_index=15
	var art:=Node2D.new()
	art.position.y=bottom_shift()
	px.add_child(art)
	art.draw.connect(draw_foreground.bind(art,"bas"))
	add_child(px)
	var px_top:=Parallax2D.new()
	px_top.scroll_scale=Vector2(1.3,1.0)
	px_top.repeat_size=Vector2(900,0)
	px_top.repeat_times=3
	px_top.z_index=15
	var art_top:=Node2D.new()
	px_top.add_child(art_top)
	art_top.draw.connect(draw_foreground.bind(art_top,"haut"))
	add_child(px_top)
	var fog:=Parallax2D.new()
	fog.scroll_scale=Vector2(0.8,1.0)
	fog.repeat_size=Vector2(PARALLAX_W,0)
	fog.repeat_times=3
	fog.z_index=14
	fog_art=Node2D.new()
	fog_art.position.y=bottom_shift()
	fog.add_child(fog_art)
	fog_art.draw.connect(draw_fog)
	add_child(fog)
func draw_foreground(art:Node2D,part:String)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=77+world
	var ink:=Color(0,0,0,0.92)
	var x:=0.0 if part=="bas" else 900.0
	while x<900.0:
		match world:
			3:
				for i in 4:
					var bx:=x+i*6.0
					var h:=rng.randf_range(24,46)
					art.draw_line(Vector2(bx,400),Vector2(bx+rng.randf_range(-3,3),384-h),ink,2.0)
					if i%2==0:
						art.draw_rect(Rect2(bx-2.5,384-h-2,5,11),ink)
				x+=rng.randf_range(50,130)
			4:
				var r:=rng.randf_range(24,40)
				art.draw_circle(Vector2(x,392),r,Color(0.9,0.9,0.9,0.55))
				art.draw_circle(Vector2(x+r,398),r*0.8,Color(0.9,0.9,0.9,0.55))
				x+=rng.randf_range(90,200)
			1:
				var w:=rng.randf_range(30,70)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x,400),Vector2(x+w*0.3,372-rng.randf_range(0,20)),Vector2(x+w*0.7,368-rng.randf_range(0,24)),Vector2(x+w,400)]),ink)
				x+=w+rng.randf_range(60,160)
			2:
				var h:=rng.randf_range(16,30)
				art.draw_rect(Rect2(x,384-h,4,h+20),ink)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x-3,386-h),Vector2(x+2,376-h),Vector2(x+7,386-h)]),ink)
				x+=14.0
			_:
				for i in 5:
					var bx:=x+i*5.0
					var h:=rng.randf_range(10,34)
					art.draw_colored_polygon(PackedVector2Array([Vector2(bx,400),Vector2(bx+5,400),Vector2(bx+2.5+rng.randf_range(-6,6),384-h)]),ink)
				x+=rng.randf_range(40,140)
	x=rng.randf_range(0,60)if part=="haut" else 900.0
	while x<900.0:
		match world:
			4:
				x+=900.0
			3:
				var len_m:=rng.randf_range(20,60)
				for i in 4:
					var mx:=x+i*4.0
					art.draw_line(Vector2(mx,-4),Vector2(mx+sin(i*1.3)*3.0,len_m-i*6.0),ink,2.0)
				x+=rng.randf_range(60,150)
			1:
				var w:=rng.randf_range(16,40)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x-w*0.5,-10),Vector2(x+w*0.5,-10),Vector2(x,rng.randf_range(30,70))]),ink)
				x+=rng.randf_range(50,140)
			2:
				var len_c:=rng.randf_range(30,80)
				var y:=0.0
				while y<len_c:
					art.draw_arc(Vector2(x,y),3.5,0.0,TAU,8,ink,2.0)
					y+=7.0
				x+=rng.randf_range(120,260)
			_:
				var len_v:=rng.randf_range(20,70)
				var pts:=PackedVector2Array()
				for i in 8:
					var k:=i/7.0
					pts.append(Vector2(x+sin(k*5.0+x)*4.0,-4.0+k*len_v))
				art.draw_polyline(pts,ink,2.0)
				for i in 3:
					var leaf:=pts[2+i*2]
					art.draw_colored_polygon(PackedVector2Array([leaf,leaf+Vector2(5,2),leaf+Vector2(1,6)]),ink)
				x+=rng.randf_range(40,120)
func draw_fog()->void:
	var tt:=Time.get_ticks_msec()*0.001
	var strength:float=[0.05,0.035,0.05,0.09,0.07][world]
	for i in 14:
		var fx0:=fmod(i*97.0+tt*(6.0+(i%3)*3.0),PARALLAX_W)
		var fy:=300.0+(i%4)*14.0+sin(tt*0.5+i)*5.0
		fog_art.draw_set_transform(Vector2(fx0,fy),0.0,Vector2(3.0,0.6))
		fog_art.draw_circle(Vector2.ZERO,40.0+(i%3)*12.0,Color(1,1,1,strength))
	fog_art.draw_set_transform(Vector2.ZERO)
func setup_hud()->void:
	hud_layer=CanvasLayer.new()
	hud_layer.layer=5
	hud_layer.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_draw=Node2D.new()
	hud_layer.add_child(hud_draw)
	hud_draw.draw.connect(draw_hud)
	coin_label=MenuScript.make_label("0",18)
	hud_layer.add_child(coin_label)
	banner=MenuScript.make_label("",26)
	banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(banner)
	boss_label=MenuScript.make_label("",14)
	boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible=false
	hud_layer.add_child(boss_label)
	pause_button=MenuScript.make_button("II",18)
	pause_button.custom_minimum_size=Vector2(46,38)
	pause_button.pressed.connect(toggle_pause)
	hud_layer.add_child(pause_button)
	layout_hud()
	update_hud()
func layout_hud()->void:
	var s:=get_viewport().get_visible_rect().size
	coin_label.position=Vector2(36,33+heart_rows_offset())
	pause_button.position=Vector2(s.x-58,8)
	banner.position=Vector2(0,s.y*0.2)
	banner.size=Vector2(s.x,40)
	boss_label.position=Vector2(0,8)
	boss_label.size=Vector2(s.x,20)
func update_hud()->void:
	if hud_draw==null:
		return
	coin_label.text=str(level_coins)
	coin_label.position=Vector2(36,33+heart_rows_offset())
	hud_draw.queue_redraw()
func show_banner(text:String)->void:
	banner.text=text
	banner.modulate.a=0.0
	var tw:=banner.create_tween()
	tw.tween_property(banner,"modulate:a",1.0,0.4)
	tw.tween_interval(1.8)
	tw.tween_property(banner,"modulate:a",0.0,0.8)
func damage_number(pos:Vector2,amount:int)->void:
	var l:=MenuScript.make_label(str(amount),13,Color(1,0.85,0.35)if amount>=3 else Color.WHITE)
	l.position=pos+Vector2(randf_range(-14,4),-30)
	l.z_index=30
	add_child(l)
	var tw:=l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l,"position:y",l.position.y-18.0,0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l,"modulate:a",0.0,0.3).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)
func popup(text:String,pos:Vector2)->void:
	var l:=MenuScript.make_label(text,14)
	l.position=pos+Vector2(-40,-40)
	l.size=Vector2(80,20)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.z_index=30
	add_child(l)
	var tw:=l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l,"position:y",l.position.y-30.0,0.9)
	tw.tween_property(l,"modulate:a",0.0,0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
func _physics_process(delta:float)->void:
	if not in_level:
		return
	time+=delta
	for m in movers:
		var body:AnimatableBody2D=m["body"]
		var base:Vector2=m["base"]
		if m["vertical"]:
			body.position.y=base.y+sin(time*0.9+float(m["phase"]))*64.0
		else:
			body.position.x=base.x+sin(time*1.1+float(m["phase"]))*64.0
		body.queue_redraw()
	if finished:
		return
	if invincible>0.0:
		invincible-=delta
		player.modulate.a=0.35 if fmod(invincible,0.16)<0.08 else 1.0
		if invincible<=0.0:
			player.modulate.a=1.0
	check_checkpoints()
	check_enemies()
	check_projectiles()
	check_spikes()
	check_obstacles()
	if exit_open and player.global_position.distance_to(exit_pos)<22.0:
		level_complete()
	elif player.global_position.y>world_bottom()+48.0:
		fell_in_pit()
func check_checkpoints()->void:
	for cp in checkpoints:
		if not cp["on"]and player.global_position.distance_to(cp["pos"])<30.0:
			cp["on"]=true
			respawn_point=cp["pos"]
			popup("POINT DE PASSAGE",cp["pos"])
			sound("point")
			fx.ring(cp["pos"]+Vector2(0,-14),10.0,Color.WHITE,0.5)
			fx.burst(cp["pos"]+Vector2(0,-14),12,80.0,Color.WHITE,0.6,2.0,0.0,30.0)
func stomp_damage()->int:
	return 3 if GameData.character=="roc" else 2
func check_enemies()->void:
	var pr:Rect2=player.get_hit_rect()
	for e in group("ennemis"):
		if e.dead:
			continue
		var er:Rect2=e.get_hit_rect()
		if not pr.intersects(er):
			continue
		if player.velocity.y>30.0 and pr.end.y<er.position.y+14.0 and e.stompable:
			player.bounce()
			e.take_damage(stomp_damage(),player.global_position.x)
			fx.ring(Vector2(player.global_position.x,pr.end.y),12.0,Color.WHITE,0.3)
		elif not player.is_invulnerable():
			hurt_player(1,er.get_center().x)
	if boss_alive()and boss.is_harmful():
		var br:Rect2=boss.get_hit_rect()
		if pr.intersects(br):
			if player.velocity.y>30.0 and pr.end.y<br.position.y+16.0:
				player.bounce()
				boss.take_damage(1,player.global_position.x)
			elif not player.is_invulnerable():
				hurt_player(1,br.get_center().x)
		for extra in boss.get_extra_rects():
			if pr.intersects(extra)and not player.is_invulnerable():
				hurt_player(1,boss.position.x)
func check_projectiles()->void:
	var pr:Rect2=player.get_hit_rect()
	for p in group("proj_ennemi"):
		if p.is_queued_for_deletion():
			continue
		if pr.intersects(p.get_hit_rect())and not player.is_invulnerable():
			if hurt_player(p.damage,p.position.x):
				p.explode()
	var foes:=group("ennemis")
	for p in group("proj_joueur"):
		if p.is_queued_for_deletion():
			continue
		var hr:Rect2=p.get_hit_rect()
		var hit:=false
		for e in foes:
			if not e.dead and hr.intersects(e.get_hit_rect()):
				if p.kind=="carreau":
					if not p.hits.has(e):
						p.hits.append(e)
						e.take_damage(p.damage,p.position.x)
						fx.burst(e.position,6,90.0,Color.WHITE,0.25,2.0)
					continue
				e.take_damage(p.damage,p.position.x)
				hit=true
				break
		if not hit and boss_alive()and boss.can_be_hit()and hr.intersects(boss.get_hit_rect()):
			boss.take_damage(p.damage,p.position.x)
			hit=true
		if hit:
			p.explode()
func check_obstacles()->void:
	if finished or player.dead:
		return
	var pr:Rect2=player.get_hit_rect()
	for o in group("obstacles"):
		o.interact(player)
		if o.hits_player(pr):
			if o.kind=="acide":
				fx.burst(player.global_position+Vector2(0,12),16,120.0,Color.WHITE,0.5,3.0,300.0,100.0)
				fell_in_pit()
				return
			if not player.is_invulnerable():
				hurt_player(1,o.global_position.x)
func check_spikes()->void:
	if player.is_invulnerable()or invincible>0.0:
		return
	var pr:Rect2=player.get_hit_rect()
	var c0:=int(floor(pr.position.x/TILE))
	var c1:=int(floor(pr.end.x/TILE))
	var r0:=int(floor(pr.position.y/TILE))
	var r1:=int(floor(pr.end.y/TILE))
	for r in range(r0,r1+1):
		if r<0 or r>=rows:
			continue
		for c in range(c0,c1+1):
			var ch:=cell(c,r)
			var danger:=Rect2()
			if ch=="^":
				danger=Rect2(c*TILE+4,r*TILE+18,24,14)
			elif ch=="v":
				danger=Rect2(c*TILE+4,r*TILE,24,14)
			else:
				continue
			if pr.intersects(danger):
				hurt_player(1,c*TILE+16.0)
				return
func hurt_player(amount:int,from_x:float)->bool:
	if invincible>0.0 or finished or player.dead:
		return false
	hearts-=amount
	sound("blesse")
	shake(7.0)
	fx.burst(player.global_position,14,150.0,Color.WHITE,0.4,2.5)
	freeze(0.07)
	update_hud()
	if hearts<=0:
		hearts=0
		update_hud()
		player_died()
		return true
	player.take_hit(from_x)
	invincible=INVINCIBLE_TIME
	return true
func fell_in_pit()->void:
	if player.dead:
		return
	hearts-=1
	update_hud()
	if hearts<=0:
		hearts=0
		player_died()
		return
	for p in group("proj_ennemi"):
		p.queue_free()
	player.global_position=respawn_point
	player.velocity=Vector2.ZERO
	camera.reset_smoothing()
	invincible=INVINCIBLE_TIME
	shake(4.0)
func _on_player_melee(hit_rect:Rect2,damage:int)->void:
	var hit_any:=false
	for e in group("ennemis"):
		if not e.dead and hit_rect.intersects(e.get_hit_rect()):
			e.take_damage(damage,player.global_position.x)
			hit_any=true
	if boss_alive()and hit_rect.intersects(boss.get_hit_rect()):
		if boss.take_damage(damage,player.global_position.x)or boss.can_be_hit():
			hit_any=true
	for p in group("proj_ennemi"):
		if hit_rect.intersects(p.get_hit_rect()):
			p.explode()
			hit_any=true
	var c0:=int(floor(hit_rect.position.x/TILE))
	var c1:=int(floor(hit_rect.end.x/TILE))
	var r0:=int(floor(hit_rect.position.y/TILE))
	var r1:=int(floor(hit_rect.end.y/TILE))
	for r in range(r0,r1+1):
		for c in range(c0,c1+1):
			if crates.has(Vector2i(c,r)):
				break_crate(c,r)
				hit_any=true
	if hit_any:
		shake(3.0)
		freeze(0.04)
func _on_player_fire(from_pos:Vector2,dir_x:float)->void:
	sound("feu")
	var angles:=[0.0]
	if GameData.get_level("feu")>=3:
		angles=[-0.22,0.0,0.22]
	for a in angles:
		spawn_projectile(from_pos,Vector2(dir_x*300.0,0).rotated(a*dir_x),"joueur","feu",1)
	fx.burst(from_pos,6,70.0,Color.WHITE,0.25,2.0)
func on_projectile_wall(p)->void:
	if p.team!="joueur":
		return
	var c:=int(floor(p.position.x/TILE))
	var r:=int(floor(p.position.y/TILE))
	if crates.has(Vector2i(c,r)):
		break_crate(c,r)
func break_crate(c:int,r:int)->void:
	var key:=Vector2i(c,r)
	if not crates.has(key):
		return
	crates[key].queue_free()
	crates.erase(key)
	var kind:=cell(c,r)
	set_cell(c,r,".")
	var center:=Vector2(c*TILE+16,r*TILE+16)
	fx.burst(center,16,160.0,Color.WHITE,0.7,3.5,600.0,120.0)
	sound("caisse")
	var n:=3
	if kind=="D":
		n=1
		shake(4.0)
	elif kind=="c":
		n=10
		sound("tresor")
		popup("TRÉSOR !",center)
		fx.burst(center,20,120.0,Color(1,0.85,0.3),0.8,2.5,0.0,60.0)
	for i in n:
		spawn_pickup("piece",center,true)
	redraw_tiles()
func on_enemy_killed(e)->void:
	sound("tue")
	fx.burst(e.position,18,160.0,Color.WHITE,0.5,3.0)
	fx.ring(e.position,10.0,Color.WHITE,0.35)
	for i in e.coins:
		spawn_pickup("piece",e.position,true)
	shake(3.0)
	freeze(0.05)
func on_boss_defeated(b)->void:
	exit_open=true
	boss_label.visible=false
	popup("VICTOIRE !",b.position)
	sound("explosion",0.0)
	for i in 15:
		spawn_pickup("piece",b.position,true)
	spawn_pickup("coeur",b.position,true)
	if not GameData.containers.has(GameData.current_level):
		spawn_pickup("receptacle",b.position+Vector2(0,-10),true)
	shake(12.0)
	var tw:=create_tween()
	tw.tween_property(self,"exit_alpha",1.0,1.0)
func collect(p)->void:
	match p.kind:
		"piece":
			level_coins+=1
			fx.burst(p.position,5,60.0,Color(1,0.85,0.35),0.3,2.0)
			sound("piece",0.03)
		"tresor":
			level_coins+=10
			popup("+10",p.position)
			fx.burst(p.position,16,100.0,Color(1,0.85,0.35),0.6,2.5)
			sound("tresor")
		"coeur":
			hearts=mini(max_hearts,hearts+1)
			sound("coeur")
			popup("+1 COEUR",p.position)
			fx.ring(p.position,10.0,Color.WHITE,0.4)
		"eclat":
			if p.shard_id>=0 and p.shard_id<3:
				shards_found[p.shard_id]=true
			popup("ÉCLAT DE LUNE !",p.position)
			sound("eclat")
			fx.ring(p.position,14.0,Color.WHITE,0.6)
			fx.burst(p.position,20,120.0,Color.WHITE,0.8,2.5)
			freeze(0.06)
		"receptacle":
			GameData.containers[GameData.current_level]=true
			GameData.save_game()
			max_hearts+=1
			hearts=max_hearts
			popup("+1 COEUR MAXIMUM !",p.position)
			sound("eclat")
			fx.ring(p.position,20.0,Color.WHITE,0.8)
			fx.burst(p.position,30,160.0,Color.WHITE,0.9,3.0)
			freeze(0.1)
	update_hud()
func level_complete()->void:
	sound("porte",0.0)
	sfx.stop_music()
	finished=true
	player.can_control=false
	player.velocity=Vector2.ZERO
	touch.release_all()
	touch.visible=false
	var idx:=GameData.current_level
	var bonus:=hearts*5
	var found:int=shards_found.count(true)
	var is_boss:bool=level_data["boss"]!=""
	if is_boss:
		found=1
	GameData.coins+=level_coins+bonus
	GameData.shards[idx]=maxi(int(GameData.shards.get(idx,0)),found)
	GameData.unlocked=maxi(GameData.unlocked,mini(idx+1,Levels.all().size()-1))
	GameData.save_game()
	fx.burst(exit_pos,30,150.0,Color.WHITE,0.8,3.0,0.0,40.0)
	var tw:Tween=player.create_tween()
	tw.tween_property(player,"modulate:a",0.0,0.5)
	var text:="Pièces : %d  (+%d bonus de coeurs)"%[level_coins,bonus]
	if not is_boss:
		text+="\nÉclats de lune : %d / 3"%found
	var buttons:=[]
	var title:="NIVEAU TERMINÉ !"
	if idx+1<Levels.all().size():
		buttons.append(["SUIVANT",next_level])
	else:
		title="LE ROI OMBRE EST VAINCU !"
		text+="\nMerci d'avoir joué !"
	buttons.append(["MAGASIN",go_shop])
	buttons.append(["CARTE",go_map])
	await get_tree().create_timer(0.9).timeout
	show_panel(title,text,buttons)
func player_died()->void:
	sound("mort",0.0)
	sfx.stop_music()
	finished=true
	player.die()
	touch.release_all()
	touch.visible=false
	var kept:=int(level_coins*0.5)
	GameData.coins+=kept
	GameData.save_game()
	shake(10.0)
	await get_tree().create_timer(1.3).timeout
	show_panel("VAINCU...","Tu gardes la moitié des pièces : %d"%kept,
		[["RÉESSAYER",restart],["MAGASIN",go_shop],["CARTE",go_map]])
func toggle_pause()->void:
	if finished:
		return
	if get_tree().paused:
		resume()
		return
	get_tree().paused=true
	touch.release_all()
	show_panel("PAUSE",level_data["nom"],[["REPRENDRE",resume],["RECOMMENCER",restart],["CARTE",go_map],[sound_label(),toggle_sound]])
func sound_label()->String:
	return "SON : OUI" if GameData.sfx_on else "SON : NON"
func toggle_sound()->void:
	GameData.sfx_on=not GameData.sfx_on
	GameData.music_on=GameData.sfx_on
	GameData.save_game()
	if GameData.music_on:
		sfx.play_music(world,level_data["boss"]!="")
	else:
		sfx.stop_music()
	toggle_pause()
	toggle_pause()
func resume()->void:
	get_tree().paused=false
	touch.release_all()
	if panel:
		panel.queue_free()
		panel=null
func restart()->void:
	GameData.screen="niveau"
	fade_and_reload()
func next_level()->void:
	GameData.current_level+=1
	restart()
func go_map()->void:
	GameData.screen="carte"
	fade_and_reload()
func go_shop()->void:
	GameData.screen="magasin"
	fade_and_reload()
func show_panel(title:String,text:String,buttons:Array)->void:
	if panel:
		panel.queue_free()
	var cc:=CenterContainer.new()
	hud_layer.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p:=MenuScript.make_panel()
	cc.add_child(p)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	p.add_child(box)
	var t:=MenuScript.make_label(title,28)
	t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var l:=MenuScript.make_label(text,16,Color(0.85,0.85,0.85))
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",10)
	box.add_child(row)
	for b in buttons:
		var btn:=MenuScript.make_button(b[0],18)
		btn.custom_minimum_size=Vector2(120,44)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	cc.modulate.a=0.0
	var tw:=cc.create_tween()
	tw.tween_property(cc,"modulate:a",1.0,0.25)
	panel=cc
func _process(delta:float)->void:
	if camera:
		if in_level:
			var target_look:=0.0
			if not player.dead and not finished:
				target_look=player.facing*36.0
			look=lerpf(look,target_look,minf(1.0,3.0*delta))
		else:
			camera.position.x+=25.0*delta
		camera.offset=Vector2(look,0)+Vector2(randf_range(-1,1),randf_range(-1,1))*shake_amount
		shake_amount=move_toward(shake_amount,0.0,30.0*delta)
		ambient(delta)
	if deco:
		deco.queue_redraw()
	if fog_art:
		fog_art.queue_redraw()
	if water_layer:
		water_layer.queue_redraw()
	var tt:=Time.get_ticks_msec()*0.001
	for cp in checkpoints:
		if cp.has("light"):
			var l:PointLight2D=cp["light"]
			l.enabled=cp["on"]
			l.energy=1.0+0.15*sin(tt*13.0+l.global_position.x)
	if door_light:
		door_light.enabled=exit_alpha>0.0
		door_light.energy=exit_alpha*(1.1+0.2*sin(tt*3.0))
	if world==2:
		update_weather(delta)
	if boss!=null:
		if not is_instance_valid(boss):
			boss=null
			boss_label.visible=false
		else:
			boss_label.visible=not boss.dead
			boss_label.text=boss.display_name
		if hud_draw:
			hud_draw.queue_redraw()
func ambient(delta:float)->void:
	ambient_timer-=delta
	if ambient_timer>0.0:
		return
	ambient_timer=0.12
	var center:=camera.get_screen_center_position()
	var half:=get_viewport().get_visible_rect().size/camera.zoom*0.5
	var p:=center+Vector2(randf_range(-half.x,half.x),randf_range(-half.y,half.y))
	match world:
		0:
			fx.spawn(p,Vector2(randf_range(-12,12),randf_range(-14,-4)),Color(1,1,1,0.9),2.5,2.0)
		1:
			fx.spawn(Vector2(p.x,center.y-half.y),Vector2(0,20),Color(0.85,0.85,0.85,0.8),1.6,2.0,450.0)
		2:
			fx.spawn(Vector2(p.x,center.y-half.y),Vector2(randf_range(-25,-5),35),Color(0.7,0.7,0.7,0.6),5.0,2.0)
		3:
			fx.spawn(p,Vector2(randf_range(-8,8),randf_range(-10,-2)),Color(1,1,1,0.9),3.0,2.0)
		4:
			fx.streak(Vector2(center.x+half.x,p.y),Vector2(-randf_range(260,420),0),Color(1,1,1,0.35),1.6)
func setup_rain()->void:
	var layer:=CanvasLayer.new()
	layer.layer=1
	add_child(layer)
	weather=Node2D.new()
	layer.add_child(weather)
	weather.draw.connect(draw_weather)
	var s:=get_viewport().get_visible_rect().size
	for i in 70:
		rain.append(Vector2(randf()*s.x,randf()*s.y))
func update_weather(delta:float)->void:
	next_lightning-=delta
	if next_lightning<=0.0:
		next_lightning=randf_range(6.0,12.0)
		flash_alpha=0.7
		shake(2.0)
	flash_alpha=move_toward(flash_alpha,0.0,delta*2.5)
	if weather:
		var s:=get_viewport().get_visible_rect().size
		for i in rain.size():
			var d:Vector2=rain[i]
			d+=Vector2(-120.0,520.0)*delta
			if d.y>s.y:
				d=Vector2(randf()*(s.x+100.0),-10.0)
			rain[i]=d
		weather.queue_redraw()
	if sky:
		sky.queue_redraw()
func draw_weather()->void:
	for d in rain:
		weather.draw_line(d,d+Vector2(-3,11),Color(0.85,0.85,0.85,0.35),1.0)
	if flash_alpha>0.0:
		var s:=get_viewport().get_visible_rect().size
		weather.draw_rect(Rect2(Vector2.ZERO,s),Color(1,1,1,flash_alpha*0.25))
func draw_hud()->void:
	var s:=get_viewport().get_visible_rect().size
	for i in max_hearts:
		draw_heart(Vector2(14+(i%8)*24,10+floori(i/8.0)*22),i<hearts)
	var coin_y:=46.0+heart_rows_offset()
	hud_draw.draw_circle(Vector2(22,coin_y),8.0,Color.BLACK)
	hud_draw.draw_circle(Vector2(22,coin_y),6.5,Color.WHITE)
	hud_draw.draw_arc(Vector2(22,coin_y),3.5,0.0,TAU,12,Color(0.35,0.35,0.35),1.5)
	if level_data.get("boss","")=="":
		for i in 3:
			var c:=Vector2(s.x-80-i*22,27)
			if shards_found[2-i]:
				hud_draw.draw_circle(c,7.0,Color.WHITE)
				hud_draw.draw_circle(c+Vector2(3.5,-2.5),6.0,Color.BLACK)
			else:
				hud_draw.draw_arc(c,7.0,0.0,TAU,16,Color(0.45,0.45,0.45),1.5)
	if boss!=null and is_instance_valid(boss)and not boss.dead:
		var w:=s.x*0.42
		var x:=(s.x-w)*0.5
		var y:=30.0
		hud_draw.draw_rect(Rect2(x-2,y-2,w+4,14),Color.BLACK)
		hud_draw.draw_rect(Rect2(x,y,w*float(boss.hp)/float(boss.max_hp),10),Color.WHITE)
		hud_draw.draw_rect(Rect2(x-2,y-2,w+4,14),Color.WHITE,false,1.5)
func heart_rows_offset()->float:
	return(ceili(max_hearts/8.0)-1)*22.0
func draw_heart(pos:Vector2,full:bool)->void:
	for y in 6:
		var line:String=HEART[y]
		for x in 7:
			if line[x]=="#":
				hud_draw.draw_rect(Rect2(pos+Vector2(x,y)*3.0-Vector2(1,1),Vector2(5,5)),Color.BLACK)
	for y in 6:
		var line:String=HEART[y]
		for x in 7:
			if line[x]=="#":
				var col:=HEART_RED if full else Color(0.28,0.28,0.28)
				if full and y==1 and(x==1 or x==2):
					col=Color(1,0.6,0.62)
				hud_draw.draw_rect(Rect2(pos+Vector2(x,y)*3.0,Vector2(3,3)),col)
func setup_background()->void:
	var sky_layer:=CanvasLayer.new()
	sky_layer.layer=-10
	add_child(sky_layer)
	sky=Node2D.new()
	sky_layer.add_child(sky)
	sky.draw.connect(draw_sky)
	match world:
		1:
			add_parallax(0.2,draw_cave_far)
			add_parallax(0.45,draw_cave_near)
		2:
			add_parallax(0.12,draw_castle_far)
			add_parallax(0.4,draw_graveyard)
		3:
			add_parallax(0.15,draw_swamp_far)
			add_parallax(0.4,draw_swamp_near)
		4:
			add_parallax(0.08,draw_sky_islands)
			add_parallax(0.3,draw_cloud_bank.bind(0.3,300.0,3))
			add_parallax(0.55,draw_cloud_bank.bind(0.5,345.0,9))
		_:
			add_parallax(0.15,draw_far_hills)
			add_parallax(0.4,draw_near_forest)
func bottom_shift()->float:
	return float(maxi(0,rows-12)*TILE)if in_level else 0.0
func add_parallax(scroll:float,fn:Callable)->void:
	var px:=Parallax2D.new()
	px.scroll_scale=Vector2(scroll,1.0)
	px.repeat_size=Vector2(PARALLAX_W,0)
	px.repeat_times=3
	px.z_index=-5
	var art:=Node2D.new()
	art.position.y=bottom_shift()
	px.add_child(art)
	art.draw.connect(fn.bind(art))
	add_child(px)
func draw_sky()->void:
	var s:=get_viewport().get_visible_rect().size
	var top:=0.02
	var bottom:=0.3
	if world==1:
		top=0.0
		bottom=0.08
	elif world==2:
		top=0.03
		bottom=0.22
	elif world==3:
		top=0.03
		bottom=0.2
	elif world==4:
		top=0.1
		bottom=0.5
	var bands:=32
	for i in bands:
		var k:=float(i)/(bands-1)
		var g:=lerpf(top,bottom,k*k)
		sky.draw_rect(Rect2(0,s.y*i/bands,s.x,s.y/bands+1.0),Color(g,g,g))
	var rng:=RandomNumberGenerator.new()
	rng.seed=7
	if world==1:
		for i in 25:
			var p:=Vector2(rng.randf()*s.x,rng.randf()*s.y)
			var a:=0.15+0.15*sin(Time.get_ticks_msec()*0.002+i)
			sky.draw_rect(Rect2(p,Vector2(2,2)),Color(1,1,1,a))
		return
	var tw:=Time.get_ticks_msec()*0.001
	for i in(140 if world==4 else 70):
		var p:=Vector2(rng.randf()*s.x,rng.randf()*s.y*0.6)
		var twinkle:=0.5+0.5*sin(tw*rng.randf_range(1.0,3.0)+i)
		sky.draw_rect(Rect2(p,Vector2(1.5,1.5)),Color(1,1,1,rng.randf_range(0.2,0.8)*(0.6+0.4*twinkle)))
	if world==4:
		var sf:=fmod(tw,7.0)
		if sf<0.6:
			var start:=Vector2(s.x*(0.2+fmod(floor(tw/7.0)*0.37,0.6)),s.y*0.1)
			var head:=start+Vector2(sf*300.0,sf*120.0)
			sky.draw_line(head-Vector2(40,16),head,Color(1,1,1,0.7*(1.0-sf/0.6)),1.5)
	var moon_x:float=[0.78,0.25,0.25,0.7,0.6][world]
	var moon_r:float=[0.08,0.13,0.13,0.07,0.18][world]
	var m:=Vector2(s.x*moon_x,s.y*(0.2 if world!=4 else 0.28))
	var r:=s.y*moon_r
	var sway:=sin(Time.get_ticks_msec()*0.0003)*0.05
	for k in 6:
		var a:=1.75+(k-2.5)*0.22+sway
		var d1:=Vector2(cos(a-0.04),sin(a-0.04))*s.y*1.6
		var d2:=Vector2(cos(a+0.04),sin(a+0.04))*s.y*1.6
		sky.draw_colored_polygon(PackedVector2Array([m,m+d1,m+d2]),Color(1,1,1,0.025))
	for k in 5:
		sky.draw_circle(m,r*(1.3+k*0.45),Color(1,1,1,0.035))
	sky.draw_circle(m,r,Color(0.95,0.95,0.95))
	sky.draw_circle(m+Vector2(-r*0.3,-r*0.2),r*0.22,Color(0.8,0.8,0.8))
	sky.draw_circle(m+Vector2(r*0.35,r*0.25),r*0.15,Color(0.82,0.82,0.82))
	sky.draw_circle(m+Vector2(-r*0.1,r*0.5),r*0.1,Color(0.84,0.84,0.84))
	if world==3:
		for i in 5:
			sky.draw_rect(Rect2(0,s.y*(0.15+i*0.07),s.x,s.y*0.05),Color(0.2,0.2,0.2,0.25))
	if world==2:
		var tt:=Time.get_ticks_msec()*0.001
		for i in 6:
			var cx:=fmod(i*170.0+tt*(8.0+i*2.0),s.x+300.0)-150.0
			var cy:=s.y*(0.12+0.07*(i%3))
			for k in 4:
				sky.draw_circle(Vector2(cx+k*26.0,cy+sin(k*1.7)*6.0),22.0+(k%2)*8.0,Color(0.08,0.08,0.08,0.85))
		if flash_alpha>0.0:
			sky.draw_rect(Rect2(Vector2.ZERO,s),Color(1,1,1,flash_alpha*0.5))
func hill_y(x:float,base_y:float,amp:float,seed_value:float)->float:
	var t:=x/PARALLAX_W*TAU
	return base_y-amp*(0.6*sin(t*2.0+seed_value)+0.4*sin(t*5.0+seed_value*2.0))
func draw_hill_band(art:Node2D,base_y:float,amp:float,seed_value:float,color:Color,rim:Color)->void:
	var pts:=PackedVector2Array()
	var top:=PackedVector2Array()
	for i in 81:
		var x:=PARALLAX_W*i/80.0
		var p:=Vector2(x,hill_y(x,base_y,amp,seed_value))
		pts.append(p)
		top.append(p)
	pts.append(Vector2(PARALLAX_W,520))
	pts.append(Vector2(0,520))
	art.draw_colored_polygon(pts,color)
	art.draw_polyline(top,rim,1.5)
func draw_far_hills(art:Node2D)->void:
	draw_hill_band(art,270.0,50.0,1.0,Color(0.15,0.15,0.15),Color(0.3,0.3,0.3))
func draw_near_forest(art:Node2D)->void:
	draw_hill_band(art,315.0,26.0,4.0,Color(0.08,0.08,0.08),Color(0.2,0.2,0.2))
	var rng:=RandomNumberGenerator.new()
	rng.seed=11
	for k in 8:
		var tx:=70.0+k*150.0
		draw_dead_tree(art,Vector2(tx,hill_y(tx,315.0,26.0,4.0)+4.0),rng.randf_range(60,110),Color(0.03,0.03,0.03),rng)
	art.draw_rect(Rect2(0,300,PARALLAX_W,30),Color(1,1,1,0.03))
	art.draw_rect(Rect2(0,312,PARALLAX_W,30),Color(1,1,1,0.03))
func draw_swamp_far(art:Node2D)->void:
	draw_hill_band(art,300.0,18.0,3.0,Color(0.11,0.11,0.11),Color(0.22,0.22,0.22))
	var rng:=RandomNumberGenerator.new()
	rng.seed=31
	var col:=Color(0.1,0.1,0.1)
	for k in 7:
		var x:=60.0+k*170.0+rng.randf_range(-20,20)
		var y:=hill_y(x,300.0,18.0,3.0)
		var h:=rng.randf_range(90,140)
		art.draw_line(Vector2(x,y),Vector2(x+4,y-h),col,6.0)
		art.draw_circle(Vector2(x+4,y-h),34.0,col)
		art.draw_circle(Vector2(x-20,y-h+14),24.0,col)
		art.draw_circle(Vector2(x+26,y-h+12),26.0,col)
		for i in 9:
			var mx:=x-40.0+i*10.0
			art.draw_line(Vector2(mx,y-h+10),Vector2(mx+sin(i)*3.0,y-h+40+rng.randf_range(0,40)),col,2.0)
func draw_swamp_near(art:Node2D)->void:
	art.draw_rect(Rect2(0,318,PARALLAX_W,200),Color(0.05,0.05,0.05))
	for i in 40:
		var x:=fmod(i*61.0,PARALLAX_W)
		art.draw_line(Vector2(x,322+(i%5)*6.0),Vector2(x+18+(i%3)*8.0,322+(i%5)*6.0),Color(1,1,1,0.08),1.0)
	var rng:=RandomNumberGenerator.new()
	rng.seed=41
	var col:=Color(0.04,0.04,0.04)
	for k in 30:
		var x:=rng.randf()*PARALLAX_W
		var h:=rng.randf_range(20,50)
		art.draw_line(Vector2(x,322),Vector2(x+rng.randf_range(-4,4),322-h),col,2.0)
		if k%3==0:
			art.draw_rect(Rect2(x-2,322-h-8,4,10),col)
	for k in 4:
		draw_dead_tree(art,Vector2(150.0+k*300.0,322),rng.randf_range(70,110),col,rng)
func draw_sky_islands(art:Node2D)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=51
	for k in 5:
		var x:=80.0+k*240.0+rng.randf_range(-30,30)
		var y:=rng.randf_range(120,220)
		var w:=rng.randf_range(60,110)
		var col:=Color(0.25,0.25,0.25)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x-w,y),Vector2(x+w,y),Vector2(x+w*0.4,y+w*0.5),Vector2(x,y+w*0.9),Vector2(x-w*0.5,y+w*0.45)]),col)
		art.draw_line(Vector2(x-w,y),Vector2(x+w,y),Color(0.5,0.5,0.5),2.0)
		if k%2==0:
			art.draw_rect(Rect2(x-10,y-40,20,40),col)
			art.draw_colored_polygon(PackedVector2Array([Vector2(x-14,y-40),Vector2(x,y-62),Vector2(x+14,y-40)]),col)
			art.draw_rect(Rect2(x-3,y-30,6,8),Color(0.7,0.7,0.7))
func draw_cloud_bank(art:Node2D,alpha:float,base_y:float,seed_value:int)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var x:=0.0
	while x<PARALLAX_W:
		var r:=rng.randf_range(30,60)
		art.draw_circle(Vector2(x,base_y+rng.randf_range(-12,12)),r,Color(0.85,0.85,0.85,alpha*0.5))
		art.draw_circle(Vector2(x,base_y+30),r*1.2,Color(0.85,0.85,0.85,alpha*0.6))
		x+=r*1.1
	art.draw_rect(Rect2(0,base_y+30,PARALLAX_W,200),Color(0.85,0.85,0.85,alpha*0.6))
func draw_cave_far(art:Node2D)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=3
	var col:=Color(0.09,0.09,0.09)
	for k in 12:
		var x:=k*100.0+rng.randf_range(-20,20)
		var w:=rng.randf_range(30,70)
		var h:=rng.randf_range(60,150)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x-w,0),Vector2(x+w,0),Vector2(x+rng.randf_range(-8,8),h)]),col)
		var h2:=rng.randf_range(60,160)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x+40-w,400),Vector2(x+40+w,400),Vector2(x+40,400-h2)]),col)
	for i in 20:
		var p:=Vector2(rng.randf()*PARALLAX_W,rng.randf_range(120,300))
		art.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-5),p+Vector2(3,0),p+Vector2(0,5),p+Vector2(-3,0)]),Color(1,1,1,0.25))
func draw_cave_near(art:Node2D)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=9
	var col:=Color(0.045,0.045,0.045)
	for k in 5:
		var x:=k*240.0+60.0
		var w:=rng.randf_range(26,44)
		var pts:=PackedVector2Array()
		for i in 9:
			var y:=i*50.0
			pts.append(Vector2(x-w+sin(i*1.3+k)*8.0,y))
		for i in range(8,-1,-1):
			var y:=i*50.0
			pts.append(Vector2(x+w+cos(i*1.1+k)*8.0,y))
		art.draw_colored_polygon(pts,col)
func draw_castle_far(art:Node2D)->void:
	var col:=Color(0.13,0.13,0.13)
	var rng:=RandomNumberGenerator.new()
	rng.seed=21
	art.draw_rect(Rect2(0,260,PARALLAX_W,260),col)
	for k in 7:
		var x:=40.0+k*170.0
		var w:=rng.randf_range(40,70)
		var h:=rng.randf_range(90,170)
		var top:=260.0-h
		art.draw_rect(Rect2(x,top,w,h+10),col)
		if k%2==0:
			for i in int(w/12.0):
				art.draw_rect(Rect2(x+i*12.0,top-8,7,8),col)
		else:
			art.draw_colored_polygon(PackedVector2Array([Vector2(x-6,top),Vector2(x+w*0.5,top-50),Vector2(x+w+6,top)]),col)
		for i in 3:
			if rng.randf()<0.6:
				art.draw_rect(Rect2(x+w*0.5-3,top+20+i*30,6,10),Color(0.75,0.75,0.75))
	for i in 12:
		var x:=rng.randf()*PARALLAX_W
		art.draw_rect(Rect2(x,240,6,20),col)
func draw_graveyard(art:Node2D)->void:
	draw_hill_band(art,330.0,14.0,2.0,Color(0.06,0.06,0.06),Color(0.18,0.18,0.18))
	var rng:=RandomNumberGenerator.new()
	rng.seed=5
	var col:=Color(0.06,0.06,0.06)
	for k in 16:
		var x:=30.0+k*75.0+rng.randf_range(-10,10)
		var y:=hill_y(x,330.0,14.0,2.0)
		if k%3==0:
			art.draw_rect(Rect2(x-2,y-30,4,30),col)
			art.draw_rect(Rect2(x-10,y-22,20,4),col)
		else:
			art.draw_rect(Rect2(x-8,y-18,16,18),col)
			art.draw_circle(Vector2(x,y-18),8.0,col)
	for i in 60:
		var x:=i*20.0
		art.draw_line(Vector2(x,300),Vector2(x,345),Color(0.1,0.1,0.1),2.0)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x-3,302),Vector2(x,294),Vector2(x+3,302)]),Color(0.1,0.1,0.1))
	art.draw_line(Vector2(0,308),Vector2(PARALLAX_W,308),Color(0.1,0.1,0.1),2.0)
func draw_dead_tree(canvas:CanvasItem,base:Vector2,height:float,color:Color,rng:RandomNumberGenerator)->void:
	var top:=base+Vector2(rng.randf_range(-6,6),-height)
	var width:=maxf(2.0,height*0.06)
	canvas.draw_line(base,top,color,width)
	draw_branch(canvas,top,-PI/2.0,height*0.3,width*0.7,2,color,rng)
	for k in 3:
		var p:=base.lerp(top,0.4+k*0.18)
		var side:=1.0 if k%2==0 else-1.0
		draw_branch(canvas,p,-PI/2.0+side*rng.randf_range(0.6,1.1),height*0.35,width*0.7,2,color,rng)
func draw_branch(canvas:CanvasItem,start:Vector2,angle:float,length:float,width:float,depth:int,color:Color,rng:RandomNumberGenerator)->void:
	var to:=start+Vector2(cos(angle),sin(angle))*length
	canvas.draw_line(start,to,color,width)
	if depth<=0:
		return
	for k in 2:
		var side:=1.0 if k==0 else-1.0
		draw_branch(canvas,to,angle+side*rng.randf_range(0.3,0.7),length*0.6,maxf(1.0,width*0.6),depth-1,color,rng)
func build_tile_chunks()->void:
	var c0:=0
	while c0<cols:
		var chunk:=Node2D.new()
		add_child(chunk)
		move_child(chunk,0)
		chunk.draw.connect(draw_chunk.bind(chunk,c0,mini(c0+16,cols)))
		tile_chunks.append(chunk)
		c0+=16
func redraw_tiles()->void:
	for chunk in tile_chunks:
		chunk.queue_redraw()
func draw_chunk(chunk:Node2D,c0:int,c1:int)->void:
	canvas=chunk
	var rng:=RandomNumberGenerator.new()
	for r in rows:
		var line:String=grid[r]
		for c in range(c0,c1):
			var ch:=line[c]
			rng.seed=tile_hash(c,r)
			match ch:
				"#":
					draw_tile(c,r,rng)
				"=":
					draw_platform(c,r,rng)
				"B":
					draw_crate(c,r)
				"D":
					draw_cracked(c,r)
				"c":
					draw_chest(c,r)
				"/","\\":
					draw_slope(c,r,ch,rng)
				"^":
					draw_spikes(c,r,false)
				"v":
					draw_spikes(c,r,true)
func draw_water()->void:
	var tt:=Time.get_ticks_msec()*0.001
	for cv in water_cells:
		var x:=float(cv.x*TILE)
		var y:=float(cv.y*TILE)
		var surface:=cell(cv.x,cv.y-1)!="~"
		var top:=y
		if surface:
			top=y+6.0+sin(tt*2.5+x*0.05)*2.0
		water_layer.draw_rect(Rect2(x,top,TILE,y+TILE-top),Color(0.55,0.62,0.7,0.35))
		if surface:
			var a:=Vector2(x,y+6.0+sin(tt*2.5+x*0.05)*2.0)
			var b:=Vector2(x+TILE,y+6.0+sin(tt*2.5+(x+TILE)*0.05)*2.0)
			water_layer.draw_line(a,b,Color(1,1,1,0.8),2.0)
			water_layer.draw_line(a+Vector2(6,5),a+Vector2(14,5),Color(1,1,1,0.25),1.0)
		var sx:=x+fmod(tt*12.0+cv.y*13.0,TILE)
		water_layer.draw_line(Vector2(sx,y+18),Vector2(minf(sx+6.0,x+TILE),y+18),Color(1,1,1,0.12),1.0)
func draw_slope(c:int,r:int,ch:String,rng:RandomNumberGenerator)->void:
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	var a:=Vector2(x,y+TILE)if ch=="/" else Vector2(x,y)
	var b:=Vector2(x+TILE,y)if ch=="/" else Vector2(x+TILE,y+TILE)
	var corner:=Vector2(x+TILE,y+TILE)if ch=="/" else Vector2(x,y+TILE)
	var tri:=PackedVector2Array([a,b,corner])
	canvas.draw_colored_polygon(tri,Color.WHITE)
	canvas.draw_line(a,b,Color(0,0,0,0.35),1.5)
	var n:=(b-a).normalized()
	var up:=Vector2(n.y,-n.x)if ch=="/" else Vector2(-n.y,n.x)
	if up.y>0.0:
		up=-up
	match world:
		0:
			var k:=0.0
			while k<1.0:
				var p:=a.lerp(b,k)
				var h:=rng.randf_range(4.0,8.0)
				canvas.draw_colored_polygon(PackedVector2Array([p-n*1.5-up*3.0,p+n*1.5-up*3.0,p+up*h+Vector2(rng.randf_range(-1.5,1.5),0)]),Color.BLACK)
				k+=rng.randf_range(0.08,0.14)
		3:
			for i in 4:
				canvas.draw_circle(a.lerp(b,0.12+i*0.25)-up*1.0,rng.randf_range(2.5,4.0),Color(0.08,0.08,0.08))
		4:
			for i in 4:
				canvas.draw_circle(a.lerp(b,0.12+i*0.25)-up*1.0,rng.randf_range(5.0,6.5),Color.WHITE)
		_:
			canvas.draw_line(a-up*1.5,b-up*1.5,Color(0.7,0.7,0.7),2.0)
func draw_cracked(c:int,r:int)->void:
	var rect:=Rect2(c*TILE,r*TILE,TILE,TILE)
	canvas.draw_rect(rect,Color(0.72,0.72,0.72))
	canvas.draw_rect(rect.grow(-1),Color.BLACK,false,1.5)
	canvas.draw_line(rect.position+Vector2(0,16),rect.position+Vector2(32,16),Color(0,0,0,0.4),1.0)
	canvas.draw_line(rect.position+Vector2(16,0),rect.position+Vector2(16,16),Color(0,0,0,0.4),1.0)
	var crack:=PackedVector2Array([rect.position+Vector2(6,4),rect.position+Vector2(12,12),rect.position+Vector2(9,19),rect.position+Vector2(17,25),rect.position+Vector2(14,30)])
	canvas.draw_polyline(crack,Color.BLACK,1.5)
	canvas.draw_line(rect.position+Vector2(12,12),rect.position+Vector2(22,9),Color.BLACK,1.0)
	canvas.draw_line(rect.position+Vector2(17,25),rect.position+Vector2(26,22),Color.BLACK,1.0)
func draw_chest(c:int,r:int)->void:
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	var body:=Rect2(x+3,y+12,26,18)
	canvas.draw_circle(Vector2(x+16,y+20),18.0,Color(1,0.85,0.3,0.08))
	canvas.draw_rect(body,Color(0.35,0.35,0.35))
	canvas.draw_rect(body,Color.BLACK,false,1.5)
	var lid:=PackedVector2Array([Vector2(x+3,y+12),Vector2(x+5,y+6),Vector2(x+27,y+6),Vector2(x+29,y+12)])
	canvas.draw_colored_polygon(lid,Color(0.45,0.45,0.45))
	canvas.draw_polyline(PackedVector2Array([lid[0],lid[1],lid[2],lid[3]]),Color.BLACK,1.5)
	canvas.draw_line(Vector2(x+9,y+6),Vector2(x+9,y+30),Color(0.85,0.85,0.85),2.0)
	canvas.draw_line(Vector2(x+23,y+6),Vector2(x+23,y+30),Color(0.85,0.85,0.85),2.0)
	canvas.draw_rect(Rect2(x+13,y+10,6,7),Color(1.0,0.8,0.25))
	canvas.draw_rect(Rect2(x+13,y+10,6,7),Color.BLACK,false,1.0)
func tile_hash(c:int,r:int)->int:
	return absi((c*73856093)^(r*19349663))%100000
func depth_of(c:int,r:int)->int:
	for d in range(1,4):
		if not ground_at(c,r-d)or not ground_at(c,r+d)or not ground_at(c-d,r)or not ground_at(c+d,r):
			return d
	return 4
func draw_tile(c:int,r:int,rng:RandomNumberGenerator)->void:
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	var rect:=Rect2(x,y,TILE,TILE)
	var shade:float=[1.0,1.0,0.8,0.62,0.5][depth_of(c,r)]
	var base:=Color(shade,shade,shade)
	canvas.draw_rect(rect,base)
	var ink:=Color(0,0,0,0.55*shade)
	var up:=not ground_at(c,r-1)
	var down:=not ground_at(c,r+1)
	canvas.draw_rect(Rect2(x,y+22,TILE,10),Color(0,0,0,0.08))
	if not ground_at(c-1,r):
		canvas.draw_line(Vector2(x+1,y),Vector2(x+1,y+TILE),Color.BLACK,2.0)
		canvas.draw_line(Vector2(x+3,y+2),Vector2(x+3,y+TILE),Color(1,1,1,0.5),1.0)
	if not ground_at(c+1,r):
		canvas.draw_line(Vector2(x+TILE-1,y),Vector2(x+TILE-1,y+TILE),Color.BLACK,2.0)
		canvas.draw_line(Vector2(x+TILE-4,y+2),Vector2(x+TILE-4,y+TILE),Color(0,0,0,0.15),2.0)
	if down and r<rows-1:
		canvas.draw_line(Vector2(x,y+TILE-1),Vector2(x+TILE,y+TILE-1),Color.BLACK,2.0)
	match world:
		1:
			for i in 2:
				var p:=Vector2(x+rng.randf_range(4,28),y+rng.randf_range(4,28))
				canvas.draw_line(p,p+Vector2(rng.randf_range(-7,7),rng.randf_range(3,8)),ink,1.0)
			if down and r>0:
				var sx:=x+rng.randf_range(6,26)
				var tri:=PackedVector2Array([Vector2(sx-4,y+TILE),Vector2(sx+4,y+TILE),Vector2(sx,y+TILE+rng.randf_range(6,14))])
				canvas.draw_colored_polygon(tri,base)
				canvas.draw_polyline(PackedVector2Array([tri[0],tri[2],tri[1]]),Color.BLACK,1.0)
		3:
			if rng.randi()%2==0:
				var p:=Vector2(x+rng.randf_range(4,28),y+rng.randf_range(4,20))
				canvas.draw_line(p,p+Vector2(rng.randf_range(-6,6),10),ink,1.5)
			if down and r>0:
				var dx:=x+rng.randf_range(6,26)
				canvas.draw_line(Vector2(dx,y+TILE),Vector2(dx,y+TILE+rng.randf_range(4,12)),Color(0.3,0.3,0.3),2.0)
		4:
			if down and r>0:
				for i in 3:
					canvas.draw_circle(Vector2(x+6+i*10,y+TILE-2),7.0,base)
			canvas.draw_arc(Vector2(x+rng.randf_range(8,24),y+rng.randf_range(10,22)),4.0,0.0,PI,6,Color(0,0,0,0.12),1.0)
		2:
			var mortar:=Color(0,0,0,0.4*shade)
			canvas.draw_line(Vector2(x,y+16),Vector2(x+TILE,y+16),mortar,1.0)
			canvas.draw_line(Vector2(x,y),Vector2(x+TILE,y),mortar,1.0)
			var off:=0.0 if r%2==0 else 16.0
			canvas.draw_line(Vector2(x+off,y),Vector2(x+off,y+16),mortar,1.0)
			canvas.draw_line(Vector2(x+16-off+8,y+16),Vector2(x+16-off+8,y+32),mortar,1.0)
			if rng.randi()%7==0:
				var p:=Vector2(x+rng.randf_range(4,28),y)
				for i in 4:
					var q:=p+Vector2(sin(i*1.7)*4.0,7.0)
					canvas.draw_line(p,q,Color.BLACK,1.5)
					canvas.draw_circle(q,2.0,Color.BLACK)
					p=q
		_:
			if rng.randi()%3==0:
				canvas.draw_circle(Vector2(x+rng.randf_range(5,27),y+rng.randf_range(8,28)),rng.randf_range(1.0,2.5),ink)
			if rng.randi()%5==0:
				var p:=Vector2(x+rng.randf_range(4,28),y+rng.randf_range(6,20))
				canvas.draw_line(p,p+Vector2(rng.randf_range(-6,6),8),ink,1.0)
	if up:
		if world==0:
			var gx:=x
			while gx<x+TILE-2.0:
				var h:=rng.randf_range(4.0,9.0)
				var lean:=rng.randf_range(-2.0,2.0)
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(gx,y+5),Vector2(gx+3,y+5),Vector2(gx+1.5+lean,y+5-h)]),Color.BLACK)
				gx+=rng.randf_range(3.0,5.0)
			if rng.randi()%6==0:
				var fx0:=x+rng.randf_range(6,26)
				canvas.draw_line(Vector2(fx0,y+2),Vector2(fx0,y-6),Color.BLACK,1.0)
				canvas.draw_circle(Vector2(fx0,y-7),2.0,Color.WHITE)
				canvas.draw_circle(Vector2(fx0,y-7),0.8,Color.BLACK)
		elif world==1:
			canvas.draw_line(Vector2(x,y+1),Vector2(x+TILE,y+1),Color(0.6,0.6,0.6),2.0)
			if rng.randi()%5==0 and r>2:
				var cx:=x+rng.randf_range(8,24)
				canvas.draw_circle(Vector2(cx,y-6),12.0,Color(1,1,1,0.08))
				for i in 3:
					var h:=rng.randf_range(8,16)
					var ox:=(i-1)*5.0
					var tilt:=(i-1)*3.0
					var cr:=PackedVector2Array([Vector2(cx+ox-2.5,y+1),Vector2(cx+ox+tilt,y-h),Vector2(cx+ox+2.5,y+1)])
					canvas.draw_colored_polygon(cr,Color.WHITE)
					canvas.draw_polyline(cr,Color.BLACK,1.0)
		elif world==3:
			for i in 4:
				canvas.draw_circle(Vector2(x+4+i*8,y+2),rng.randf_range(2.5,4.5),Color(0.08,0.08,0.08))
		elif world==4:
			for i in 4:
				canvas.draw_circle(Vector2(x+4+i*8,y+2),rng.randf_range(5.0,7.0),Color.WHITE)
			canvas.draw_arc(Vector2(x+16,y+6),14.0,PI*1.15,PI*1.85,8,Color(0,0,0,0.15),1.5)
		else:
			canvas.draw_rect(Rect2(x,y,TILE,4),Color(0.85,0.85,0.85))
			canvas.draw_line(Vector2(x,y+4),Vector2(x+TILE,y+4),Color(0,0,0,0.5),1.0)
		draw_prop(x,y,rng)
func draw_prop(x:float,y:float,rng:RandomNumberGenerator)->void:
	var roll:=rng.randi()%14
	var px:=x+rng.randf_range(8,24)
	match world:
		0,3:
			if roll==0:
				canvas.draw_line(Vector2(px,y),Vector2(px,y-6),Color(0.85,0.85,0.85),3.0)
				canvas.draw_colored_polygon(ellipse_half(Vector2(px,y-6),6.0,5.0),Color.WHITE)
				canvas.draw_polyline(ellipse_half(Vector2(px,y-6),6.0,5.0),Color.BLACK,1.0)
				canvas.draw_circle(Vector2(px-2,y-8),1.0,Color.BLACK)
				canvas.draw_circle(Vector2(px+2,y-9),0.8,Color.BLACK)
			elif roll==1 and world==3:
				canvas.draw_line(Vector2(px,y),Vector2(px+2,y-18),Color.BLACK,1.5)
				canvas.draw_rect(Rect2(px,y-22,4,8),Color.BLACK)
		1:
			if roll==0:
				canvas.draw_circle(Vector2(px,y-4),4.0,Color.WHITE)
				canvas.draw_rect(Rect2(px-2.5,y-2,5,3),Color.WHITE)
				canvas.draw_circle(Vector2(px-1.5,y-4),1.0,Color.BLACK)
				canvas.draw_circle(Vector2(px+1.5,y-4),1.0,Color.BLACK)
				canvas.draw_arc(Vector2(px,y-4),4.0,PI,TAU,6,Color.BLACK,1.0)
		2:
			if roll==0:
				canvas.draw_rect(Rect2(px-2,y-8,4,8),Color(0.9,0.9,0.9))
				canvas.draw_rect(Rect2(px-2,y-8,4,8),Color.BLACK,false,1.0)
				canvas.draw_circle(Vector2(px,y-11),5.0,Color(1,1,1,0.15))
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(px-1.5,y-9),Vector2(px,y-14),Vector2(px+1.5,y-9)]),Color.WHITE)
func ellipse_half(center:Vector2,rx:float,ry:float)->PackedVector2Array:
	var pts:=PackedVector2Array()
	for i in 9:
		var a:=PI+PI*i/8.0
		pts.append(center+Vector2(cos(a)*rx,sin(a)*ry))
	return pts
func draw_platform(c:int,r:int,rng:RandomNumberGenerator)->void:
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	var rect:=Rect2(x,y,TILE,12)
	match world:
		3:
			canvas.draw_rect(Rect2(x,y+1,TILE,10),Color(0.75,0.75,0.75))
			canvas.draw_line(Vector2(x,y+1),Vector2(x+TILE,y+1),Color.BLACK,1.5)
			canvas.draw_line(Vector2(x,y+11),Vector2(x+TILE,y+11),Color.BLACK,1.5)
			canvas.draw_line(Vector2(x+4,y+5),Vector2(x+20,y+5),Color(0,0,0,0.35),1.0)
			if cell(c-1,r)!="=":
				canvas.draw_circle(Vector2(x+2,y+6),5.5,Color.BLACK)
				canvas.draw_circle(Vector2(x+2,y+6),4.5,Color(0.9,0.9,0.9))
				canvas.draw_arc(Vector2(x+2,y+6),2.5,0.0,TAU,8,Color(0,0,0,0.5),1.0)
			if cell(c+1,r)!="=":
				canvas.draw_circle(Vector2(x+TILE-2,y+6),5.5,Color.BLACK)
				canvas.draw_circle(Vector2(x+TILE-2,y+6),4.5,Color(0.9,0.9,0.9))
				canvas.draw_arc(Vector2(x+TILE-2,y+6),2.5,0.0,TAU,8,Color(0,0,0,0.5),1.0)
		4:
			for i in 3:
				canvas.draw_circle(Vector2(x+6+i*10,y+6),8.0,Color(0.3,0.3,0.3))
			for i in 3:
				canvas.draw_circle(Vector2(x+6+i*10,y+5),7.0,Color.WHITE)
		1:
			canvas.draw_rect(rect,Color(0.85,0.85,0.85))
			canvas.draw_rect(rect,Color.BLACK,false,1.0)
			canvas.draw_line(Vector2(x+rng.randf_range(6,26),y+2),Vector2(x+rng.randf_range(6,26),y+10),Color(0,0,0,0.5),1.0)
			var tri:=PackedVector2Array([Vector2(x+10,y+12),Vector2(x+22,y+12),Vector2(x+16,y+22)])
			canvas.draw_colored_polygon(tri,Color(0.85,0.85,0.85))
			canvas.draw_polyline(PackedVector2Array([tri[0],tri[2],tri[1]]),Color.BLACK,1.0)
		2:
			canvas.draw_rect(rect,Color.WHITE)
			canvas.draw_rect(rect,Color.BLACK,false,1.0)
			canvas.draw_line(Vector2(x+16,y),Vector2(x+16,y+12),Color(0,0,0,0.5),1.0)
			if cell(c-1,r)!="=" or cell(c+1,r)!="=":
				var cx:=x+6.0 if cell(c-1,r)!="=" else x+26.0
				for i in 6:
					canvas.draw_arc(Vector2(cx,y-6-i*8),3.0,0.0,TAU,8,Color(0.4,0.4,0.4),1.5)
		_:
			canvas.draw_rect(rect,Color.WHITE)
			canvas.draw_rect(rect,Color.BLACK,false,1.0)
			canvas.draw_line(Vector2(x,y+6),Vector2(x+TILE,y+6),Color(0,0,0,0.4),1.0)
			canvas.draw_circle(Vector2(x+4,y+3),1.0,Color.BLACK)
			canvas.draw_circle(Vector2(x+28,y+9),1.0,Color.BLACK)
			canvas.draw_line(Vector2(x+8,y+12),Vector2(x+6,y+18),Color(0.7,0.7,0.7),1.0)
func draw_crate(c:int,r:int)->void:
	var rect:=Rect2(c*TILE+1,r*TILE+1,TILE-2,TILE-2)
	canvas.draw_rect(rect,Color.WHITE)
	canvas.draw_rect(rect,Color.BLACK,false,2.0)
	var inner:=rect.grow(-5)
	canvas.draw_rect(inner,Color.BLACK,false,1.0)
	canvas.draw_line(inner.position,inner.end,Color.BLACK,1.5)
	canvas.draw_line(Vector2(inner.end.x,inner.position.y),Vector2(inner.position.x,inner.end.y),Color.BLACK,1.5)
func draw_spikes(c:int,r:int,ceiling:bool)->void:
	var x:=float(c*TILE)
	var y:=float(r*TILE)
	for k in 2:
		var x0:=x+k*16.0
		var tri:=PackedVector2Array()
		if ceiling:
			tri=PackedVector2Array([Vector2(x0,y),Vector2(x0+8,y+16),Vector2(x0+16,y)])
		else:
			tri=PackedVector2Array([Vector2(x0,y+TILE),Vector2(x0+8,y+TILE-16),Vector2(x0+16,y+TILE)])
		canvas.draw_colored_polygon(tri,Color.WHITE)
		canvas.draw_polyline(tri,Color.BLACK,1.5)
func draw_deco()->void:
	var tt:=time
	if not player.dead:
		for k in 3:
			deco.draw_circle(player.global_position,40.0+k*22.0,Color(1,1,1,0.025))
	for cp in checkpoints:
		var p:Vector2=cp["pos"]
		deco.draw_line(p+Vector2(0,16),p+Vector2(0,-10),Color(0.55,0.55,0.55),3.0)
		var lamp:=p+Vector2(0,-18)
		deco.draw_rect(Rect2(lamp-Vector2(6,8),Vector2(12,16)),Color.BLACK)
		deco.draw_rect(Rect2(lamp-Vector2(6,8),Vector2(12,16)),Color(0.7,0.7,0.7),false,1.5)
		if cp["on"]:
			var f:=1.0+0.2*sin(tt*14.0+p.x)
			for k in 3:
				deco.draw_circle(lamp,(12.0+k*9.0)*f,Color(1,1,1,0.07))
			deco.draw_circle(lamp+Vector2(0,2),3.5*f,Color.WHITE)
		else:
			deco.draw_circle(lamp+Vector2(0,2),2.0,Color(0.35,0.35,0.35))
	if exit_alpha>0.0:
		var a:=exit_alpha
		var base:=exit_pos+Vector2(0,16)
		var pulse:=0.5+0.5*sin(tt*3.0)
		for k in 4:
			deco.draw_circle(base+Vector2(0,-28),30.0+k*12.0+pulse*4.0,Color(1,1,1,0.04*a))
		var frame:=PackedVector2Array([base+Vector2(-20,0),base+Vector2(-20,-40),base+Vector2(-12,-54),base+Vector2(0,-58),base+Vector2(12,-54),base+Vector2(20,-40),base+Vector2(20,0)])
		deco.draw_colored_polygon(frame,Color(1,1,1,a))
		var inner:=PackedVector2Array([base+Vector2(-13,0),base+Vector2(-13,-38),base+Vector2(-7,-48),base+Vector2(0,-51),base+Vector2(7,-48),base+Vector2(13,-38),base+Vector2(13,0)])
		deco.draw_colored_polygon(inner,Color(0,0,0,a))
		deco.draw_circle(base+Vector2(0,-24),6.0+pulse*3.0,Color(1,1,1,0.5*a))
		deco.draw_circle(base+Vector2(0,-24),3.0,Color(1,1,1,a))
		if int(tt*10.0)%4==0:
			fx.spawn(base+Vector2(randf_range(-10,10),-4),Vector2(0,-30),Color(1,1,1,0.7*a),1.0,2.0)
func draw_mover(body:AnimatableBody2D)->void:
	var rect:=Rect2(-48,-6,96,12)
	body.draw_rect(rect,Color.WHITE)
	body.draw_rect(rect,Color.BLACK,false,1.5)
	for i in 3:
		body.draw_line(Vector2(-16+i*16-16,-6),Vector2(-16+i*16-16,6),Color(0,0,0,0.4),1.0)
	var glow:=0.5+0.5*sin(Time.get_ticks_msec()*0.004)
	body.draw_circle(Vector2(0,12),5.0,Color(1,1,1,0.15+0.2*glow))
	body.draw_colored_polygon(PackedVector2Array([Vector2(0,8),Vector2(4,12),Vector2(0,16),Vector2(-4,12)]),Color.WHITE)
