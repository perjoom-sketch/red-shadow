@tool
extends EditorScript

func _run():
	var sf = SpriteFrames.new()
	sf.remove_animation(&"default")
	
	var base = "res://assets/characters/adam/frames_normalized/"
	
	# idle
	sf.add_animation(&"idle")
	sf.set_animation_speed(&"idle", 2.0)
	sf.set_animation_loop(&"idle", true)
	sf.add_frame(&"idle", load(base + "1_adam_idle.png"))
	sf.add_frame(&"idle", load(base + "2_adam_idle_breath.png"))
	
	# walk
	sf.add_animation(&"walk")
	sf.set_animation_speed(&"walk", 8.0)
	sf.set_animation_loop(&"walk", true)
	sf.add_frame(&"walk", load(base + "3_adam_walk_1.png"))
	sf.add_frame(&"walk", load(base + "4_adam_walk_2.png"))
	sf.add_frame(&"walk", load(base + "5_adam_walk_3.png"))
	sf.add_frame(&"walk", load(base + "6_adam_walk_4.png"))
	
	# run
	sf.add_animation(&"run")
	sf.set_animation_speed(&"run", 12.0)
	sf.set_animation_loop(&"run", true)
	for i in range(1, 9):
		sf.add_frame(&"run", load(base + str(6 + i) + "_adam_run_" + str(i) + ".png"))
	
	# dash
	sf.add_animation(&"dash")
	sf.set_animation_speed(&"dash", 1.0)
	sf.set_animation_loop(&"dash", false)
	sf.add_frame(&"dash", load(base + "15_adam_dash.png"))
	
	# crouch
	sf.add_animation(&"crouch")
	sf.set_animation_speed(&"crouch", 1.0)
	sf.set_animation_loop(&"crouch", false)
	sf.add_frame(&"crouch", load(base + "27_adam_crouch.png"))
	
	# step_back
	sf.add_animation(&"step_back")
	sf.set_animation_speed(&"step_back", 10.0)
	sf.set_animation_loop(&"step_back", true)
	for i in range(1, 9):
		sf.add_frame(&"step_back", load(base + str(18 + i) + "_adam_step_back_" + str(i) + ".png"))
	
	# turn
	sf.add_animation(&"turn")
	sf.set_animation_speed(&"turn", 10.0)
	sf.set_animation_loop(&"turn", false)
	sf.add_frame(&"turn", load(base + "16_adam_left_look_turn_1.png"))
	sf.add_frame(&"turn", load(base + "17_adam_right_turn_2.png"))
	sf.add_frame(&"turn", load(base + "18_adam_right_turn_3.png"))
	
	# jump_up
	sf.add_animation(&"jump_up")
	sf.set_animation_speed(&"jump_up", 10.0)
	sf.set_animation_loop(&"jump_up", false)
	sf.add_frame(&"jump_up", load(base + "28_adam_jump_takeoff.png"))
	sf.add_frame(&"jump_up", load(base + "29_adam_air_up.png"))
	
	# fall
	sf.add_animation(&"fall")
	sf.set_animation_speed(&"fall", 1.0)
	sf.set_animation_loop(&"fall", false)
	sf.add_frame(&"fall", load(base + "28_adam_jump_takeoff.png"))
	
	# land
	sf.add_animation(&"land")
	sf.set_animation_speed(&"land", 1.0)
	sf.set_animation_loop(&"land", false)
	sf.add_frame(&"land", load(base + "32_adam_land.png"))
	
	# draw_charge
	sf.add_animation(&"draw_charge")
	sf.set_animation_speed(&"draw_charge", 1.0)
	sf.set_animation_loop(&"draw_charge", false)
	sf.add_frame(&"draw_charge", load(base + "39_adam_L_facing_draw_charge.png"))
	
	# slash_h
	sf.add_animation(&"slash_h")
	sf.set_animation_speed(&"slash_h", 1.0)
	sf.set_animation_loop(&"slash_h", false)
	sf.add_frame(&"slash_h", load(base + "40_adam_L_facing _slash_h.png"))
	
	# sheath
	sf.add_animation(&"sheath")
	sf.set_animation_speed(&"sheath", 1.0)
	sf.set_animation_loop(&"sheath", false)
	sf.add_frame(&"sheath", load(base + "43_left-facing_sheath.png"))
	
	# attack_up
	sf.add_animation(&"attack_up")
	sf.set_animation_speed(&"attack_up", 1.0)
	sf.set_animation_loop(&"attack_up", false)
	sf.add_frame(&"attack_up", load(base + "45_adam_attack_up.png"))
	
	# attack2
	sf.add_animation(&"attack2")
	sf.set_animation_speed(&"attack2", 1.0)
	sf.set_animation_loop(&"attack2", false)
	sf.add_frame(&"attack2", load(base + "46_adam_attack2.png"))
	
	# guard
	sf.add_animation(&"guard")
	sf.set_animation_speed(&"guard", 1.0)
	sf.set_animation_loop(&"guard", false)
	sf.add_frame(&"guard", load(base + "49_adam_combat_idle.png"))
	
	# parry
	sf.add_animation(&"parry")
	sf.set_animation_speed(&"parry", 1.0)
	sf.set_animation_loop(&"parry", false)
	sf.add_frame(&"parry", load(base + "44_adam_parry.png"))
	
	# hurt
	sf.add_animation(&"hurt")
	sf.set_animation_speed(&"hurt", 1.0)
	sf.set_animation_loop(&"hurt", false)
	sf.add_frame(&"hurt", load(base + "52_adam_hurt.png"))
	
	# dizzy
	sf.add_animation(&"dizzy")
	sf.set_animation_speed(&"dizzy", 1.0)
	sf.set_animation_loop(&"dizzy", true)
	sf.add_frame(&"dizzy", load(base + "53_adam_dizzy.png"))
	
	# die
	sf.add_animation(&"die")
	sf.set_animation_speed(&"die", 1.0)
	sf.set_animation_loop(&"die", false)
	sf.add_frame(&"die", load(base + "54_adam_die.png"))
	
	# victory
	sf.add_animation(&"victory")
	sf.set_animation_speed(&"victory", 1.0)
	sf.set_animation_loop(&"victory", false)
	sf.add_frame(&"victory", load(base + "55_adam_victory.png"))
	
	# Save
	var err = ResourceSaver.save(sf, "res://assets/characters/adam/adam_spriteframes.tres")
	if err == OK:
		print(">>> SpriteFrames saved successfully! 21 animations.")
	else:
		print(">>> ERROR saving SpriteFrames: ", err)
