from pathlib import Path
r=Path('/Users/juancarlos/Downloads/jogo/Tower Defense')
p=r/'scenes/world/day_night_manager.gd';s=p.read_text().replace('var is_game_over := false','var is_game_over := false\nvar gameplay_enabled := false\n\nfunc reset_session(active: bool = false) -> void:\n\tstate = State.DAY\n\tis_game_over = false\n\tgameplay_enabled = active\n\nfunc can_play() -> bool:\n\treturn gameplay_enabled and not is_game_over and not get_tree().paused')
s=s.replace('if event.is_action_pressed("start_night"):', 'if can_play() and event.is_action_pressed("start_night") and not event.is_echo():').replace('if is_game_over or state == State.NIGHT:', 'if not can_play() or state == State.NIGHT:').replace('return is_day()', 'return is_day() and can_play()');p.write_text(s)
p=r/'scenes/player/player.gd';s=p.read_text();start=s.index('func _unhandled_input');end=s.index('func _physics_process');s=s[:start]+'''func _unhandled_input(event: InputEvent) -> void:
	if not DayNightManager.can_play() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-55), deg_to_rad(10))
	elif event.is_action_pressed("attack") and not Input.is_action_pressed("domesticate"):
		_try_attack()

'''+s[end:];s=s.replace('if not DayNightManager.is_game_over:', 'if DayNightManager.can_play():').replace('if not attack_cooldown.is_stopped():', 'if not DayNightManager.can_play() or not attack_cooldown.is_stopped():').replace('attack_cooldown.start()', 'attack_cooldown.start()\n\t$Visual.strike()');p.write_text(s)
p=r/'scenes/player/domestication_channel.gd';s=p.read_text().replace('const DEBUG := true','const DEBUG := false').replace('if DayNightManager.is_game_over:\n\t\treturn', 'if not DayNightManager.can_play():\n\t\treset_channel()\n\t\treturn');s=s.replace('if event is InputEventKey and not event.echo:', 'if DayNightManager.can_play() and event is InputEventKey and not event.echo:');s=s.replace('_e_event_down = false # evita', 'reset_channel() # evita');s += '''
func reset_channel() -> void:
	_e_event_down = false
	if _progress > 0.0:
		_cancel("estado_ou_foco")
	if _is_alive(_target):
		_target.set_prompt("")
	_target = null

func get_progress() -> float:
	return _progress / CHANNEL_TIME
''';p.write_text(s)
p=r/'scenes/enemies/wild_dino.gd';s=p.read_text().replace('func _physics_process(delta: float) -> void:\n', 'func _physics_process(delta: float) -> void:\n\tif not DayNightManager.can_play():\n\t\treturn\n');s=s.replace('\thp -= amount', '\t$Visual.flash()\n\thp -= amount');s=s.replace('\tvar green := StandardMaterial3D.new()\n\tgreen.albedo_color = Color(0.2, 0.7, 0.3)\n\tmesh.material_override = green # feedback visual temporario', '\t$Visual.set_ally()\n\t_update_label()');s=s.replace('\t_attack_cooldown_left = ATTACK_COOLDOWN', '\t$Visual.strike()\n\t_attack_cooldown_left = ATTACK_COOLDOWN');s=s.replace('hp_label.text = "HP %d/%d" % [maxi(int(hp), 0), int(MAX_HP)] # feedback temporario de playtest', 'var status := "ALIADO" if is_domesticated else ("SELVAGEM" if is_domesticable else "CARNOTAURO • NÃO DOMESTICÁVEL")\n\thp_label.text = "%s  ·  %d/%d" % [status, maxi(int(hp), 0), int(MAX_HP)]\n\thp_label.modulate = Color("a5e7c3") if is_domesticated else Color("fff0cf")');p.write_text(s)
p=r/'scenes/test/wave_test_trigger.gd';s=p.read_text().replace('@export var debug_enabled := true','@export var debug_enabled := false').replace('or DayNightManager.is_game_over:', 'or not DayNightManager.can_play():');p.write_text(s)
p=r/'scenes/world/wave_manager.gd';s=p.read_text().replace('\tDayNightManager.report_wave_victory()', '\t# Resolve at end of frame: base destruction in this frame has priority.\n\t_finish_victory.call_deferred()');s+='''
func _finish_victory() -> void:
	var base := get_tree().get_first_node_in_group("base")
	if is_instance_valid(base) and base.health <= 0.0:
		DayNightManager.report_defeat()
	else:
		DayNightManager.report_wave_victory()

func snapshot() -> Dictionary:
	return {"spawned": _spawned_count, "total": enemy_count, "active": _active_wave_enemies.size(), "resolved": _spawned_count - _active_wave_enemies.size()}
''';p.write_text(s)
p=r/'project.godot';s=p.read_text().replace('run/main_scene="res://scenes/world/prototype_area.tscn"','run/main_scene="res://scenes/ui/main.tscn"').replace('"Forward Plus"','"GL Compatibility"');s+='''
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''';p.write_text(s)
