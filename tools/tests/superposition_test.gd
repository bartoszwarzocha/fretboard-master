# Test superpozycji: godot --headless --path app -s ../tools/tests/superposition_test.gd
extends SceneTree

const STD := [64, 59, 55, 50, 45, 40]


func _pcs(root: int, steps: Array) -> Dictionary:
	var d := {}
	for s in steps:
		d[posmod(root + s, 12)] = true
	return d


func _show(name: String, v: Array) -> void:
	var t := ""
	for n in v:
		t += "%d/%d(%d) " % [6 - n.s, n.f, n.pos]
	print(name, " n=", v.size(), " shifts=", v[v.size() - 1].pos if v.size() else -1, " : ", t)


func _init() -> void:
	var minor := _pcs(4, [0, 2, 3, 5, 7, 8, 10])
	for case in [["Em 0-12", minor, 0, 12, ""], ["D dor 5-9", _pcs(2, [0, 2, 3, 5, 7, 9, 10]), 5, 9, ""],
			["Em 3nps 0-12", minor, 0, 12, "3nps"], ["Em 0-24", minor, 0, 24, ""], ["A min 5-17", _pcs(9, [0, 2, 3, 5, 7, 8, 10]), 5, 17, ""]]:
		var t0 := Time.get_ticks_usec()
		var vs := Superposition.variants(STD, case[1], case[2], case[3], case[4])
		print("--- ", case[0], ": ", vs.size(), " wariantów, ", (Time.get_ticks_usec() - t0) / 1000.0, " ms")
		for i in mini(vs.size(), 2):
			_show("  v%d" % (i + 1), vs[i])
	quit()
