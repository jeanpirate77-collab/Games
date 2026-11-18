extends Node
const GameData=preload("res://game_data.gd")
const RATE:=22050
const MUSIC_RATE:=12000
const SOUNDS:={
	"saut":[[0.14,300.0,620.0,0,0.18,0.0]],
	"double_saut":[[0.16,450.0,950.0,1,0.3,0.0]],
	"atterrir":[[0.07,140.0,60.0,2,0.4,0.5]],
	"coup":[[0.13,1800.0,300.0,2,0.22,1.0]],
	"touche":[[0.08,240.0,110.0,0,0.22,0.3]],
	"tue":[[0.05,600.0,900.0,0,0.2,0.0],[0.14,400.0,60.0,2,0.3,1.0]],
	"blesse":[[0.22,420.0,90.0,0,0.28,0.2]],
	"pistolet":[[0.11,2500.0,300.0,2,0.35,1.0]],
	"fusil":[[0.28,1600.0,80.0,2,0.5,1.0]],
	"arbalete":[[0.1,500.0,1000.0,1,0.25,0.1]],
	"feu":[[0.3,900.0,150.0,2,0.3,0.85]],
	"ruee":[[0.18,2000.0,600.0,2,0.22,1.0]],
	"ressort":[[0.32,180.0,900.0,2,0.35,0.0]],
	"piece":[[0.05,988.0,988.0,0,0.12,0.0],[0.13,1319.0,1319.0,0,0.12,0.0]],
	"tresor":[[0.06,784.0,784.0,1,0.25,0.0],[0.06,988.0,988.0,1,0.25,0.0],[0.06,1175.0,1175.0,1,0.25,0.0],[0.2,1568.0,1568.0,1,0.25,0.0]],
	"eclat":[[0.07,1047.0,1047.0,1,0.25,0.0],[0.07,1319.0,1319.0,1,0.25,0.0],[0.07,1568.0,1568.0,1,0.25,0.0],[0.25,2093.0,2093.0,1,0.25,0.0]],
	"coeur":[[0.08,523.0,523.0,1,0.3,0.0],[0.08,659.0,659.0,1,0.3,0.0],[0.18,784.0,784.0,1,0.3,0.0]],
	"caisse":[[0.16,500.0,60.0,2,0.4,1.0]],
	"explosion":[[0.7,300.0,30.0,2,0.55,1.0]],
	"canon":[[0.35,200.0,40.0,2,0.5,0.9]],
	"porte":[[0.12,523.0,523.0,0,0.15,0.0],[0.12,659.0,659.0,0,0.15,0.0],[0.12,784.0,784.0,0,0.15,0.0],[0.4,1047.0,1047.0,0,0.15,0.0]],
	"mort":[[0.16,400.0,380.0,0,0.2,0.0],[0.16,300.0,280.0,0,0.2,0.0],[0.45,200.0,70.0,0,0.2,0.0]],
	"point":[[0.1,659.0,659.0,2,0.35,0.0],[0.3,988.0,988.0,2,0.35,0.0]],
	"clic":[[0.04,1200.0,900.0,0,0.1,0.0]],
	"boss":[[0.9,140.0,55.0,0,0.35,0.5]],
	"plouf":[[0.3,1400.0,200.0,2,0.3,1.0]],
	"vent":[[0.4,300.0,500.0,2,0.12,1.0]],
}
static var cache:={}
static var music_cache:={}
var players:Array=[]
var next_player:=0
var music_player:AudioStreamPlayer
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p:=AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player=AudioStreamPlayer.new()
	music_player.volume_db=-9.0
	add_child(music_player)
func play(sound_name:String,pitch_jitter:=0.06,volume_db:=0.0)->void:
	if not GameData.sfx_on or not SOUNDS.has(sound_name):
		return
	var p:AudioStreamPlayer=players[next_player]
	next_player=(next_player+1)%players.size()
	p.stream=get_sound(sound_name)
	p.pitch_scale=1.0+randf_range(-pitch_jitter,pitch_jitter)
	p.volume_db=volume_db
	p.play()
func play_music(world:int,boss:bool)->void:
	if not GameData.music_on:
		music_player.stop()
		return
	var key:="%d_%s"%[world,"boss" if boss else "niveau"]
	if not music_cache.has(key):
		music_cache[key]=make_music(world,boss)
	music_player.stream=music_cache[key]
	music_player.play()
func stop_music()->void:
	music_player.stop()
