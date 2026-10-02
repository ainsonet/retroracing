extends SceneTree

func _init():
    var a = ResourceLoader.exists("res://logo_transparent.png")
    var b = load("res://logo_transparent.png") != null
    var f = FileAccess.open("res://res_test_out.txt", FileAccess.WRITE)
    f.store_string("EXISTS: " + str(a) + "\nLOADABLE: " + str(b))
    f.close()
    quit()
