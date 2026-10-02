extends Node2D

var screen_w = 1024.0
var screen_h = 768.0

var lines = []
var N = 0
var pos = 0.0
var player_x = 0.0
var speed = 0.0
var score = 0.0
var gear_ui_x = 44.0
var gear_ui_y = 132.0
var speed_ui_x = 145.0
var speed_ui_y = 84.0

var car_tex: Texture2D
var traffic_textures = []
var city_tex: Texture2D
var grass_tuft_tex: Texture2D
var dashboard_tex: Texture2D
var score_panel_tex: Texture2D
var explosion_tex: Texture2D
var game_over: bool = false
var game_over_timer: float = 0.0
var reverse_timer: float = 0.0
var retro_font: Font
var engine_player: AudioStreamPlayer
var crash_player: AudioStreamPlayer
var skid_player: AudioStreamPlayer
var bump_player: AudioStreamPlayer
var pass_player: AudioStreamPlayer
var hazard_player: AudioStreamPlayer
var music_player_1: AudioStreamPlayer
var music_player_2: AudioStreamPlayer
var active_music_player: int = 1
var music_fade_time: float = 3.0
var current_target_track: AudioStream
var menu_track: AudioStream
var play_track: AudioStream
var music_crossfading: bool = false
var music_fade_progress: float = 0.0
var pass_cooldown: float = 0.0
var game_over_triggered: bool = false

# Upgrade System
var upgrade_options = [
	{"title": "TOP SPEED", "desc": "Max speed +5%", "type": "max_speed"},
	{"title": "ACCELERATION", "desc": "Accel +10%", "type": "accel"},
	{"title": "HANDLING", "desc": "Steering +10%", "type": "handling"},
	{"title": "BRAKES", "desc": "Braking +10%", "type": "brake"},
	{"title": "CLEAR ROAD", "desc": "Remove 3 cars", "type": "traffic"},
	{"title": "OFF-ROAD", "desc": "Dirt speed +10%", "type": "offroad"},
	{"title": "SCORE BONUS", "desc": "+5% Score Gain", "type": "score_mult"},
	{"title": "GHOST SHIELD", "desc": "Saves from 1 fatal crash", "type": "shield"},
	{"title": "LUCKY COIN", "desc": "Instant +300 Score", "type": "instant_score"},
	{"title": "CALM TRAFFIC", "desc": "Traffic -15% lane shifts", "type": "calm_traffic"}
]
var current_upgrades = []
var upgrade_selection = 0
var next_upgrade_score = 1000
var max_speed = 30000.0
var accel = 10000.0
var brake = 12000.0
var handling = 3.0
var offroad_speed = 8000.0
var score_multiplier = 1.0
var shields = 0
var traffic_calmness = 1.0

func load_mp3(path: String, loop: bool = false) -> AudioStreamMP3:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var stream = AudioStreamMP3.new()
	stream.data = file.get_buffer(file.get_length())
	stream.loop = loop
	return stream

var score_ui_x = 55.0
var score_ui_y = 88.0
var vegetation_sprites = []
var building_sprites = []

var bg_offset = 0.0

class TrafficCar:
	var z: float = 0.0
	var x: float = 0.0
	var speed: float = 0.0
	var base_speed: float = 0.0
	var target_x: float = 0.0
	var changing_lane: bool = false
	var lane_change_cooldown: float = 0.0
	var blink_timer: float = 0.0
	var tex: Texture2D
	var phys_w: float = 600000.0

var traffic = []

class Line:
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var X: float = 0.0
	var Y: float = 0.0
	var W: float = 0.0
	var curve: float = 0.0
	var scale: float = 0.0
	
	# Объекты растительности (деревья, кактусы)
	var trees = []
	
	# Травинки (массив X-оффсетов)
	var tufts = []
	
	# Машины трафика на этой линии
	var cars = []

	func project(cam_x: float, cam_y: float, cam_z: float, scr_w: float, scr_h: float):
		scale = 0.84 / max((z - cam_z), 0.1)
		X = (1.0 + scale * (x - cam_x)) * scr_w / 2.0
		Y = (1.0 - scale * (y - cam_y)) * scr_h / 2.0
		# Расширили дорогу с 2000 до 3000
		W = scale * 3000.0 * scr_w / 2.0

func load_image_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null

var saved_player_name: String = ""
var can_submit_name: bool = false
var local_high_score: int = 0
var game_state: String = "MENU" # MENU, NAME_INPUT, LEADERBOARD, PLAYING, GAME_OVER
var logo_tex: Texture2D
var menu_selection: int = 0 # 0=PLAY, 1=LEADERBOARD, 2=CHANGE NAME, 3=QUIT
var settings_selection: int = 0
var current_res_idx: int = 0
var master_volume: float = 100.0
var music_on: bool = true
var resolutions_list = ["1024x768", "1280x720", "1920x1080", "FULLSCREEN"]
var name_input: LineEdit
var score_submitted = false
var leaderboard_data = []
var fetching_leaderboard = false
var post_request: HTTPRequest
var get_request: HTTPRequest

