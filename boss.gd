extends Node2D
var kind:="corbeau"
var level=null
var target=null
var hp:=14
var max_hp:=14
var display_name:=""
var state:="intro"
var timer:=1.5
var vel:=Vector2.ZERO
var facing:=-1.0
var flash:=0.0
var t:=0.0
var dead:=false
var phase2:=false
var alpha:=1.0
var shot_timer:=0.0
var shots_left:=0
var attack_index:=0
var dive_goal:=Vector2.ZERO
var shake:=Vector2.ZERO
var arena_left:=64.0
var arena_right:=768.0
var ground_y:=320.0
var half:=Vector2(30,20)
var tongue:=0.0
var tongue_dir:=Vector2(1,0)
var hist:Array=[]
func _ready()->void:
	add_to_group("boss")
	match kind:
		"golem":
			display_name="LE GOLEM"
			max_hp=20
			half=Vector2(28,34)
			position.y=ground_y+50.0
		"crapaud":
			display_name="LE CRAPAUD GÉANT"
			max_hp=24
			half=Vector2(34,24)
			position.y=-80.0
		"dragon":
			display_name="LE DRAGON DE BRUME"
			max_hp=30
			half=Vector2(18,13)
			position=Vector2(arena_right+120.0,90.0)
		"roi":
			display_name="LE ROI OMBRE"
			max_hp=26
			half=Vector2(20,30)
			alpha=0.0
			position.y=190.0
		_:
			display_name="LE CORBEAU"
			max_hp=14
			half=Vector2(30,18)
			position.y=-60.0
	hp=max_hp
	z_index=2
func get_extra_rects()->Array:
	var out:=[]
	if dead or state=="intro":
		return out
	if kind=="crapaud" and tongue>4.0:
		var mouth:=tongue_mouth()
		var d:=0.0
		while d<=tongue:
			var q:=mouth+tongue_dir*d
			out.append(Rect2(q-Vector2(7,7),Vector2(14,14)))
			d+=12.0
	elif kind=="dragon":
		for i in range(1,10):
			var p:=segment_pos(i)
			var r:=11.0-i*0.5
			out.append(Rect2(p-Vector2(r,r),Vector2(r,r)*2.0))
	return out
func tongue_mouth()->Vector2:
	return position+Vector2(facing*26.0,-2.0)
func get_hit_rect()->Rect2:
	return Rect2(position-half,half*2.0)
func can_be_hit()->bool:
	return not dead and state!="intro" and alpha>0.6
func is_harmful()->bool:
	return can_be_hit()
func take_damage(amount:int,_from_x:float)->bool:
	if not can_be_hit():
		return false
	hp-=amount
	flash=0.12
	level.damage_number(position+Vector2(0,-half.y),amount)
	level.sound("touche")
	level.fx.burst(position,8,120.0,Color.WHITE,0.3,2.5)
	if not phase2 and hp<=max_hp*0.5:
		phase2=true
		level.popup("COLÈRE !",position+Vector2(0,-60))
		level.shake(8.0)
	if hp<=0:
		hp=0
		dead=true
		state="mort"
		timer=2.0
		level.sound("boss",0.0)
		return true
	return false
func _physics_process(delta:float)->void:
	if level==null or target==null:
		return
	t+=delta
	flash=maxf(0.0,flash-delta)
	if state=="mort":
		update_death(delta)
	else:
		match kind:
			"golem":
				update_golem(delta)
			"roi":
				update_roi(delta)
			"crapaud":
				update_crapaud(delta)
			"dragon":
				update_dragon(delta)
			_:
				update_corbeau(delta)
	modulate.a=alpha
	queue_redraw()
