extends RefCounted
const PATH:="res://niveaux.txt"
static var cache:Array=[]
static func all()->Array:
	if cache.is_empty():
		load_levels()
	return cache
static func load_levels()->void:
	var f:=FileAccess.open(PATH,FileAccess.READ)
	if f==null:
		push_error("Fichier introuvable : "+PATH)
		return
	var current:Dictionary={}
	while not f.eof_reached():
		var line:=f.get_line().strip_edges(false,true)
		if line.begins_with("==="):
			var parts:=line.substr(3).strip_edges().split("|")
			current={
				"nom":parts[0],
				"monde":int(parts[1])if parts.size()>1 else 0,
				"boss":parts[2]if parts.size()>2 else "",
				"carte":[],
			}
			cache.append(current)
		elif current.is_empty()or line=="":
			continue
		else:
			current["carte"].append(line)