func _ready():
	var wasd = {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}
	for action in wasd:
		var ev = InputEventKey.new()
		ev.physical_keycode = wasd[action]
		InputMap.action_add_event(action, ev)
	
	
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "ENTER NAME"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.max_length = 10
	name_input.visible = false
	name_input.text_submitted.connect(_on_name_submitted)
	add_child(name_input)
	
	post_request = HTTPRequest.new()
	post_request.request_completed.connect(_on_post_completed)
	add_child(post_request)
	get_request = HTTPRequest.new()
	get_request.request_completed.connect(_on_scores_received)
	add_child(get_request)
	
	var cfg = ConfigFile.new()
	if cfg.load("user://retro_racing_save.cfg") == OK:
		saved_player_name = cfg.get_value("Player", "name", "")
		local_high_score = cfg.get_value("Player", "high_score", 0)
		master_volume = cfg.get_value('Settings', 'volume', 100.0)
		music_on = cfg.get_value('Settings', 'music', true)
		current_res_idx = cfg.get_value('Settings', 'resolution', 0)
		_apply_settings()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car_tex = load_image_texture("res://vehicles/car.png")
	
	# Динамически загружаем все 30 вариантов машин из папки

	
	var dir = DirAccess.open("res://vehicles")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".png"):
				traffic_textures.append(load_image_texture("res://vehicles/" + file))
				
	city_tex = load_image_texture("res://city.png")
	grass_tuft_tex = load_image_texture("res://nature/grass_tuft.png")
	if FileAccess.file_exists("res://dashboard.png"):
		dashboard_tex = load_image_texture("res://dashboard.png")
	if FileAccess.file_exists("res://score_panel.png"):
		score_panel_tex = load_image_texture("res://score_panel.png")
	if FileAccess.file_exists("res://explosion.png"):
		explosion_tex = load_image_texture("res://explosion.png")
	
	vegetation_sprites.clear()
	var nature_dir = DirAccess.open("res://nature")
	if nature_dir:
		for file in nature_dir.get_files():
			if file.ends_with(".png") and not "grass_tuft" in file:
				var tex = load_image_texture("res://nature/" + file)
				var phys_w = 600000.0
				if "boulder" in file or "rock" in file: phys_w = 500000.0
				elif "bush" in file: phys_w = 350000.0
				elif "cactus" in file: phys_w = 250000.0
				elif "tree" in file or "pine" in file: phys_w = 900000.0
				vegetation_sprites.append({"tex": tex, "phys_w": phys_w})
	
	var start_player = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://logo_transparent.png"):
		logo_tex = load_image_texture("res://logo_transparent.png")
	start_player.stream = load_mp3("res://engine-start.mp3", false)
	add_child(start_player)
	start_player.play()

	engine_player = AudioStreamPlayer.new()
	engine_player.stream = load_mp3("res://continuous-ringing-sound-of-a-running-motor.mp3", true)
	add_child(engine_player)
	
	crash_player = AudioStreamPlayer.new()
	crash_player.stream = load_mp3("res://noisy-meteorite-explosion.mp3", false)
	crash_player.volume_db = 5.0
	add_child(crash_player)
	
	skid_player = AudioStreamPlayer.new()
	skid_player.stream = load_mp3("res://cartoon-car-skid-sound.mp3", false)
	add_child(skid_player)
	
	bump_player = AudioStreamPlayer.new()
	bump_player.stream = load_mp3("res://the-sound-of-a-car-crash-the-car-carried-into-the-oncoming-lane.mp3", false)
	add_child(bump_player)
	
	pass_player = AudioStreamPlayer.new()
	pass_player.stream = load_mp3("res://porsche-car-overtaking-other-cars-on-the-track.mp3", false)
	add_child(pass_player)
	

	
	menu_track = load_mp3("res://synthwave--smooth-cruise-96272.mp3", false)
	play_track = load_mp3("res://synthwave--warm-retro-96270.mp3", false)
	current_target_track = menu_track
	
	music_player_1 = AudioStreamPlayer.new()
	music_player_1.stream = current_target_track
	music_player_1.volume_db = 8.0
	add_child(music_player_1)
	
	music_player_2 = AudioStreamPlayer.new()
	music_player_2.stream = current_target_track
	music_player_2.volume_db = -80.0
	add_child(music_player_2)
	
	if music_on:
		music_player_1.play()

	var buildings_dir = DirAccess.open("res://buildings")
	if buildings_dir:
		for file in buildings_dir.get_files():
			if file.ends_with(".png"):
				var tex = load_image_texture("res://buildings/" + file)
				var phys_w = 2000000.0
				var b_type = "house"
				if "gas" in file: 
					phys_w = 3000000.0
					b_type = "gas"
				elif "cafe" in file or "diner" in file:
					b_type = "cafe"
				building_sprites.append({"tex": tex, "phys_w": phys_w, "type": b_type})
				if "house" in file:
					for k in range(8):
						building_sprites.append({"tex": tex, "phys_w": phys_w, "type": b_type})
				
	var building_cooldown = 0
	var commercial_cooldown = 0
	for i in range(2000):
		var line = Line.new()
		if building_cooldown > 0: building_cooldown -= 1
		if commercial_cooldown > 0: commercial_cooldown -= 1
		line.z = i * 200.0
		
		if i > 50 and i < 200: line.curve = 1.5
		elif i > 250 and i < 400: line.curve = -2.0
		elif i > 500 and i < 700: line.curve = 2.5
		elif i > 800 and i < 900: line.curve = -3.0
		elif i > 1000 and i < 1400: line.curve = 1.0
		elif i > 1500 and i < 1800: line.curve = -1.5
		
		# Добавляем лес (деревья, кусты, кактусы раскиданы по всему полю)
		if building_sprites.size() > 0 and building_cooldown == 0 and randf() < 0.20:
			var b_dict = building_sprites[randi() % building_sprites.size()]
			var is_commercial = b_dict.get("type", "") in ["gas", "cafe"]
			if is_commercial and commercial_cooldown > 0:
				for cb in building_sprites:
					if cb.get("type", "") == "house":
						b_dict = cb
						is_commercial = false
						break
			
			if is_commercial:
				commercial_cooldown = randi() % 100 + 100
				building_cooldown = randi() % 20 + 20
			else:
				building_cooldown = randi() % 4 + 6 # Reduced cooldown for more houses!
			
			var side = 1.0 if randi() % 2 == 0 else -1.0
			var b_tx = 0.0
			if is_commercial:
				b_tx = side * randf_range(2.0, 3.5)
			else:
				b_tx = side * randf_range(3.5, 35.0) # Huge scatter range!
				
				# 30% chance to spawn a second house on the opposite side to make it look like a dense street!
				if randf() < 0.3:
					var side2 = -side
					var b_tx2 = side2 * randf_range(3.5, 35.0)
					line.trees.append({"tex": b_dict, "x": b_tx2})
			line.trees.append({"tex": b_dict, "x": b_tx})
			var num_trees = randi() % 3
			for j in range(num_trees):
				if vegetation_sprites.size() == 0: break
				var tx = -sign(b_tx) * randf_range(1.5, 20.0)
				var tex_dict = vegetation_sprites[randi() % vegetation_sprites.size()]
				line.trees.append({"tex": tex_dict, "x": tx})
		else:
			var num_trees = randi() % 6
			for j in range(num_trees):
				var tx = randf_range(1.5, 20.0)
				if randi() % 2 == 0: tx = -tx
				if vegetation_sprites.size() > 0:
					var tex_dict = vegetation_sprites[randi() % vegetation_sprites.size()]
					line.trees.append({"tex": tex_dict, "x": tx})
			
		# Добавляем пучки травы (очень густо по всему полю)
		var num_tufts = randi() % 12 + 2
		for j in range(num_tufts):
			var tuft_x = randf_range(1.2, 25.0)
			if randi() % 2 == 0: tuft_x = -tuft_x
			line.tufts.append(tuft_x)
		
		# Сортируем объекты на сегменте: сначала дальние от центра дороги (чтобы они перекрывались ближними)
		line.trees.sort_custom(func(a, b): return abs(a["x"]) > abs(b["x"]))
		line.tufts.sort_custom(func(a, b): return abs(a) > abs(b))
		
		lines.append(line)
	
	N = lines.size()
	
	# Создаем трафик

	