func update_death(delta:float)->void:
	timer-=delta
	shake=Vector2(randf_range(-4,4),randf_range(-4,4))
	flash=0.05 if int(t*12.0)%2==0 else 0.0
	shot_timer-=delta
	if shot_timer<=0.0:
		shot_timer=0.12
		level.fx.burst(position+Vector2(randf_range(-half.x,half.x),randf_range(-half.y,half.y)),10,140.0,Color.WHITE,0.5,3.0)
		level.shake(4.0)
	if timer<=0.0:
		level.fx.burst(position,40,220.0,Color.WHITE,0.8,3.5)
		level.fx.ring(position,30.0,Color.WHITE,0.6)
		level.on_boss_defeated(self)
		queue_free()
func update_corbeau(delta:float)->void:
	var px:float=target.global_position.x
	shake=Vector2.ZERO
	match state:
		"intro":
			position.y=move_toward(position.y,110.0,120.0*delta)
			if position.y>=110.0:
				state="vol"
				timer=3.0
		"vol":
			timer-=delta
			var goal_x:=clampf(px,arena_left+50.0,arena_right-50.0)
			position.x=move_toward(position.x,goal_x,(160.0 if phase2 else 110.0)*delta)
			position.y=110.0+sin(t*2.0)*16.0
			shot_timer-=delta
			if shot_timer<=0.0:
				shot_timer=0.5 if phase2 else 0.85
				var spreads:=[-70.0,0.0,70.0]if phase2 else[0.0]
				for sx in spreads:
					level.spawn_projectile(position+Vector2(0,16),Vector2(sx+randf_range(-20,20),170.0),"ennemi","plume")
			if timer<=0.0:
				state="prepare"
				timer=0.6
				dive_goal=Vector2(clampf(px,arena_left+30.0,arena_right-30.0),ground_y-20.0)
		"prepare":
			timer-=delta
			shake=Vector2(randf_range(-2,2),randf_range(-2,2))
			if timer<=0.0:
				state="pique"
		"pique":
			position=position.move_toward(dive_goal,430.0*delta)
			if position.distance_to(dive_goal)<4.0:
				state="au_sol"
				timer=1.0 if phase2 else 1.4
				level.shake(6.0)
				level.fx.burst(position+Vector2(0,18),14,120.0,Color(0.85,0.85,0.85),0.5,3.0,0.0,40.0)
		"au_sol":
			timer-=delta
			if timer<=0.0:
				state="remonte"
		"remonte":
			position.y=move_toward(position.y,110.0,220.0*delta)
			if position.y<=111.0:
				state="vol"
				timer=2.2 if phase2 else 3.0
	if state!="pique":
		facing=1.0 if px>position.x else-1.0
func update_golem(delta:float)->void:
	var p:Vector2=target.global_position
	var feet_y:=ground_y-half.y
	shake=Vector2.ZERO
	match state:
		"intro":
			position.y=move_toward(position.y,feet_y,40.0*delta)
			shake=Vector2(randf_range(-2,2),0)
			if int(t*10.0)%3==0:
				level.fx.burst(Vector2(position.x+randf_range(-30,30),ground_y),2,60.0,Color(0.8,0.8,0.8),0.5,3.0,300.0,120.0)
			if position.y<=feet_y:
				position.y=feet_y
				state="marche"
				timer=2.0
				level.shake(6.0)
		"marche":
			timer-=delta
			facing=1.0 if p.x>position.x else-1.0
			position.x+=facing*(75.0 if phase2 else 45.0)*delta
			position.x=clampf(position.x,arena_left+half.x,arena_right-half.x)
			if timer<=0.0:
				attack_index+=1
				if attack_index%2==1:
					state="lance"
					shots_left=5 if phase2 else 3
					shot_timer=0.3
				else:
					state="saut_prep"
					timer=0.5
		"lance":
			facing=1.0 if p.x>position.x else-1.0
			shot_timer-=delta
			if shot_timer<=0.0:
				shot_timer=0.45
				shots_left-=1
				var from_pos:=position+Vector2(facing*20.0,-36.0)
				var tt:=0.9
				var aim:=p+Vector2(randf_range(-30,30),0)
				var v:=Vector2((aim.x-from_pos.x)/tt,(aim.y-from_pos.y-0.5*600.0*tt*tt)/tt)
				level.spawn_projectile(from_pos,v,"ennemi","rocher")
				if shots_left<=0:
					state="marche"
					timer=1.6
		"saut_prep":
			timer-=delta
			shake=Vector2(randf_range(-2,2),0)
			if timer<=0.0:
				state="saut"
				vel=Vector2(clampf((p.x-position.x)/0.9,-320.0,320.0),-560.0)
		"saut":
			vel.y+=1200.0*delta
			position+=vel*delta
			position.x=clampf(position.x,arena_left+half.x,arena_right-half.x)
			if vel.y>0.0 and position.y>=feet_y:
				position.y=feet_y
				state="repos"
				timer=0.8 if phase2 else 1.2
				level.shake(10.0)
				level.fx.burst(Vector2(position.x,ground_y),20,160.0,Color(0.85,0.85,0.85),0.6,3.0,200.0,80.0)
				for d in[-1.0,1.0]:
					level.spawn_projectile(Vector2(position.x+d*34.0,ground_y-10.0),Vector2(d*230.0,0),"ennemi","onde")
		"repos":
			timer-=delta
			if timer<=0.0:
				state="marche"
				timer=2.0
