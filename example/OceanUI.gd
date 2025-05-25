extends CanvasLayer


@onready var debug_texture_rect0:TextureRect = $DebugTextureRect0
@onready var debug_texture_rect1:TextureRect = $DebugTextureRect1
@onready var debug_texture_rect2:TextureRect = $DebugTextureRect2
@onready var debug_texture_rect3:TextureRect = $DebugTextureRect3
@onready var settings_view:PanelContainer = $PanelContainer
@onready var fps_view:Label = $VBoxContainer/FPS
@onready var ocean_fps_view:Label = $VBoxContainer/OceanFPS


@export var ocean:OceanEnvironment
@export var free_camera:Camera3D
@export var player_camera:Camera3D

var _debug_textures_initialized := false


func _process(_delta):
	var fps := Engine.get_frames_per_second()
	
	fps_view.text = "%.1f Draw FPS" % [fps]
	ocean_fps_view.text = "%.1f Ocean TPS" % [fps / (ocean.ocean.simulation_frameskip + 1)]
	
	if not _debug_textures_initialized and ocean.ocean.initialized:
		debug_texture_rect0.texture = ocean.ocean.get_waves_texture()

		debug_texture_rect1.texture = ocean.ocean.get_lean_normal_texture()

		debug_texture_rect2.texture = ocean.ocean.get_lean_B_texture()

		debug_texture_rect3.texture = ocean.ocean.get_lean_M_texture()

		_debug_textures_initialized = true


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("camera_mode_free") and free_camera != null:
		free_camera.make_current()
		print("c'est censé changer là")
	
	if event.is_action_pressed("camera_mode_ship") and player_camera != null:
		player_camera.make_current()
	
	if event.is_action_pressed("toggle_ocean_debug"):
		debug_texture_rect0.visible = not debug_texture_rect0.visible
		debug_texture_rect1.visible = debug_texture_rect0.visible
		debug_texture_rect2.visible = debug_texture_rect0.visible
		debug_texture_rect3.visible = debug_texture_rect0.visible


		settings_view.visible = debug_texture_rect0.visible
		
		if debug_texture_rect0.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	get_viewport().get_camera_3d().motion_enabled = not debug_texture_rect0.visible


func _on_frameskip_value_changed(value:float) -> void:
	ocean.ocean.simulation_frameskip = int(value)


func _on_simulate_enabled_toggled(button_pressed:bool) -> void:
	ocean.ocean.simulation_enabled = button_pressed


func _on_speed_value_changed(value:float) -> void:
	ocean.ocean.time_scale = value


func _on_choppiness_value_changed(value:float) -> void:
	ocean.ocean.choppiness = value


func _on_wind_speed_value_changed(value:float) -> void:
	ocean.ocean.wave_vector = ocean.ocean.wave_vector.normalized() * value


func _on_wind_direction_value_changed(value:float) -> void:
	ocean.ocean.wind_direction_degrees = value


func _on_wave_speed_value_changed(value:float) -> void:
	ocean.ocean.wave_scroll_speed = -value


func _on_cull_enabled_toggled(button_pressed:bool) -> void:
	$"../QuadTree3D".pause_cull = not button_pressed


func _on_planetary_curve_value_changed(value:float) -> void:
	ocean.ocean.planetary_curve_strength = value * 0.0001


func _on_heightmap_sync_frameskip_value_changed(value: float) -> void:
	ocean.ocean.heightmap_sync_frameskip = int(value)