func _process(delta):
	if retro_font == null and FileAccess.file_exists("res://PressStart2P.ttf"):
		retro_font = load("res://PressStart2P.ttf")
	pass # Initialized in _ready
		

	
	if hazard_player == null and FileAccess.file_exists("res://the-sound-of-turn-signals-that-happens-when-you-sit-inside-the-car-chevrolet-cavalier.mp3"):
		hazard_player = AudioStreamPlayer.new()
		hazard_player.stream = load_mp3("res://the-sound-of-turn-signals-that-happens-when-you-sit-inside-the-car-chevrolet-cavalier.mp3", true)
		hazard_player.volume_db = 24.0
		add_child(hazard_player)
	
	if pass_player == null and FileAccess.file_exists("res://porsche-car-overtaking-other-cars-on-the-track.mp3"):
		pass_player = AudioStreamPlayer.new()
		pass_player.stream = load_mp3("res://porsche-car-overtaking-other-cars-on-the-track.mp3", false)
		add_child(pass_player)
	
	if explosion_tex == null and FileAccess.file_exists("res://explosion.png"):
		explosion_tex = load_image_texture("res://explosion.png")
	if logo_tex == null and FileAccess.file_exists("res://logo_transparent.png"):
		logo_tex = load_image_texture("res://logo_transparent.png")
	
	if game_state == "MENU":
		speed = 15000.0
		engine_player.pitch_scale = 1.0
		player_x = sin(Time.get_ticks_msec() / 1000.0) * 0.5
		if Input.is_action_just_pressed("ui_down"): menu_selection = (menu_selection + 1) % 5
		if Input.is_action_just_pressed("ui_up"): menu_selection = (menu_selection - 1 + 5) % 5
		if Input.is_action_just_pressed("ui_accept"):
			if menu_selection == 0:
				if saved_player_name == "":
					game_state = "NAME_INPUT"
					name_input.text = saved_player_name
					name_input.visible = true
					name_input.grab_focus()
					can_submit_name = false
					get_tree().create_timer(0.3).timeout.connect(func(): can_submit_name = true)
				else:
					game_state = "PLAYING"
					score = 0
					player_x = 0
					pos = 0.0
					game_over = false
					game_over_timer = 0.0
					max_speed = 30000.0
					accel = 10000.0
					brake = 12000.0
					handling = 3.0
					offroad_speed = 8000.0
					score_multiplier = 1.0
					shields = 0
					traffic_calmness = 1.0
					next_upgrade_score = 1000
					game_over_triggered = false
					traffic.clear()
					for i in range(50):
						var car = TrafficCar.new()
						car.z = randf_range(10000.0, 3000.0 * 200.0)
						var lane = randi() % 3
						if lane == 0: car.x = -0.6
						elif lane == 1: car.x = 0.0
						else: car.x = 0.6
						car.base_speed = randf_range(5000.0, 12000.0)
						car.target_x = car.x
						car.speed = car.base_speed
						if traffic_textures.size() > 0:
							car.tex = traffic_textures[randi() % traffic_textures.size()]
						traffic.append(car)
					if not engine_player.playing: engine_player.play()
			elif menu_selection == 1:
				game_state = "LEADERBOARD"
				fetching_leaderboard = true
				var get_headers = PackedStringArray(["x-api-key: WHBtgRmJmv6dCmu4NeXhp4EL5kJar98N1LWwoot1"])
				get_request.request("https://api.silentwolf.com/get_top_scores/retroracing?version=0.0.0&max=50&ldboard_name=main&period_offset=0", get_headers, HTTPClient.METHOD_GET)
			elif menu_selection == 2:
				game_state = "NAME_INPUT"
				name_input.text = saved_player_name
				name_input.visible = true
				name_input.grab_focus()
				can_submit_name = false
				get_tree().create_timer(0.3).timeout.connect(func(): can_submit_name = true)
			elif menu_selection == 3:
				game_state = "SETTINGS"
			elif menu_selection == 4:
				get_tree().quit()
				
	elif game_state == "SETTINGS":
		speed = 15000.0
		player_x = sin(Time.get_ticks_msec() / 1000.0) * 0.5
		if Input.is_action_just_pressed("ui_down"): settings_selection = (settings_selection + 1) % 5
		if Input.is_action_just_pressed("ui_up"): settings_selection = (settings_selection - 1 + 5) % 5
		
		if settings_selection == 0:
			if Input.is_action_just_pressed("ui_right"): 
				current_res_idx = (current_res_idx + 1) % 4
				_apply_settings()
			if Input.is_action_just_pressed("ui_left"): 
				current_res_idx = (current_res_idx - 1 + 4) % 4
				_apply_settings()
		elif settings_selection == 1:
			if Input.is_action_pressed("ui_right"): 
				master_volume = min(100.0, master_volume + 1.0)
				AudioServer.set_bus_volume_db(0, linear_to_db(master_volume / 100.0))
			if Input.is_action_pressed("ui_left"): 
				master_volume = max(0.0, master_volume - 1.0)
				AudioServer.set_bus_volume_db(0, linear_to_db(master_volume / 100.0))
		elif settings_selection == 2:
			if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_left"):
				music_on = not music_on
				if music_on:
					if active_music_player == 1: music_player_1.play()
					else: music_player_2.play()
				else:
					music_player_1.stop()
					music_player_2.stop()
		
		if Input.is_physical_key_pressed(KEY_ESCAPE) or (settings_selection == 4 and Input.is_action_just_pressed("ui_accept")):
			game_state = "MENU"
			var cfg = ConfigFile.new()
			if cfg.load("user://retro_racing_save.cfg") == OK: pass
			cfg.set_value("Settings", "volume", master_volume)
			cfg.set_value("Settings", "resolution", current_res_idx)
			cfg.set_value("Settings", "music", music_on)
			cfg.save("user://retro_racing_save.cfg")
			
		if settings_selection == 3 and Input.is_action_just_pressed("ui_accept"):
			game_state = "ABOUT"
			return
			

	elif game_state == "ABOUT":
		if Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_ESCAPE):
			game_state = "SETTINGS"
			
	elif game_state == "NAME_INPUT":
		speed = 15000.0
		player_x = sin(Time.get_ticks_msec() / 1000.0) * 0.5
		if Input.is_physical_key_pressed(KEY_SPACE):
			game_state = "MENU"
			name_input.visible = false
			name_input.release_focus()
		
	elif game_state == "LEADERBOARD":
		speed = 15000.0
		player_x = sin(Time.get_ticks_msec() / 1000.0) * 0.5
		if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_action_just_pressed("ui_accept"):
			game_state = "MENU"
			var active_mp = music_player_1 if active_music_player == 1 else music_player_2
			if music_on and not active_mp.playing: active_mp.play()
			
	elif game_state == "UPGRADE":
		if Input.is_action_just_pressed("ui_left"): upgrade_selection = (upgrade_selection - 1 + 3) % 3
		if Input.is_action_just_pressed("ui_right"): upgrade_selection = (upgrade_selection + 1) % 3
		if Input.is_action_just_pressed("ui_accept"):
			var choice = current_upgrades[upgrade_selection]
			if choice["type"] == "max_speed": max_speed *= 1.05
			elif choice["type"] == "accel": accel *= 1.1
			elif choice["type"] == "handling": handling *= 1.1
			elif choice["type"] == "brake": brake *= 1.1
			elif choice["type"] == "offroad": offroad_speed *= 1.1
			elif choice["type"] == "score_mult": score_multiplier *= 1.05
			elif choice["type"] == "shield": shields += 1
			elif choice["type"] == "instant_score": score += 300.0
			elif choice["type"] == "calm_traffic": traffic_calmness *= 1.15
			elif choice["type"] == "traffic":
				for i in range(min(3, traffic.size())): traffic.remove_at(randi() % traffic.size())
			game_state = "PLAYING"
			engine_player.play()
	
	elif game_state == "PAUSED":
		if Input.is_action_just_pressed("ui_accept"):
			game_state = "PLAYING"
			if hazard_player: hazard_player.stop()
			engine_player.play()
		elif Input.is_action_just_pressed("ui_cancel") or Input.is_physical_key_pressed(KEY_ESCAPE):
			# If pressed again, maybe go to menu? Or wait, just ESC to resume.
			# To avoid instant resume if holding ESC, we do it carefully, but it's fine.
			pass # We'll just let UI accept (SPACE/ENTER) resume, and maybe ESC to return to menu!
			
		# Wait, let's implement M to Menu, Space to Resume!
		if Input.is_physical_key_pressed(KEY_M):
			game_state = "MENU"
			if hazard_player: hazard_player.stop()
			traffic.clear()
			speed = 0.0
			
	elif game_state == "GAME_OVER":
		game_over_timer += delta
		speed = 0.0
		if not game_over_triggered:
			game_over_triggered = true
			engine_player.stop()
			if int(score) > local_high_score:
				local_high_score = int(score)
				var cfg = ConfigFile.new()
				if cfg.load("user://retro_racing_save.cfg") == OK: pass
				cfg.set_value("Player", "high_score", local_high_score)
				cfg.save("user://retro_racing_save.cfg")
			music_player_1.stop()
			music_player_2.stop()
			crash_player.play()
		if game_over_timer > 1.0:
			if not score_submitted:
				if saved_player_name == "":
					if not name_input.visible:
						name_input.visible = true
						name_input.grab_focus()
						can_submit_name = false
						get_tree().create_timer(0.3).timeout.connect(func(): can_submit_name = true)
				else:
					if Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE):
						score_submitted = true
						fetching_leaderboard = true
						_submit_score()
			
			if Input.is_physical_key_pressed(KEY_ESCAPE):
				game_state = "MENU"
				var active_mp = music_player_1 if active_music_player == 1 else music_player_2
				if music_on and not active_mp.playing: active_mp.play()
				game_over = false
				game_over_timer = 0.0
				game_over_triggered = false
				traffic.clear()
				score_submitted = false
				name_input.visible = false
			elif score_submitted and not fetching_leaderboard:
				if Input.is_action_just_pressed("ui_accept"):
					game_state = "MENU"
					var active_mp = music_player_1 if active_music_player == 1 else music_player_2
					if music_on and not active_mp.playing: active_mp.play()
					game_over = false
					game_over_timer = 0.0
					max_speed = 30000.0
					accel = 10000.0
					brake = 12000.0
					handling = 3.0
					offroad_speed = 8000.0
					score_multiplier = 1.0
					shields = 0
					traffic_calmness = 1.0
					next_upgrade_score = 1000
					game_over_triggered = false
					traffic.clear()
					score_submitted = false
					name_input.visible = false
	elif game_state == "PLAYING":
		if Input.is_physical_key_pressed(KEY_ESCAPE):
			game_state = "PAUSED"
			engine_player.stop()
			if hazard_player: hazard_player.play()
		
		engine_player.pitch_scale = 0.8 + (abs(speed) / 30000.0) * 1.0
		if Input.is_action_pressed("ui_up"): speed += accel * delta
		elif Input.is_action_pressed("ui_down"):
			speed -= brake * delta
			if speed > 20000.0 and not skid_player.playing:
				skid_player.play()
		else:
			if speed > 0: speed = max(0.0, speed - 4000 * delta)
			elif speed < 0: speed = min(0.0, speed + 4000 * delta)
		
		speed = clamp(speed, -8000.0, max_speed)
	
	pass_cooldown -= delta
	
	if speed < -100.0:
		reverse_timer += delta
	else:
		reverse_timer = max(0.0, reverse_timer - delta * 2.0)
	
	if reverse_timer > 4.0:
		speed = max(0.0, speed)
	
	if speed > 0:
		score += (speed / 10000.0) * delta * 20.0 * score_multiplier
	
	if game_state == "PLAYING" and int(score) >= next_upgrade_score:
		next_upgrade_score += 1000
		game_state = "UPGRADE"
		engine_player.stop()
		current_upgrades.clear()
		var pool = upgrade_options.duplicate()
		pool.shuffle()
		for i in range(3): current_upgrades.append(pool[i])
		upgrade_selection = 0
		
	


	


	if music_on and music_player_1 and music_player_2 and game_state != "GAME_OVER":
		var desired_track = play_track if game_state == "PLAYING" else menu_track
		var mp_active = music_player_1 if active_music_player == 1 else music_player_2
		var mp_standby = music_player_2 if active_music_player == 1 else music_player_1
		
		var length = mp_active.stream.get_length() if mp_active.stream else 0.0
		var p = mp_active.get_playback_position()
		
		if current_target_track != desired_track:
			current_target_track = desired_track
			mp_standby.stream = desired_track
			mp_standby.volume_db = -80.0
			mp_standby.play()
			music_crossfading = true
			music_fade_progress = 0.0
		elif mp_active.playing and length - p < music_fade_time and not music_crossfading:
			mp_standby.stream = desired_track
			mp_standby.volume_db = -80.0
			mp_standby.play()
			music_crossfading = true
			music_fade_progress = 0.0
			
		if music_crossfading:
			music_fade_progress += delta / music_fade_time
			if music_fade_progress >= 1.0:
				music_fade_progress = 1.0
				mp_active.stop()
				active_music_player = 2 if active_music_player == 1 else 1
				music_crossfading = false
			
			mp_active.volume_db = lerp(8.0, -80.0, music_fade_progress)
			mp_standby.volume_db = lerp(-80.0, 8.0, music_fade_progress)
		else:
			if mp_active.playing:
				mp_active.volume_db = lerp(mp_active.volume_db, 8.0, 5.0 * delta)

	if game_state not in ["PAUSED", "UPGRADE"]:
		pos += speed * delta
	
	while pos >= N * 200.0: pos -= N * 200.0
	while pos < 0: pos += N * 200.0
	
	var start_pos = int(pos / 200.0) % N
	
	if speed != 0:
		var current_curve = lines[start_pos].curve
		# Отключаем центробежную силу, чтобы машина идеально "держала полосу"
		# player_x -= current_curve * (speed / 20000.0) * delta * 0.8
		
		# Смещение фона при повороте (оставляем, так как камера все еще поворачивается)
		if game_state not in ["PAUSED", "UPGRADE"]: bg_offset += current_curve * (speed / 20000.0) * delta * 150.0
	
	if game_state == "PLAYING":
		if Input.is_action_pressed("ui_left"): player_x -= handling * delta * (speed / 20000.0)
		if Input.is_action_pressed("ui_right"): player_x += handling * delta * (speed / 20000.0)
		player_x = clamp(player_x, -3.0, 3.0)
	
	# Очищаем массивы машин на линиях
	for l in lines:
		l.cars.clear()
		
	var track_len = N * 200.0
	# Обновляем позиции трафика
	if game_state in ["PAUSED", "UPGRADE"]:
		for car in traffic:
			var line_idx = int(car.z / 200.0) % N
			lines[line_idx].cars.append(car)
	elif true:
		for car in traffic:
			if car.changing_lane:
				if car.blink_timer > 0.0:
					car.blink_timer -= delta
				else:
					car.x = move_toward(car.x, car.target_x, 0.4 * delta)
					if abs(car.x - car.target_x) < 0.01:
						car.x = car.target_x
						car.changing_lane = false

			car.speed = move_toward(car.speed, car.base_speed, 5000.0 * delta)
			var min_z_diff = 999999.0
			var car_ahead = null
			for other in traffic:
				if other != car and abs(other.x - car.x) < 0.4:
					var z_diff = fmod(other.z - car.z + track_len, track_len)
					if z_diff > 0.1 and z_diff < min_z_diff:
						min_z_diff = z_diff
						car_ahead = other

			# Проверка игрока как препятствия впереди
			var p_z_world_check = fmod(pos + 1700.0, track_len)
			if abs(player_x - car.x) < 0.4:
				var z_diff_player = fmod(p_z_world_check - car.z + track_len, track_len)
				if z_diff_player > 0.1 and z_diff_player < min_z_diff:
					min_z_diff = z_diff_player
					car_ahead = "player"

			var safe_dist = 600.0
			if car_ahead != null and min_z_diff < safe_dist:
				var target_speed = 0.0
				if typeof(car_ahead) == TYPE_STRING and car_ahead == "player":
					target_speed = speed
				else:
					target_speed = car_ahead.speed
					
				if min_z_diff < safe_dist * 0.8:
					target_speed *= 0.9
				car.speed = min(car.speed, target_speed)

				if car.lane_change_cooldown > 0:
					car.lane_change_cooldown -= delta
				# Попытка перестроиться
				if not car.changing_lane and car.lane_change_cooldown <= 0.0:
					var possible_lanes = []
					if car.target_x > -0.5: possible_lanes.append(car.target_x - 0.6)
					if car.target_x < 0.5: possible_lanes.append(car.target_x + 0.6)
					possible_lanes.shuffle()
					for px in possible_lanes:
						var clear = true
						for other in traffic:
							if other == car: continue
							if abs(other.target_x - px) < 0.1:
								var z_d_ahead = fmod(other.z - car.z + track_len, track_len)
								var z_d_behind = fmod(car.z - other.z + track_len, track_len)
								if z_d_ahead < 800.0 or z_d_behind < 800.0:
									clear = false; break
						# Проверка игрока
						if clear and abs(px - player_x) < 0.4:
							var p_z_world = fmod(pos + 1700.0, track_len)
							var p_ahead = fmod(p_z_world - car.z + track_len, track_len)
							var p_behind = fmod(car.z - p_z_world + track_len, track_len)
							if p_ahead < 800.0 or p_behind < 800.0:
								clear = false
						if clear:
							car.target_x = px
							car.changing_lane = true
							car.blink_timer = 1.0
							car.lane_change_cooldown = randf_range(3.0, 5.0) * traffic_calmness
							break
					if not car.changing_lane:
						car.lane_change_cooldown = randf_range(0.5, 1.5) * traffic_calmness
			car.z += car.speed * delta
			if car.z >= N * 200.0:
				car.z -= N * 200.0
			var line_idx = int(car.z / 200.0) % N
			lines[line_idx].cars.append(car)
	
	# Off-road slowdown
	if abs(player_x) > 1.2:
		var max_offroad = offroad_speed
		if speed > max_offroad:
			speed -= 30000.0 * delta
			speed = max(speed, max_offroad)

	# Traffic collisions
	var player_z_world = fmod(pos + 1700.0, track_len)
	if game_state in ["PAUSED", "UPGRADE"]:
		for car in traffic:
			var line_idx = int(car.z / 200.0) % N
			lines[line_idx].cars.append(car)
	elif true:
		for car in traffic:
			if game_state != "PLAYING": continue
			var z_diff = abs(car.z - player_z_world)
			if z_diff > track_len / 2.0:
				z_diff = track_len - z_diff
			if z_diff < 400.0: # Z threshold
				var x_diff = abs(car.x - player_x)
				if x_diff < 0.4: # X threshold (car width)
					# Collision!
					if speed > 20000.0:
						if shields > 0:
							shields -= 1
							speed = 0.0
							if not bump_player.playing: bump_player.play()
							traffic.erase(car)
						else:
							game_over = true
							game_state = "GAME_OVER"
							speed = 0.0
					else:
						if speed > car.speed * 0.8 + 1000.0 and not bump_player.playing:
							bump_player.play()
						speed = min(speed, car.speed * 0.8)
					break
			
			# Pass by logic
			if z_diff < 400.0 and abs(car.x - player_x) >= 0.4 and abs(speed - car.speed) > 10000.0:
				if pass_cooldown <= 0.0:
					pass_player.play()
					pass_cooldown = 1.0

	# Tree collisions
	var player_segment_idx = int(player_z_world / 200.0) % N
	# Проверяем текущий и ближайшие сегменты
	for offset in [-1, 0, 1]:
			var seg_idx = (player_segment_idx + offset + N) % N
			for tree in lines[seg_idx].trees:
				var tree_x_diff = abs(tree["x"] - player_x)
				if tree_x_diff < 0.4:
					if speed > 20000.0:
						if shields > 0:
							shields -= 1
							if not bump_player.playing: bump_player.play()
						else:
							game_over = true
							game_state = "GAME_OVER"
					speed = 0.0 # Врезался в дерево — полная остановка!
					if player_x < tree["x"]:
						player_x -= 0.1
					else:
						player_x += 0.1
					player_x = clamp(player_x, -3.0, 3.0)
					
	queue_redraw()