func update_crapaud(delta:float)->void:
	var p:Vector2=target.global_position
	var feet_y:=ground_y-half.y
	shake=Vector2.ZERO
	match state:
		"intro":
			vel.y+=900.0*delta
			position.y+=vel.y*delta
			if position.y>=feet_y:
				position.y=feet_y
				vel=Vector2.ZERO
				land_splash()
				state="attend"
				timer=1.0
		"attend":
			facing=1.0 if p.x>position.x else-1.0
			timer-=delta
			if timer<=0.0:
				var cycle:=["saut","langue","crache","saut","langue"]
				state=cycle[attack_index%cycle.size()]
				attack_index+=1
				timer=0.4
				match state:
					"langue":
						var aim_dir:=(p-tongue_mouth()).normalized()
						aim_dir.x=facing*maxf(absf(aim_dir.x),0.5)
						aim_dir.y=clampf(aim_dir.y,-0.8,0.1)
						tongue_dir=aim_dir.normalized()
						level.sound("boss",0.1)
					"saut":
						vel=Vector2(clampf((p.x-position.x)/0.8,-300.0,300.0),-520.0)
					"crache":
						shots_left=5 if phase2 else 3
						shot_timer=0.3
		"saut":
			vel.y+=1200.0*delta
			position+=vel*delta
			position.x=clampf(position.x,arena_left+half.x,arena_right-half.x)
			if vel.y>0.0 and position.y>=feet_y:
				position.y=feet_y
				vel=Vector2.ZERO
				land_splash()
				state="attend"
				timer=0.6 if phase2 else 1.0
		"langue":
			timer-=delta
			var max_len:=220.0 if phase2 else 180.0
			if timer>0.0:
				shake=Vector2(randf_range(-1.5,1.5),0)
			elif timer>-0.25:
				tongue=move_toward(tongue,max_len,max_len*4.0*delta)
			elif timer>-0.4:
				pass
			else:
				tongue=move_toward(tongue,0.0,max_len*3.0*delta)
				if tongue<=0.0:
					state="attend"
					timer=0.7
		"crache":
			facing=1.0 if p.x>position.x else-1.0
			shot_timer-=delta
			if shot_timer<=0.0:
				shot_timer=0.35
				shots_left-=1
				var from_pos:=position+Vector2(facing*24.0,-4.0)
				var tt:=0.8+randf_range(-0.15,0.15)
				var aim:=p+Vector2(randf_range(-50,50),0)
				var v:=Vector2((aim.x-from_pos.x)/tt,(aim.y-from_pos.y-0.5*500.0*tt*tt)/tt)
				level.spawn_projectile(from_pos,v,"ennemi","poison")
				if shots_left<=0:
					state="attend"
					timer=0.8