static func get_sound(sound_name:String)->AudioStreamWAV:
	if not cache.has(sound_name):
		cache[sound_name]=make_sound(sound_name)
	return cache[sound_name]
static func make_sound(sound_name:String)->AudioStreamWAV:
	var segs:Array=SOUNDS[sound_name]
	var total:=0
	for sg in segs:
		total+=int(float(sg[0])*RATE)
	var data:=PackedByteArray()
	data.resize(total*2)
	var idx:=0
	var phase:=0.0
	var noise_t:=0.0
	var noise_val:=0.0
	for sg in segs:
		var count:=int(float(sg[0])*RATE)
		var f0:float=sg[1]
		var f1:float=sg[2]
		var wave:int=sg[3]
		var vol:float=sg[4]
		var nmix:float=sg[5]
		var attack:=0.004*RATE
		for i in count:
			var k:=float(i)/count
			var f:=lerpf(f0,f1,k)
			phase=fmod(phase+f/RATE,1.0)
			var v:=0.0
			match wave:
				0:
					v=1.0 if phase<0.5 else-1.0
				1:
					v=4.0*absf(phase-0.5)-1.0
				_:
					v=sin(phase*TAU)
			noise_t+=f/RATE
			if noise_t>=1.0:
				noise_t-=1.0
				noise_val=randf_range(-1.0,1.0)
			v=lerpf(v,noise_val,nmix)
			var env:=minf(1.0,i/attack)*pow(1.0-k,1.6)
			data.encode_s16(idx*2,int(clampf(v*vol*env,-1.0,1.0)*32767.0))
			idx+=1
	var wav:=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=RATE
	wav.stereo=false
	wav.data=data
	return wav
static func tri(x:float)->float:
	return 4.0*absf(fmod(x,1.0)-0.5)-1.0
static func make_music(world:int,boss:bool)->AudioStreamWAV:
	var roots:=[220.0,196.0,246.9,261.6,174.6]
	var root:float=roots[clampi(world,0,roots.size()-1)]
	var step:=0.2 if boss else 0.3
	var chords:=[[0,3,7],[-4,0,3],[3,7,10],[-2,2,5]]
	if boss:
		chords=[[0,3,7],[1,5,8],[0,3,7],[-1,2,6]]
	var pattern:=[0,1,2,1,0,2,1,2]
	var steps_per_chord:=8
	var spn:=int(step*MUSIC_RATE)
	var total_steps:int=chords.size()*steps_per_chord
	var total:=spn*total_steps
	var data:=PackedByteArray()
	data.resize(total*2)
	var idx:=0
	for st in total_steps:
		var chord:Array=chords[floori(st/float(steps_per_chord))]
		var semi:int=chord[pattern[st%8]]+12
		if st%8==7 and not boss:
			semi+=12
		var f_arp:=root*pow(2.0,semi/12.0)
		var f_bass:=root*pow(2.0,(int(chord[0])-12)/12.0)
		var f_p1:=root*pow(2.0,int(chord[0])/12.0)
		var f_p2:=root*pow(2.0,int(chord[1])/12.0)
		var f_p3:=root*pow(2.0,int(chord[2])/12.0)
		for i in spn:
			var tt:=float(i)/MUSIC_RATE
			var g:=float(idx)/MUSIC_RATE
			var chord_k:=float((st%steps_per_chord)*spn+i)/(steps_per_chord*spn)
			var arp:=tri(f_arp*tt)*exp(-tt*7.0)*minf(1.0,tt*300.0)*0.16
			var bass:=sin(TAU*f_bass*g)*0.17*(1.0-chord_k*0.5)
			var pad:=(sin(TAU*f_p1*g)+sin(TAU*f_p2*g)+sin(TAU*f_p3*g))*0.035*(0.75+0.25*sin(g*1.7))
			var drum:=0.0
			if boss and st%2==0:
				drum=sin(TAU*55.0*tt*(1.0+exp(-tt*30.0)))*exp(-tt*18.0)*0.35
			elif not boss and st%4==0:
				drum=sin(TAU*50.0*tt)*exp(-tt*14.0)*0.18
			data.encode_s16(idx*2,int(clampf(arp+bass+pad+drum,-1.0,1.0)*32767.0))
			idx+=1
	var wav:=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=MUSIC_RATE
	wav.stereo=false
	wav.data=data
	wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin=0
	wav.loop_end=total
	return wav