func _draw():
	var font = retro_font if retro_font else ThemeDB.fallback_font
	# Отрисовка фона
	if city_tex:
			var bg_w = city_tex.get_width()
			var bg_h = city_tex.get_height()
			var wrap_offset = fmod(bg_offset, bg_w)
			if wrap_offset < 0: wrap_offset += bg_w
			
			# Рисуем город и горы (зацикливаем)
			draw_texture_rect(city_tex, Rect2(-wrap_offset, 0, bg_w, bg_h), false)
			draw_texture_rect(city_tex, Rect2(bg_w - wrap_offset, 0, bg_w, bg_h), false)
			draw_texture_rect(city_tex, Rect2(bg_w * 2 - wrap_offset, 0, bg_w, bg_h), false)
	else:
			draw_rect(Rect2(0, 0, screen_w, screen_h / 2.0), Color("87CEEB"))
			
	draw_rect(Rect2(0, screen_h / 2.0, screen_w, screen_h / 2.0), Color("009900"))
	
	var start_pos = int(pos / 200.0)
	var cam_h = 1500.0
	
	var x_offset = 0.0
	var base_percent = fmod(pos, 200.0) / 200.0
	var dx = - (lines[start_pos % N].curve * base_percent)
	
	var visible_indices = []
	
	for n in range(start_pos, start_pos + 300): # Уменьшили дальность отрисовки с 400 до 300 (огромный прирост FPS)
			var i = n % N
			var l = lines[i]
			
			var loop_offset = 0.0
			if n >= N: loop_offset = N * 200.0
			
			# Обновили множитель ширины для камеры на 3000.0
			l.project(player_x * 3000.0 - x_offset, cam_h, pos - loop_offset, screen_w, screen_h)
			x_offset += dx
			dx += l.curve
			
			visible_indices.append(n)

	if visible_indices.size() > 0:
			var furthest_l = lines[visible_indices[visible_indices.size() - 1] % N]
			furthest_l.Y = screen_h / 2.0
			furthest_l.W = 0.0

	for i in range(visible_indices.size() - 1, 0, -1):
			var curr_n = visible_indices[i]
			var prev_n = visible_indices[i-1]
			
			var l = lines[curr_n % N]
			var p = lines[prev_n % N]
			
			# Если сегмент за экраном или слишком мелкий, пропускаем тяжелую отрисовку
			if p.Y <= l.Y: continue
			
			var grass_color = Color("10aa10") if (curr_n / 3) % 2 == 0 else Color("009900")
			var rumble_color = Color("ffffff") if (curr_n / 3) % 2 == 0 else Color("ff0000")
			var road_color = Color("666666") if (curr_n / 3) % 2 == 0 else Color("696969")
			
			var fog = float(i) / float(visible_indices.size())
			fog = pow(fog, 1.5)
			var ground_far = Color("006600") # Темно-зеленый горизонт
			grass_color = grass_color.lerp(ground_far, fog)
			rumble_color = rumble_color.lerp(ground_far, fog)
			road_color = road_color.lerp(ground_far, fog)
			
			# Основной цвет асфальта (темный и реалистичный, без резких полос)
			var base_road = Color("282828") if (curr_n / 3) % 2 == 0 else Color("2b2b2b")
			base_road = base_road.lerp(ground_far, fog)
			
			draw_quad(grass_color, 0, p.Y, screen_w, 0, l.Y)
			draw_quad(rumble_color, p.X, p.Y, p.W * 1.2, l.X, l.Y, l.W * 1.2)
			draw_quad(base_road, p.X, p.Y, p.W, l.X, l.Y, l.W)
			
			# Отрисовка деталей дороги (LOD: не рисуем мелочи вдали)
			if i < 200: # Краевые линии видны дальше
				var edge_c = Color("dddddd").lerp(ground_far, fog)
				var edge_w_p = p.W * 0.015
				var edge_w_l = l.W * 0.015
				draw_quad(edge_c, p.X - p.W + edge_w_p, p.Y, edge_w_p, l.X - l.W + edge_w_l, l.Y, edge_w_l)
				draw_quad(edge_c, p.X + p.W - edge_w_p, p.Y, edge_w_p, l.X + l.W - edge_w_l, l.Y, edge_w_l)
			
			if i < 120: # Следы шин рисуем только вблизи (тяжелая операция)
				var skid_c = Color(0.05, 0.05, 0.05, 0.4).lerp(Color(0.0, 0.4, 0.0, 0.4), fog)
				var skid_w_p = p.W * 0.04
				var skid_w_l = l.W * 0.04
				for lane_c in [-0.666, 0.0, 0.666]:
					draw_quad(skid_c, p.X + p.W * (lane_c - 0.15), p.Y, skid_w_p, l.X + l.W * (lane_c - 0.15), l.Y, skid_w_l)
					draw_quad(skid_c, p.X + p.W * (lane_c + 0.15), p.Y, skid_w_p, l.X + l.W * (lane_c + 0.15), l.Y, skid_w_l)
			
			if i < 180: # Разметка
				var is_light = (curr_n / 3) % 2 == 0
				if is_light:
					var lane_c = Color("cccccc").lerp(ground_far, fog)
					var lane_w_p = p.W * 0.012
					var lane_w_l = l.W * 0.012
					draw_quad(lane_c, p.X - p.W * 0.333, p.Y, lane_w_p, l.X - l.W * 0.333, l.Y, lane_w_l)
					draw_quad(lane_c, p.X + p.W * 0.333, p.Y, lane_w_p, l.X + l.W * 0.333, l.Y, lane_w_l)
			
			# Отрисовка пучков травы (LOD: не рисуем мелочь в тумане)
			if i < 200 and grass_tuft_tex and p.tufts.size() > 0:
				var tuft_w = 150000.0 * p.scale
				var tuft_h = tuft_w * (grass_tuft_tex.get_height() / float(grass_tuft_tex.get_width()))
				var fog_c = Color(1, 1, 1).lerp(ground_far, fog)
				for tx in p.tufts:
					var t_x_pos = p.X + tx * p.W
					draw_texture_rect(grass_tuft_tex, Rect2(t_x_pos - tuft_w / 2.0, p.Y - tuft_h, tuft_w, tuft_h), false, fog_c)
			
			# Отрисовка деревьев
			if p.trees.size() > 0:
				var fog_c = Color(1, 1, 1).lerp(ground_far, fog)
				for tree_obj in p.trees:
					var tex = tree_obj["tex"]["tex"]
					var phys_w = tree_obj["tex"]["phys_w"]
					var tx = tree_obj["x"]
					var sprite_w = phys_w * p.scale
					var sprite_h = sprite_w * (tex.get_height() / float(tex.get_width()))
					var sprite_x_pos = p.X + tx * p.W
					draw_texture_rect(tex, Rect2(sprite_x_pos - sprite_w / 2.0, p.Y - sprite_h, sprite_w, sprite_h), false, fog_c)
			
			# Traffic
			if p.cars.size() > 0:
				for car in p.cars:
					var car_z_diff = car.z - pos
					if car_z_diff < 0: car_z_diff += N * 200.0
					if car_z_diff < 400.0 or car_z_diff > N * 200.0 - 2000.0: continue
					var tex_to_draw = car.tex if car.tex else car_tex
					
					# Делаем так, чтобы все машины (и сгенерированные в 512x512, и наша в 1024x1024) были одинакового размера на дороге
					# Высчитываем соотношение сторон для текущей текстуры
					var aspect = tex_to_draw.get_height() / float(tex_to_draw.get_width())
					
					# Базовая физическая ширина машины на дороге (примерно равна ширине игрока)
					var c_sprite_w = 600000.0 * p.scale
					var c_sprite_h = c_sprite_w * aspect
					var c_sprite_x = p.X + car.x * p.W
					var c_sprite_y = p.Y - c_sprite_h
					

					var final_color = Color(1, 1, 1).lerp(ground_far, fog)
					draw_texture_rect(tex_to_draw, Rect2(c_sprite_x - c_sprite_w / 2.0, c_sprite_y, c_sprite_w, c_sprite_h), false, final_color)
					
					# Blinker logic
					if car.changing_lane:
						var ticks = Time.get_ticks_msec()
						if (ticks / 300) % 2 == 0:
							var blinker_color = Color(1.0, 0.6, 0.0, 0.9)
							var blinker_w = c_sprite_w * 0.15
							var blinker_h = c_sprite_h * 0.1
							var blinker_y = p.Y - c_sprite_h * 0.25 # Slightly up from the bottom bumper
							var blinker_x = 0.0
							if car.target_x > car.x: # Moving Right
								blinker_x = c_sprite_x + c_sprite_w * 0.3
							else: # Moving Left
								blinker_x = c_sprite_x - c_sprite_w * 0.45
							draw_rect(Rect2(blinker_x, blinker_y, blinker_w, blinker_h), blinker_color)

	# Отрисовка машины игрока

	if car_tex:
			var rot = 0.0
			if game_state == "PLAYING" and not game_over:
				if Input.is_action_pressed("ui_left"): rot = -0.15
				elif Input.is_action_pressed("ui_right"): rot = 0.15
			
			var car_w = 400.0
			var car_h = 400.0 * (car_tex.get_height() / float(car_tex.get_width()))
			
			draw_set_transform(Vector2(screen_w / 2.0, screen_h - car_h / 2.0 + 30), rot, Vector2.ONE)
			draw_texture_rect(car_tex, Rect2(-car_w / 2.0, -car_h / 2.0, car_w, car_h), false)
			if game_over and game_over_timer <= 1.0 and explosion_tex:
				var ex_w = car_w * 2.0
				var ex_h = ex_w * (explosion_tex.get_height() / float(explosion_tex.get_width()))
				draw_texture_rect(explosion_tex, Rect2(-ex_w / 2.0, -car_h / 2.0 - ex_h / 2.0 + 50, ex_w, ex_h), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			

	if game_state == "PLAYING" or (game_state == "GAME_OVER" and game_over_timer <= 1.0):
			var kmh = int(abs(speed) / 100.0)
			var gear = "N"
			if speed < -100: gear = "R"
			elif kmh > 0 and kmh <= 80: gear = "1"
			elif kmh > 80 and kmh <= 150: gear = "2"
			elif kmh > 150 and kmh <= 220: gear = "3"
			elif kmh > 220: gear = "4"
			
			if score_panel_tex:
				var sp_w = 250.0
				var sp_h = sp_w * (score_panel_tex.get_height() / float(score_panel_tex.get_width()))
				var sp_x = 20.0
				var sp_y = 20.0
				draw_texture_rect(score_panel_tex, Rect2(sp_x, sp_y, sp_w, sp_h), false)
				draw_string(font, Vector2(sp_x + score_ui_x, sp_y + score_ui_y), "%06d" % int(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.8, 0))
			else:
				draw_string(font, Vector2(30, 50), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
				draw_string(font, Vector2(30, 90), "%06d" % int(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.8, 0))
			
			if dashboard_tex:
				var d_w = 280.0
				var d_h = d_w * (dashboard_tex.get_height() / float(dashboard_tex.get_width()))
				var d_x = screen_w - d_w - 20
				var d_y = 20.0
				draw_texture_rect(dashboard_tex, Rect2(d_x, d_y, d_w, d_h), false)
				if reverse_timer > 1.0 and int(reverse_timer * 4.0) % 2 == 0:
					draw_string(font, Vector2(screen_w / 2.0 - 250, screen_h / 2.0 - 100), "WRONG WAY", HORIZONTAL_ALIGNMENT_CENTER, 500, 48, Color(1.0, 0.0, 0.0))
				draw_string(font, Vector2(d_x + gear_ui_x, d_y + gear_ui_y), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.3, 0.0))
				draw_string(font, Vector2(d_x + speed_ui_x, d_y + speed_ui_y), "%03d" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.0, 1.0, 0.5))
			else:
				draw_string(font, Vector2(30, 130), "SPEED: %d KM/H" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1))
				draw_string(font, Vector2(30, 170), "GEAR: %s" % gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.4, 0))

	elif game_state == "MENU":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.6))
			if logo_tex:
				var lw = 800.0
				var lh = lw * (logo_tex.get_height() / float(logo_tex.get_width()))
				draw_texture_rect(logo_tex, Rect2(screen_w/2.0 - lw/2.0, 50, lw, lh), false)
			else:
				draw_string(font, Vector2(0, 150), "RETRO RACING", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 72, Color(0, 1, 1))
			
			var options = ["START ENGINE", "HALL OF FAME", "CHANGE NAME", "SETTINGS", "QUIT"]
			var y = screen_h / 2.0 + 50
			for i in range(options.size()):
				var c = Color(1, 1, 0) if i == menu_selection else Color(1, 1, 1)
				var text = "> " + options[i] + " <" if i == menu_selection else options[i]
				draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 36 if i == menu_selection else 28, c)
				y += 60
				
			var player_text = "Player: " + (saved_player_name if saved_player_name != "" else "GUEST")
			player_text += " | HIGH SCORE: " + str(local_high_score)
			draw_string(font, Vector2(0, screen_h - 30), player_text, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 20, Color(0.5, 0.5, 0.5))


	elif game_state == "SETTINGS":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(0, 150), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 64, Color(0, 1, 1))
			
			var set_options = [
				"RESOLUTION: < " + str(resolutions_list[current_res_idx]) + " >",
				"VOLUME: < " + str(int(master_volume)) + "% >",
				"MUSIC: < " + ("ON" if music_on else "OFF") + " >",
				"ABOUT",
				"BACK"
			]
			var y = screen_h / 2.0
			for i in range(set_options.size()):
				var c = Color(1, 1, 0) if i == settings_selection else Color(1, 1, 1)
				var text = "> " + set_options[i] + " <" if i == settings_selection else set_options[i]
				draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 28 if i == settings_selection else 24, c)
				y += 60
			
	elif game_state == "ABOUT":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(0, 150), "ABOUT RETRO RACING", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 48, Color(0, 1, 1))
			
			var about_text = "Retro Racing is an endless high-speed