func land_splash()->void:
	level.shake(8.0)
	level.fx.burst(Vector2(position.x,ground_y),18,150.0,Color(0.85,0.85,0.85),0.6,3.0,300.0,80.0)
	for d in[-1.0,1.0]:
		level.spawn_projectile(position+Vector2(d*20.0,-10.0),Vector2(d*120.0,-280.0),"ennemi","poison")
		if phase2:
			level.spawn_projectile(position+Vector2(d*20.0,-10.0),Vector2(d*220.0,-220.0),"ennemi","poison")
func segment_pos(i:int)->Vector2:
	if hist.is_empty():
		return position
	var idx:=maxi(0,hist.size()-1-i*4)
	return hist[idx]
func update_dragon(delta:float)->void:
	var p:Vector2=target.global_position
	var cx:=(arena_left+arena_right)*0.5
	var w:=(arena_right-arena_left)*0.38
	var goal:=Vector2(cx+sin(t*0.8)*w,120.0+sin(t*1.6)*45.0)
	match state:
		"intro":
			position=position.move_toward(goal,160.0*delta)
			if position.distance_to(goal)<10.0:
				state="vol"
				timer=2.5
		"vol":
			position=position.move_toward(goal,(220.0 if phase2 else 170.0)*delta)
			timer-=delta
			if timer<=0.0:
				attack_index+=1
				if attack_index%2==1:
					state="souffle"
					timer=0.7
					shots_left=1
				else:
					state="pique"
					dive_goal=p
		"souffle":
			timer-=delta
			shake=Vector2(randf_range(-1,1),randf_range(-1,1))
			if timer<0.35 and shots_left>0:
				shots_left=0
				var count:=5 if phase2 else 3
				var base:=(p-position).angle()
				for i in count:
					var a:=base+(i-(count-1)*0.5)*0.25
					level.spawn_projectile(position+Vector2(cos(base),sin(base))*16.0,Vector2(cos(a),sin(a))*190.0,"ennemi","flamme")
				level.shake(3.0)
			if timer<=0.0:
				state="vol"
				timer=1.6 if phase2 else 2.4
		"pique":
			position=position.move_toward(dive_goal,340.0*delta)
			if position.distance_to(dive_goal)<6.0 or position.y>ground_y-30.0:
				state="vol"
				timer=1.8 if phase2 else 2.6
				level.fx.burst(position,14,120.0,Color(0.85,0.85,0.85),0.5,3.0)
	shake=Vector2.ZERO if state!="souffle" else shake
	if hist.is_empty()or position.distance_to(hist[hist.size()-1])>3.0:
		hist.append(position)
		if hist.size()>60:
			hist.remove_at(0)
	var look_dir:=position-segment_pos(1)
	if absf(look_dir.x)>0.5:
		facing=signf(look_dir.x)
