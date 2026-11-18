extends Node2D
const GameData=preload("res://game_data.gd")
var kind:="marcheur"
var level=null
var target=null
var hp:=1
var coins:=1
var dir_x:=-1.0
var speed:=45.0
var home:=Vector2.ZERO
var vel:=Vector2.ZERO
var timer:=0.0
var state:="repos"
var dead:=false
var flash:=0.0
var anim_time:=0.0
var on_ground:=true
var stompable:=true
var pose:=0
var rect_offset:=Vector2(-12,-8)
var rect_size:=Vector2(24,24)
var sprite:Sprite2D
var frames:Array=[]
var frames_flash:Array=[]
const WALKER_A:=[
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
const WALKER_B:=[
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
const SHOOTER_A:=[
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
const SHOOTER_B:=[
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
const BAT_A:=[
	"................",
	"w..............w",
	"ww............ww",
	"w#w....ww....w#w",
	"w##w..w##w..w##w",
	"w###ww####ww###w",
	"w###w#w##w#w###w",
	".w###########w..",
	"..w##w####w##w..",
	"...ww.w##w.ww...",
	"......w..w......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const BAT_B:=[
	"................",
	"................",
	"................",
	".......ww.......",
	"......w##w......",
	"....ww####ww....",
	"..ww#w#ww#w#ww..",
	".w############w.",
	"w##w##w##w##w##w",
	"w#w.ww#ww#ww.w#w",
	"ww.....ww.....ww",
	"w..............w",
	"................",
	"................",
	"................",
	"................",
]
const JUMPER_A:=[
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......wwww......",
	"....ww####ww....",
	"...w########w...",
	"..w##ww##ww##w..",
	"..w##w#ww#w##w..",
	".w############w.",
	".w##w######w##w.",
	".w############w.",
	"..wwwwwwwwwwww..",
]
const JUMPER_B:=[
	"................",
	"................",
	"......wwww......",
	".....w####w.....",
	"....w######w....",
	"....w#ww#ww#....",
	"....w#w#w#w#w...",
	"....w######w....",
	"....w######w....",
	"....w##ww##w....",
	"....w######w....",
	".....w####w.....",
	"....w#w..w#w....",
	"...w#w....w#w...",
	"...ww......ww...",
	"................",
]
const GHOST_A:=[
	"................",
	".....wwwwww.....",
	"....w######w....",
	"...w########w...",
	"...w#ww##ww#w...",
	"...w#ww##ww#w...",
	"...w########w...",
	"...w###ww###w...",
	"...w##w##w##w...",
	"...w########w...",
	"...w########w...",
	"...w########w...",
	"...w#w##w##w#w..",
	"...ww.ww.ww.ww..",
	"................",
	"................",
]
const GHOST_B:=[
	"................",
	"................",
	".....wwwwww.....",
	"....w######w....",
	"...w########w...",
	"...w#ww##ww#w...",
	"...w#ww##ww#w...",
	"...w########w...",
	"...w###ww###w...",
	"...w##w##w##w...",
	"...w########w...",
	"...w########w...",
	"..w#w##w##w#w...",
	"..ww.ww.ww.ww...",
	"................",
	"................",
]
const EYE_A:=[
	"................",
	".....wwwwww.....",
	"...ww######ww...",
	"..w##wwwwww##w..",
	".w##wwwwwwww##w.",
	".w#wwww##wwww#w.",
	"w##www####www##w",
	"w##www####www##w",
	".w#wwww##wwww#w.",
	".w##wwwwwwww##w.",
	"..w##wwwwww##w..",
	"...ww######ww...",
	".....w#ww#w.....",
	"......w..w......",
	".....w....w.....",
	"................",
]
const EYE_B:=[
	"................",
	".....wwwwww.....",
	"...ww######ww...",
	"..w##wwwwww##w..",
	".w##wwwwwwww##w.",
	".w#ww##wwwwww#w.",
	"w##w####wwwww##w",
	"w##w####wwwww##w",
	".w#ww##wwwwww#w.",
	".w##wwwwwwww##w.",
	"..w##wwwwww##w..",
	"...ww######ww...",
	".....w#ww#w.....",
	".....w....w.....",
	"......w..w......",
	"................",
]
const KNIGHT_A:=[
	".......ww.......",
	"......w##w......",
	".....w####w.....",
	"....w######w....",
	"....w#ww#ww#w...",
	"....w######w....",
	"..www######w....",
	".w#ggw#####ww...",
	".w#ggw######ww..",
	".w#ggw#######w..",
	".w#ggw######w...",
	"..wwww######w...",
	"....w###w###w...",
	"....w##w.w##w...",
	"....w##w.w##w...",
	"...ww##w.w##ww..",
]
const KNIGHT_B:=[
	".......ww.......",
	"......w##w......",
	".....w####w.....",
	"....w######w....",
	"....w#ww#ww#w...",
	"....w######w....",
	"..www######w....",
	".w#ggw#####ww...",
	".w#ggw######ww..",
	".w#ggw#######w..",
	".w#ggw######w...",
	"..wwww######w...",
	"....w###ww##w...",
	"...w##w..w##w...",
	"..w##w....w##w..",
	"..www......www..",
]
func _ready()->void:
	add_to_group("ennemis")
	home=position
	sprite=Sprite2D.new()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2(2,2)
	add_child(sprite)
	var art:Array=[WALKER_A,WALKER_B]
	match kind:
		"tireur":
			art=[SHOOTER_A,SHOOTER_B]
			hp=2
			coins=4
			timer=2.0
			rect_offset=Vector2(-12,-14)
			rect_size=Vector2(24,30)
		"chauve-souris":
			art=[BAT_A,BAT_B]
			hp=1
			coins=2
			rect_offset=Vector2(-13,-12)
			rect_size=Vector2(26,16)
		"sauteur":
			art=[JUMPER_A,JUMPER_B]
			hp=2
			coins=3
			timer=1.0
			rect_offset=Vector2(-13,-2)
			rect_size=Vector2(26,18)
		"oeil":
			art=[EYE_A,EYE_B]
			hp=2
			coins=3
			timer=1.5
			rect_offset=Vector2(-13,-12)
			rect_size=Vector2(26,22)
		"chevalier":
			art=[KNIGHT_A,KNIGHT_B]
			hp=4
			coins=6
			stompable=false
			rect_offset=Vector2(-11,-14)
			rect_size=Vector2(22,30)
		"spectre":
			art=[GHOST_A,GHOST_B]
			hp=2
			coins=3
			rect_offset=Vector2(-11,-12)
			rect_size=Vector2(22,24)
		_:
			hp=1
			coins=2
	for rows in art:
		frames.append(GameData.make_texture(rows))
		frames_flash.append(GameData.make_texture(rows,true))
	sprite.texture=frames[0]
func get_hit_rect()->Rect2:
	return Rect2(position+rect_offset,rect_size)
func _physics_process(delta:float)->void:
	if dead or level==null or target==null:
		return
	anim_time+=delta
	flash=maxf(0.0,flash-delta)
	match kind:
		"tireur":
			update_shooter(delta)
		"chauve-souris":
			update_bat(delta)
		"sauteur":
			update_jumper(delta)
		"spectre":
			update_ghost(delta)
		"oeil":
			update_eye(delta)
		"chevalier":
			update_knight(delta)
		_:
			update_walker(delta)
	sprite.texture=frames_flash[pose]if flash>0.0 else frames[pose]
	queue_redraw()
func _draw()->void:
	if dead or kind=="chauve-souris" or kind=="spectre" or kind=="oeil" or not on_ground:
		return
	draw_set_transform(Vector2(0,16),0.0,Vector2(1.0,0.3))
	draw_circle(Vector2.ZERO,12.0,Color(0,0,0,0.45))
	draw_set_transform(Vector2.ZERO)
func update_walker(delta:float)->void:
	position.x+=dir_x*speed*delta
	var ahead:=position+Vector2(dir_x*14.0,0)
	if level.is_solid(ahead)or not level.is_solid(ahead+Vector2(0,22),true):
		dir_x=-dir_x
	sprite.flip_h=dir_x>0.0
	pose=int(anim_time*6.0)%2
func update_shooter(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	dir_x=1.0 if to_player.x>0.0 else-1.0
	sprite.flip_h=dir_x>0.0
	pose=0
	if absf(to_player.x)>420.0 or absf(to_player.y)>140.0:
		return
	timer-=delta
	if timer<0.3:
		pose=1
	if timer<=0.0:
		timer=2.0
		level.spawn_projectile(position+Vector2(dir_x*18.0,6.0),Vector2(dir_x*150.0,0),"ennemi","boule")
func update_bat(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	pose=int(anim_time*10.0)%2
	sprite.flip_h=to_player.x>0.0
	timer-=delta
	match state:
		"attaque":
			position+=to_player.normalized()*100.0*delta
			if timer<=0.0:
				state="retour"
		"retour":
			position=position.move_toward(home,70.0*delta)
			if position.distance_to(home)<4.0:
				state="repos"
				timer=1.2
		_:
			var hover:=home+Vector2(sin(anim_time*1.5)*30.0,sin(anim_time*3.0)*8.0)
			position=position.move_toward(hover,60.0*delta)
			if timer<=0.0 and to_player.length()<210.0:
				state="attaque"
				timer=1.8
func update_jumper(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	if on_ground:
		pose=0
		sprite.scale=sprite.scale.lerp(Vector2(2,2),10.0*delta)
		timer-=delta
		if timer<0.25:
			sprite.scale=Vector2(2.4,1.6)
		if timer<=0.0 and absf(to_player.x)<300.0:
			dir_x=1.0 if to_player.x>0.0 else-1.0
			vel=Vector2(dir_x*95.0,-360.0)
			on_ground=false
			timer=1.4
			sprite.scale=Vector2(1.6,2.5)
	else:
		pose=1
		sprite.scale=sprite.scale.lerp(Vector2(2,2),6.0*delta)
		vel.y+=900.0*delta
		var nx:=position.x+vel.x*delta
		if level.is_solid(Vector2(nx+signf(vel.x)*12.0,position.y)):
			vel.x=0.0
		else:
			position.x=nx
		if vel.y<0.0 and level.is_solid(position+Vector2(0,-16)):
			vel.y=0.0
		position.y+=vel.y*delta
		var feet:=position+Vector2(0,16)
		if vel.y>0.0 and level.is_solid(feet,true):
			position.y=floor(feet.y/32.0)*32.0-16.0
			vel=Vector2.ZERO
			on_ground=true
			sprite.scale=Vector2(2.6,1.5)
			level.fx.burst(position+Vector2(0,16),5,40.0,Color(0.8,0.8,0.8),0.3,2.0)
		if position.y>level.world_bottom()+80.0:
			queue_free()
	sprite.flip_h=dir_x>0.0
func update_eye(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	var hover:=home+Vector2(sin(anim_time*0.9)*40.0,sin(anim_time*2.2)*10.0)
	position=position.move_toward(hover,50.0*delta)
	pose=1 if to_player.x>0.0 else 0
	sprite.flip_h=false
	timer-=delta
	if timer<=0.0 and to_player.length()<320.0:
		timer=2.2
		level.spawn_projectile(position+to_player.normalized()*14.0,to_player.normalized()*160.0,"ennemi","boule")
		sprite.scale=Vector2(2.5,2.5)
	sprite.scale=sprite.scale.lerp(Vector2(2,2),8.0*delta)
func update_knight(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	var sees:=absf(to_player.y)<40.0 and absf(to_player.x)<190.0 and signf(to_player.x)==dir_x
	var spd:=115.0 if sees else 40.0
	position.x+=dir_x*spd*delta
	var ahead:=position+Vector2(dir_x*14.0,0)
	if level.is_solid(ahead)or not level.is_solid(ahead+Vector2(0,22),true):
		dir_x=-dir_x
	sprite.flip_h=dir_x>0.0
	pose=int(anim_time*(10.0 if sees else 5.0))%2
	if sees and int(anim_time*10.0)%3==0:
		level.fx.spawn(position+Vector2(-dir_x*8.0,15.0),Vector2(-dir_x*30.0,-20.0),Color(0.8,0.8,0.8,0.7),0.3,2.0)
func update_ghost(delta:float)->void:
	var to_player:Vector2=target.global_position-global_position
	if to_player.length()<320.0:
		position+=to_player.normalized()*38.0*delta
	else:
		position=position.move_toward(home,30.0*delta)
	sprite.position.y=sin(anim_time*3.0)*3.0
	sprite.modulate.a=0.55+0.25*sin(anim_time*4.0)
	sprite.flip_h=to_player.x>0.0
	pose=int(anim_time*4.0)%2
func take_damage(amount:int,from_x:float)->bool:
	if dead:
		return false
	hp-=amount
	flash=0.12
	level.damage_number(position,amount)
	if hp>0:
		level.sound("touche")
	if kind=="chauve-souris" or kind=="spectre":
		position.x+=signf(position.x-from_x)*14.0
		state="retour"
	if hp<=0:
		die()
		return true
	level.fx.burst(position,5,80.0,Color.WHITE,0.25,2.0)
	return false
func die()->void:
	dead=true
	level.on_enemy_killed(self)
	sprite.texture=frames_flash[0]
	var tw:=create_tween()
	tw.tween_property(sprite,"scale",Vector2(3.0,0.4),0.12)
	tw.tween_property(sprite,"modulate:a",0.0,0.25)
	tw.tween_callback(queue_free)