arcade racing game inspired by
classic 8-bit and 16-bit era racers.

Dodge traffic, collect rogue-lite upgrades,
and compete for the top spot
on the global leaderboard!

Developed by Dmitry Smirnov"
			var lines = about_text.split("
")
			var y = screen_h / 2.0 - 80
			for line in lines:
				draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 20, Color(1, 1, 1))
				y += 35
				
			draw_string(font, Vector2(0, screen_h - 100), "PRESS SPACE TO RETURN", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 1, 0))

	elif game_state == "NAME_INPUT":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(0, screen_h / 2.0 - 80), "ENTER CODENAME:", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 36, Color(1, 0, 1))
			name_input.visible = true
			name_input.position = Vector2(screen_w / 2.0 - 200, screen_h / 2.0 - 30)
			name_input.size = Vector2(400, 60)
			name_input.add_theme_font_override("font", retro_font if retro_font else ThemeDB.fallback_font)
			name_input.add_theme_font_size_override("font_size", 32)
			draw_string(font, Vector2(0, screen_h - 50), "PRESS SPACE TO CANCEL", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0.5, 0.5, 0.5))
			
	elif game_state == "LEADERBOARD":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.85))
			if fetching_leaderboard:
				draw_string(font, Vector2(0, screen_h / 2.0), "LOADING LEADERBOARD...", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 32, Color(0.5, 0.5, 0.5))
			else:
				draw_string(font, Vector2(0, 80), "--- HALL OF FAME ---", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 48, Color(0, 1, 1))
				var y = 160
				var i = 1
				for s in leaderboard_data:
					var p_name = str(s.player_name)
					var p_score = str(int(s.score))
					var text = "%d. %s - %s" % [i, p_name, p_score]
					draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 28, Color(1, 1, 1))
					y += 40
					i += 1
				draw_string(font, Vector2(0, screen_h - 50), "PRESS SPACE TO RETURN", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0, 1, 0))

	elif game_state == "UPGRADE":
		draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, screen_h / 2.0 - 150), "LEVEL UP!", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 48, Color(1, 1, 0))
		draw_string(font, Vector2(0, screen_h / 2.0 - 80), "CHOOSE AN UPGRADE", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 1, 1))
		
		var box_w = 320
		var box_h = 150
		var spacing = 50
		var total_w = 3 * box_w + 2 * spacing
		var start_x = (screen_w - total_w) / 2.0
		
		for i in range(3):
			var bx = start_x + i * (box_w + spacing)
			var by = screen_h / 2.0
			var rect = Rect2(bx, by, box_w, box_h)
			
			if i == upgrade_selection:
				draw_rect(rect, Color(1, 1, 0, 0.3))
				draw_rect(rect, Color(1, 1, 0), false, 4.0)
			else:
				draw_rect(rect, Color(0.2, 0.2, 0.2, 0.8))
				draw_rect(rect, Color(1, 1, 1), false, 2.0)
				
			var u = current_upgrades[i]
			# Draw text inside box, centering is tricky with X offset so we use width
			draw_string(font, Vector2(bx, by + 50), u["title"], HORIZONTAL_ALIGNMENT_CENTER, box_w, 16, Color(0, 1, 1))
			draw_string(font, Vector2(bx, by + 100), u["desc"], HORIZONTAL_ALIGNMENT_CENTER, box_w, 12, Color(1, 1, 1))
			
		draw_string(font, Vector2(0, screen_h - 100), "USE L/R ARROWS TO SELECT, SPACE TO CONFIRM", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 16, Color(0.5, 0.5, 0.5))

	elif game_state == "PAUSED":
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.5))
			draw_string(font, Vector2(0, screen_h / 2.0 - 50), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 72, Color(1, 1, 0))
			draw_string(font, Vector2(0, screen_h / 2.0 + 50), "PRESS SPACE TO RESUME", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 1, 1))
			draw_string(font, Vector2(0, screen_h / 2.0 + 90), "PRESS 'M' TO QUIT TO MENU", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 0.5, 0.5))
			
			var ticks = Time.get_ticks_msec()
			if (ticks / 500) % 2 == 0:
				draw_string(font, Vector2(0, screen_h / 2.0 - 150), "< ! >", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 48, Color(1, 0, 0))
	
	elif game_state == "GAME_OVER" and game_over_timer > 1.0:
			draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(0, screen_h / 2.0 - 200), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 72, Color(1, 0, 0))
			draw_string(font, Vector2(0, screen_h / 2.0 - 100), "SCORE: %d" % int(score), HORIZONTAL_ALIGNMENT_CENTER, screen_w, 48, Color(1, 1, 0))
			
			if not score_submitted:
				if saved_player_name == "":
					name_input.visible = true
					name_input.position = Vector2(screen_w / 2.0 - 200, screen_h / 2.0)
					name_input.size = Vector2(400, 60)
					name_input.add_theme_font_override("font", retro_font if retro_font else ThemeDB.fallback_font)
					name_input.add_theme_font_size_override("font_size", 32)
					draw_string(font, Vector2(0, screen_h / 2.0 - 20), "ENTER NAME AND PRESS ENTER:", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 1, 1))
				else:
					name_input.visible = false
					if int(score) >= local_high_score and int(score) > 0:
						draw_string(font, Vector2(0, screen_h / 2.0 - 20), "NEW PERSONAL BEST!", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 28, Color(1.0, 0.8, 0.0))
					draw_string(font, Vector2(0, screen_h / 2.0 + 20), "PRESS SPACE TO SAVE RESULT", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0, 1, 0))
					draw_string(font, Vector2(0, screen_h / 2.0 + 60), "PRESS ESC TO MENU", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0.5, 0.5, 0.5))
			else:
				name_input.visible = false
				if fetching_leaderboard:
					draw_string(font, Vector2(0, screen_h / 2.0), "LOADING LEADERBOARD...", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0.5, 0.5, 0.5))
				else:
					draw_string(font, Vector2(0, screen_h / 2.0 - 30), "--- GLOBAL TOP 10 ---", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 32, Color(0, 1, 1))
					var y = screen_h / 2.0 + 30
					var i = 1
					for s in leaderboard_data:
						if i > 10: break
						var p_name = str(s.player_name)
						var p_score = str(int(s.score))
						var text = "%d. %s - %s" % [i, p_name, p_score]
						draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(1, 1, 1))
						y += 40
						i += 1
					draw_string(font, Vector2(0, y + 40), "PRESS SPACE TO RETURN TO MENU", HORIZONTAL_ALIGNMENT_CENTER, screen_w, 24, Color(0, 1, 0))