func update_roi(delta:float)->void:
	var p:Vector2=target.global_position
	shake=Vector2.ZERO
	facing=1.0 if p.x>position.x else-1.0
	match state:
		"intro":
			alpha=move_toward(alpha,1.0,delta*0.7)
			if alpha>=1.0:
				state="flotte"
				timer=1.5
		"flotte":
			timer-=delta
			position.y+=sin(t*2.5)*0.6
			if timer<=0.0:
				next_roi_attack()
		"eventail":
			timer-=delta
			if shots_left>0 and timer<=0.4:
				var count:=7 if phase2 else 5
				var base:=(p-position).angle()
				for i in count:
					var a:=base+(i-(count-1)*0.5)*0.22
					level.spawn_projectile(position+Vector2(0,-6),Vector2(cos(a),sin(a))*170.0,"ennemi","ombre")
				shots_left=0
				level.fx.ring(position,20.0,Color.WHITE,0.4)
			if timer<=0.0:
				state="flotte"
				timer=1.1 if phase2 else 1.7
		"disparait":
			alpha=move_toward(alpha,0.0,delta*3.0)
			if alpha<=0.0:
				var nx:=randf_range(arena_left+60.0,arena_right-60.0)
				for i in 6:
					if absf(nx-p.x)>160.0:
						break
					nx=randf_range(arena_left+60.0,arena_right-60.0)
				position=Vector2(nx,randf_range(150.0,220.0))
				state="apparait"
		"apparait":
			alpha=move_toward(alpha,1.0,delta*3.0)
			if alpha>=1.0:
				state="flotte"
				timer=0.8
		"invoque":
			timer-=delta
			shake=Vector2(randf_range(-2,2),randf_range(-2,2))
			if timer<=0.0:
				if level.count_enemies("chauve-souris")<4:
					for d in[-1.0,1.0]:
						var pos:=position+Vector2(d*40.0,-20.0)
						level.spawn_enemy("chauve-souris",pos)
						level.fx.burst(pos,12,90.0,Color.WHITE,0.4,2.5)
				state="flotte"
				timer=1.4
		"pluie":
			shot_timer-=delta
			if shot_timer<=0.0 and shots_left>0:
				shot_timer=0.15
				shots_left-=1
				level.spawn_projectile(Vector2(randf_range(arena_left+16.0,arena_right-16.0),70.0),Vector2(0,200.0),"ennemi","ombre")
			if shots_left<=0:
				state="flotte"
				timer=1.2
func next_roi_attack()->void:
	var cycle:=["eventail","disparait","invoque","eventail","disparait","pluie"]
	var choice:String=cycle[attack_index%cycle.size()]
	attack_index+=1
	if choice=="pluie" and not phase2:
		choice="eventail"
	state=choice
	match choice:
		"eventail":
			timer=0.9
			shots_left=1
		"invoque":
			timer=0.7
		"pluie":
			shots_left=12
			shot_timer=0.2
func _draw()->void:
	draw_set_transform(shake)
	match kind:
		"golem":
			draw_golem()
		"roi":
			draw_roi()
		"crapaud":
			draw_crapaud()
		"dragon":
			draw_dragon()
		_:
			draw_corbeau()
	draw_set_transform(Vector2.ZERO)
func main_color()->Color:
	return Color.WHITE if flash>0.0 else Color.BLACK
func line_color()->Color:
	return Color.BLACK if flash>0.0 else Color.WHITE
func outline(pts:PackedVector2Array,width:=2.0)->void:
	var closed:=pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed,line_color(),width)
func fill_ellipse(center:Vector2,rx:float,ry:float,color:Color)->void:
	var pts:=PackedVector2Array()
	for i in 24:
		var a:=TAU*i/24.0
		pts.append(center+Vector2(cos(a)*rx,sin(a)*ry))
	draw_colored_polygon(pts,color)
