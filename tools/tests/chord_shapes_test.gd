# Test chwytów: godot --headless --path app -s ../tools/tests/chord_shapes_test.gd
extends SceneTree

const STD := [64, 59, 55, 50, 45, 40]


func _init() -> void:
	for c in [["C", 0, [0, 4, 7]], ["G", 7, [0, 4, 7]], ["Am", 9, [0, 3, 7]], ["F", 5, [0, 4, 7]], ["Cmaj7", 0, [0, 4, 7, 11]], ["E7", 4, [0, 4, 7, 10]]]:
		var pcs := {}
		for i in c[2]:
			pcs[(c[1] + i) % 12] = true
		var t0 := Time.get_ticks_usec()
		var sh := ChordShapes.shapes(STD, 22, pcs, c[1], (c[1] + 7) % 12)
		print("--- ", c[0], ": ", sh.size(), " chwytów, ", (Time.get_ticks_usec() - t0) / 1000.0, " ms")
		for x in sh.slice(0, 6):
			var tab := ["x", "x", "x", "x", "x", "x"]
			for cell in x.cells:
				tab[5 - cell.s] = str(cell.f)
			print("   ", " ".join(tab), "  fret ", x.fret, "  barre ", x.barre)
	quit()