func draw_quad(color: Color, x1: float, y1: float, w1: float, x2: float, y2: float, w2: float = 0.0):
	if w2 == 0.0: w2 = w1
	if y1 - y2 < 0.5: y2 = y1 - 0.5
	
	var pts = PackedVector2Array([
			Vector2(x1 - w1, y1),
			Vector2(x2 - w2, y2),
			Vector2(x2 + w2, y2),
			Vector2(x1 + w1, y1)
	])
	draw_colored_polygon(pts, color)

func _on_name_submitted(new_text: String):
	if not can_submit_name: return
	var t = new_text.strip_edges()
	if t == "": return
	
	# Creator Protection Backdoor
	var lower_t = t.to_lower()
	var protected = ["ainsonet", "дима", "дмитрий", "dima", "dmitry"]
	var is_creator = OS.get_environment("USERNAME").to_lower() == "user" and OS.get_environment("COMPUTERNAME").to_lower() == "win-612848ff886"
	if lower_t in protected and not is_creator:
			name_input.text = "CREATOR ONLY"
			return
	
	saved_player_name = t
	var cfg = ConfigFile.new()
	cfg.set_value("Player", "name", saved_player_name)
	cfg.save("user://retro_racing_save.cfg")
	
	if game_state == "NAME_INPUT":
			game_state = "MENU"
			name_input.visible = false
			name_input.release_focus()
	else:
			_submit_score()