func draw_corbeau()->void:
	var flying:=state!="au_sol" and state!="pique"
	var flap:=sin(t*14.0)if flying else 0.0
	var f:=facing
	for side in[-1.0,1.0]:
		var wing:=PackedVector2Array()
		if state=="pique":
			wing=PackedVector2Array([Vector2(side*8,-6),Vector2(side*30,-26),Vector2(side*22,4),Vector2(side*10,8)])
		elif flying:
			wing=PackedVector2Array([Vector2(side*10,-6),Vector2(side*52,-6-flap*24.0),Vector2(side*40,8-flap*10.0),Vector2(side*26,4),Vector2(side*14,10)])
		else:
			wing=PackedVector2Array([Vector2(side*10,-8),Vector2(side*26,4),Vector2(side*18,14),Vector2(side*8,10)])
		draw_colored_polygon(wing,main_color())
		outline(wing)
	var tail:=PackedVector2Array([Vector2(-f*18,-4),Vector2(-f*40,-10),Vector2(-f*38,6),Vector2(-f*18,6)])
	draw_colored_polygon(tail,main_color())
	outline(tail)
	fill_ellipse(Vector2.ZERO,24.0,17.0,line_color())
	fill_ellipse(Vector2.ZERO,22.0,15.0,main_color())
	var head:=Vector2(f*22,-12)
	draw_circle(head,12.0,line_color())
	draw_circle(head,10.5,main_color())
	var beak:=PackedVector2Array([head+Vector2(f*8,-4),head+Vector2(f*24,2),head+Vector2(f*8,5)])
	draw_colored_polygon(beak,line_color())
	var eye:=head+Vector2(f*3,-3)
	draw_circle(eye,4.0 if phase2 else 3.0,line_color())
	draw_circle(eye+Vector2(f,0),1.5,main_color())
	if state=="au_sol":
		for side in[-1.0,1.0]:
			draw_line(Vector2(side*8,14),Vector2(side*8,22),line_color(),2.0)
		for k in 3:
			var a:=t*4.0+k*TAU/3.0
			var sp:=head+Vector2(cos(a)*16.0,-16.0+sin(a)*5.0)
			draw_line(sp-Vector2(3,0),sp+Vector2(3,0),Color.WHITE,1.5)
			draw_line(sp-Vector2(0,3),sp+Vector2(0,3),Color.WHITE,1.5)
func draw_golem()->void:
	var walk:=sin(t*6.0)if state=="marche" else 0.0
	var crouch:=6.0 if state=="saut_prep" or state=="repos" else 0.0
	var f:=facing
	var m:=main_color()
	var l:=line_color()
	for i in 2:
		var side:=-1.0 if i==0 else 1.0
		var lx:=side*12.0
		var ly:=20.0+walk*side*3.0
		var leg:=Rect2(lx-8,ly-4,16,18-maxf(0.0,walk*side*3.0))
		draw_rect(leg,m)
		draw_rect(leg,l,false,2.0)
	var body:=Rect2(-26,-22+crouch,52,44-crouch)
	draw_rect(body,m)
	draw_rect(body,l,false,2.0)
	draw_line(Vector2(-18,-14+crouch),Vector2(-8,-2),l,1.0)
	draw_line(Vector2(-8,-2),Vector2(-14,10),l,1.0)
	draw_line(Vector2(16,-10+crouch),Vector2(10,6),l,1.0)
	var rune:=PackedVector2Array([Vector2(0,-6+crouch),Vector2(6,2+crouch*0.5),Vector2(0,10),Vector2(-6,2+crouch*0.5)])
	draw_colored_polygon(rune,Color.WHITE if state!="repos" else Color(0.4,0.4,0.4))
	var head:=Rect2(-15+f*4,-40+crouch,30,20)
	draw_rect(head,m)
	draw_rect(head,l,false,2.0)
	var glow:=Color(0.35,0.35,0.35)if state=="repos" else Color.WHITE
	for k in[-1.0,1.0]:
		var e:=Vector2(f*4+k*7.0,-31+crouch)
		if state!="repos":
			draw_circle(e,5.0,Color(1,1,1,0.2))
		draw_rect(Rect2(e-Vector2(3,2),Vector2(6,4)),glow)
	for i in 2:
		var side:=-1.0 if i==0 else 1.0
		var shoulder:=Vector2(side*28.0,-14+crouch)
		var ang:=PI*0.5+walk*0.5*side
		if state=="lance" and side==f:
			ang=-PI*0.5+sin(t*12.0)*0.6
		var dir:=Vector2(cos(ang),sin(ang))
		var hand:=shoulder+dir*26.0
		draw_line(shoulder,hand,l,14.0)
		draw_line(shoulder,hand,m,10.0)
		draw_circle(hand,8.0,l)
		draw_circle(hand,6.5,m)
func draw_crapaud()->void:
	var m:=main_color()
	var l:=line_color()
	var f:=facing
	var crouch:=4.0 if state=="attend" and timer<0.3 else 0.0
	var air:=state=="saut" or state=="intro"
	for side in[-1.0,1.0]:
		var leg:=Vector2(side*22.0,12.0+crouch)
		if air:
			leg+=Vector2(side*8.0,8.0)
		fill_ellipse(leg,12.0,9.0,l)
		fill_ellipse(leg,10.5,7.5,m)
	fill_ellipse(Vector2(0,crouch),34.0,21.0-crouch*0.5,l)
	fill_ellipse(Vector2(0,crouch),32.0,19.5-crouch*0.5,m)
	fill_ellipse(Vector2(f*8.0,9.0+crouch),20.0,9.0,Color(0.85,0.85,0.85)if flash<=0.0 else Color.BLACK)
	for i in 5:
		draw_circle(Vector2(-f*(6.0+i*5.0)+sin(i*2.3)*4.0,-10.0+cos(i*1.7)*4.0+crouch),2.5,Color(1,1,1,0.25))
	var to_p:Vector2=(target.global_position-position).normalized()if target else Vector2.ZERO
	for k in[0.0,1.0]:
		var e:=Vector2(f*(6.0+k*14.0),-20.0+crouch)
		draw_circle(e,8.5,l)
		draw_circle(e,7.0,Color.WHITE if flash<=0.0 else Color.BLACK)
		draw_circle(e+to_p*2.5,3.5 if not phase2 else 4.5,Color.BLACK if flash<=0.0 else Color.WHITE)
		draw_circle(e+to_p*2.5+Vector2(-1,-1),1.0,Color.WHITE)
	var mouth:=tongue_mouth()-position+Vector2(0,crouch)
	if tongue>0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(f*6.0,-2.0+crouch),mouth+Vector2(f*4.0,-7.0),mouth+Vector2(f*4.0,7.0)]),Color.BLACK)
		var tip:=mouth+tongue_dir*tongue
		draw_line(mouth,tip,Color.BLACK,9.0)
		draw_line(mouth,tip,Color(0.95,0.45,0.55),6.0)
		draw_circle(tip,8.0,Color.BLACK)
		draw_circle(tip,6.5,Color(0.95,0.5,0.6))
	elif state=="langue" and timer>0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(f*6.0,-2.0+crouch),mouth+Vector2(f*4.0,-5.0),mouth+Vector2(f*4.0,5.0)]),Color.BLACK)
		var k:=1.0-timer/0.4
		draw_line(mouth,mouth+tongue_dir*200.0*k,Color(1,0.3,0.3,0.35),2.0)
	else:
		var smile:=PackedVector2Array()
		for i in 7:
			var k:=i/6.0
			smile.append(Vector2(f*(2.0+k*26.0),2.0+crouch+sin(k*PI)*3.0))
		draw_polyline(smile,l,2.0)
	for side in[0.0,1.0]:
		var hand:=Vector2(f*(14.0+side*10.0),20.0)
		draw_line(Vector2(f*(10.0+side*8.0),8.0+crouch),hand,l,6.0)
		draw_line(Vector2(f*(10.0+side*8.0),8.0+crouch),hand,m,3.5)