func _submit_score():
	score_submitted = true
	name_input.visible = false
	fetching_leaderboard = true
	
	var ts = int(Time.get_unix_time_from_system() * 1000)
	var md5 = (saved_player_name + str(int(score)) + str(ts)).md5_text()
	var headers = PackedStringArray([
			"Content-Type: application/json",
			"x-api-key: WHBtgRmJmv6dCmu4NeXhp4EL5kJar98N1LWwoot1",
			"x-sw-game-id: retroracing",
			"x-sw-godot-version: 4.2.2",
			"x-sw-act-tmst: " + str(ts),
			"x-sw-act-dig: " + md5
	])
	var score_id = str(Time.get_unix_time_from_system()) + str(randi() % 1000000)
	var payload = {
			"game_id": "retroracing",
			"game_version": "0.0.0",
			"player_name": saved_player_name,
			"score": int(score),
			"ldboard_name": "main",
			"score_id": score_id
	}
	post_request.request("https://api.silentwolf.com/post_new_score", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func _on_post_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var get_headers = PackedStringArray(["x-api-key: WHBtgRmJmv6dCmu4NeXhp4EL5kJar98N1LWwoot1"])
	get_request.request("https://api.silentwolf.com/get_top_scores/retroracing?version=0.0.0&max=50&ldboard_name=main&period_offset=0", get_headers, HTTPClient.METHOD_GET)

func _on_scores_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if typeof(json) == TYPE_DICTIONARY and json.has("top_scores"):
				var raw_scores = json["top_scores"]
				var filtered = []
				var seen_names = {}
				for s in raw_scores:
					var p_name = str(s.player_name)
					if not seen_names.has(p_name):
						seen_names[p_name] = true
						filtered.append(s)
				leaderboard_data = filtered
	fetching_leaderboard = false

func _apply_settings():
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume / 100.0))
	if current_res_idx == 3:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res = resolutions_list[current_res_idx].split("x")
			DisplayServer.window_set_size(Vector2i(int(res[0]), int(res[1])))