func draw_dragon()->void:
	var m:=main_color()
	var l:=line_color()
	for i in range(9,0,-1):
		var p:=segment_pos(i)-position
		var r:=11.0-i*0.6
		var nxt:=segment_pos(i-1)-position
		var dir:=(nxt-p).normalized()
		var n:=Vector2(-dir.y,dir.x)
		draw_colored_polygon(PackedVector2Array([p+n*(r-2.0)-dir*3.0,p-n*0.0+n*(r+7.0),p+n*(r-2.0)+dir*3.0]),Color.WHITE)
		draw_circle(p,r+1.5,l)
		draw_circle(p,r,m)
		draw_arc(p,r-3.0,n.angle()-0.8,n.angle()+0.8,6,Color(1,1,1,0.3),1.5)
		if i==9:
			draw_colored_polygon(PackedVector2Array([p-dir*4.0,p-dir*18.0+n*9.0,p-dir*12.0,p-dir*18.0-n*9.0]),Color.WHITE)
	var f:=facing
	var head:=PackedVector2Array([Vector2(-f*14.0,-10.0),Vector2(f*6.0,-12.0),Vector2(f*22.0,-4.0),Vector2(f*24.0,2.0),Vector2(f*8.0,4.0),Vector2(-f*12.0,8.0)])
	draw_colored_polygon(head,m)
	outline(head)
	var open:=8.0 if state=="souffle" else 2.0
	var jaw:=PackedVector2Array([Vector2(-f*8.0,6.0),Vector2(f*8.0,4.0),Vector2(f*20.0,4.0+open),Vector2(-f*4.0,12.0)])
	draw_colored_polygon(jaw,m)
	outline(jaw)
	if state=="souffle":
		draw_circle(Vector2(f*20.0,4.0),7.0,Color(1,1,1,0.6))
	for k in[0.0,1.0]:
		var base:=Vector2(-f*(6.0+k*6.0),-10.0)
		draw_colored_polygon(PackedVector2Array([base,base+Vector2(-f*16.0,-10.0+k*4.0),base+Vector2(-f*4.0,2.0)]),Color.WHITE)
	var eye:=Vector2(f*6.0,-5.0)
	draw_circle(eye,6.0,Color(1,1,1,0.2))
	draw_circle(eye,3.5,Color.WHITE)
	draw_line(eye+Vector2(0,-2.5),eye+Vector2(0,2.5),Color.BLACK,1.5)
	for k in[0.0,1.0]:
		var wh:=PackedVector2Array()
		for i in 6:
			var q:=i/5.0
			wh.append(Vector2(f*(18.0-q*26.0),2.0+k*3.0+q*10.0+sin(t*4.0+q*3.0+k)*3.0))
		draw_polyline(wh,Color(0.85,0.85,0.85),1.2)
func draw_roi()->void:
	var m:=main_color()
	var l:=line_color()
	if phase2:
		for k in 3:
			draw_arc(Vector2.ZERO,34.0+k*8.0+sin(t*6.0+k)*3.0,0.0,TAU,32,Color(1,1,1,0.15),2.0)
	var cape:=PackedVector2Array([Vector2(0,-30),Vector2(18,-16)])
	for i in 7:
		var x:=26.0-i*52.0/6.0
		var y:=34.0+(8.0 if i%2==0 else 0.0)+sin(t*4.0+i)*3.0
		cape.append(Vector2(x+sin(t*3.0+i)*2.0,y))
	cape.append(Vector2(-18,-16))
	draw_colored_polygon(cape,m)
	outline(cape)
	fill_ellipse(Vector2(0,-24),10.0,12.0,l)
	fill_ellipse(Vector2(0,-24),8.5,10.5,Color.WHITE if flash<=0.0 else Color.BLACK)
	for k in[-1.0,1.0]:
		var eye:=PackedVector2Array([Vector2(k*2,-27),Vector2(k*7,-29),Vector2(k*6,-24)])
		draw_colored_polygon(eye,Color.BLACK if flash<=0.0 else Color.WHITE)
	draw_line(Vector2(-3,-17),Vector2(3,-17),Color.BLACK,1.0)
	var crown:=PackedVector2Array([Vector2(-10,-34),Vector2(-10,-42),Vector2(-5,-37),Vector2(0,-46),Vector2(5,-37),Vector2(10,-42),Vector2(10,-34)])
	draw_colored_polygon(crown,Color.WHITE)
	draw_polyline(crown,Color.BLACK,1.0)
	for side in[-1.0,1.0]:
		var hand:=Vector2(side*26.0,2.0+sin(t*3.0+side)*4.0)
		draw_circle(hand,9.0,Color(1,1,1,0.15))
		draw_circle(hand,5.0,Color.WHITE)
		draw_circle(hand,2.5,Color.BLACK)