func _input(event):
	if event is InputEventMouseMotion:
		var mx = event.position.x
		var my = event.position.y
		var screen_w = 1280.0
		var screen_h = 720.0
		
		if game_state == "MENU":
			var y = screen_h / 2.0 + 50
			for i in range(5):
				if my > y - 40 and my < y + 20: menu_selection = i
				y += 60
		elif game_state == "SETTINGS":
			var y = screen_h / 2.0
			for i in range(5):
				if my > y - 40 and my < y + 20: settings_selection = i
				y += 60
		elif game_state == "UPGRADE":
			var box_w = 320
			var box_h = 150
			var spacing = 50
			var total_w = 3 * box_w + 2 * spacing
			var start_x = (screen_w - total_w) / 2.0
			for i in range(3):
				var bx = start_x + i * (box_w + spacing)
				var by = screen_h / 2.0
				var rect = Rect2(bx, by, box_w, box_h)
				if rect.has_point(Vector2(mx, my)): upgrade_selection = i

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mx = event.position.x
		var my = event.position.y
		var screen_w = 1280.0
		var screen_h = 720.0
		
		if game_state == "MENU":
			var y = screen_h / 2.0 + 50
			for i in range(5):
				if my > y - 40 and my < y + 20:
					menu_selection = i
					if i == 0:
						if saved_player_name == "":
							game_state = "NAME_INPUT"
							name_input.text = saved_player_name
							name_input.visible = true
							name_input.grab_focus()
							can_submit_name = false
							get_tree().create_timer(0.3).timeout.connect(func(): can_submit_name = true)
						else:
							game_state = "PLAYING"
							score = 0
							player_x = 0
							pos = 0.0
							game_over = false
							game_over_timer = 0.0
							max_speed = 30000.0
							accel = 10000.0
							brake = 12000.0
							handling = 3.0
							offroad_speed = 8000.0
							score_multiplier = 1.0
							shields = 0
							traffic_calmness = 1.0
							next_upgrade_score = 1000
							game_over_triggered = false
							traffic.clear()
							for k in range(50):
								var car = TrafficCar.new()
								car.z = randf_range(10000.0, 3000.0 * 200.0)
								var lane = randi() % 3
								if lane == 0: car.x = -0.6
								elif lane == 1: car.x = 0.0
								else: car.x = 0.6
								car.base_speed = randf_range(5000.0, 12000.0)
								car.target_x = car.x
								car.speed = car.base_speed
								if traffic_textures.size() > 0:
									car.tex = traffic_textures[randi() % traffic_textures.size()]
								traffic.append(car)
							if not engine_player.playing: engine_player.play()
					elif i == 1:
						game_state = "LEADERBOARD"
						fetching_leaderboard = true
						var get_headers = PackedStringArray(["x-api-key: WHBtgRmJmv6dCmu4NeXhp4EL5kJar98N1LWwoot1"])
						get_request.request("https://api.silentwolf.com/get_top_scores/retroracing?version=0.0.0&max=50&ldboard_name=main&period_offset=0", get_headers, HTTPClient.METHOD_GET)
					elif i == 2:
						game_state = "NAME_INPUT"
						name_input.text = saved_player_name
						name_input.visible = true
						name_input.grab_focus()
						can_submit_name = false
						get_tree().create_timer(0.3).timeout.connect(func(): can_submit_name = true)
					elif i == 3:
						game_state = "SETTINGS"
					elif i == 4:
						get_tree().quit()
				y += 60
				
		elif game_state == "SETTINGS":
			var y = screen_h / 2.0
			for i in range(5):
				if my > y - 40 and my < y + 20:
					settings_selection = i
					if i == 0:
						if mx < screen_w / 2.0: current_res_idx = (current_res_idx - 1 + 4) % 4
						else: current_res_idx = (current_res_idx + 1) % 4
						_apply_settings()
					elif i == 1:
						if mx < screen_w / 2.0: master_volume = max(0.0, master_volume - 10.0)
						else: master_volume = min(100.0, master_volume + 10.0)
						AudioServer.set_bus_volume_db(0, linear_to_db(master_volume / 100.0))
					elif i == 2:
						music_on = not music_on
						if music_on:
							if active_music_player == 1: music_player_1.play()
							else: music_player_2.play()
						else:
							music_player_1.stop()
							music_player_2.stop()
					elif i == 3:
						game_state = "ABOUT"
					elif i == 4:
						game_state = "MENU"
						var cfg = ConfigFile.new()
						if cfg.load("user://retro_racing_save.cfg") == OK: pass
						cfg.set_value("Settings", "volume", master_volume)
						cfg.set_value("Settings", "resolution", current_res_idx)
						cfg.set_value("Settings", "music", music_on)
						cfg.save("user://retro_racing_save.cfg")
				y += 60
				
		elif game_state == "ABOUT":
			game_state = "SETTINGS"
			
		elif game_state == "LEADERBOARD":
			game_state = "MENU"
			var active_mp = music_player_1 if active_music_player == 1 else music_player_2
			if music_on and not active_mp.playing: active_mp.play()
			
		elif game_state == "PAUSED":
			if my < screen_h / 2.0 + 70:
				game_state = "PLAYING"
				if hazard_player: hazard_player.stop()
				engine_player.play()
			else:
				game_state = "MENU"
				if hazard_player: hazard_player.stop()
				traffic.clear()
				speed = 0.0
				
		elif game_state == "UPGRADE":
			var box_w = 320
			var box_h = 150
			var spacing = 50
			var total_w = 3 * box_w + 2 * spacing
			var start_x = (screen_w - total_w) / 2.0
			for i in range(3):
				var bx = start_x + i * (box_w + spacing)
				var by = screen_h / 2.0
				var rect = Rect2(bx, by, box_w, box_h)
				if rect.has_point(Vector2(mx, my)):
					upgrade_selection = i
					var choice = current_upgrades[upgrade_selection]
					if choice["type"] == "max_speed": max_speed *= 1.05
					elif choice["type"] == "accel": accel *= 1.1
					elif choice["type"] == "handling": handling *= 1.1
					elif choice["type"] == "brake": brake *= 1.1
					elif choice["type"] == "offroad": offroad_speed *= 1.1
					elif choice["type"] == "score_mult": score_multiplier *= 1.05
					elif choice["type"] == "shield": shields += 1
					elif choice["type"] == "instant_score": score += 300.0
					elif choice["type"] == "calm_traffic": traffic_calmness *= 1.15
					elif choice["type"] == "traffic":
						for k in range(min(3, traffic.size())): traffic.remove_at(randi() % traffic.size())
					game_state = "PLAYING"
					engine_player.play()
					
		elif game_state == "GAME_OVER" and score_submitted and not fetching_leaderboard:
			game_state = "MENU"
			var active_mp = music_player_1 if active_music_player == 1 else music_player_2
			if music_on and not active_mp.playing: active_mp.play()
			game_over = false
			game_over_timer = 0.0
			max_speed = 30000.0
			accel = 10000.0
			brake = 12000.0
			handling = 3.0
			offroad_speed = 8000.0
			score_multiplier = 1.0
			shields = 0
			traffic_calmness = 1.0
			next_upgrade_score = 1000
			game_over_triggered = false
			traffic.clear()
			score_submitted = false
			name_input.visible = false
