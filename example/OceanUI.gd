extends CanvasLayer


@onready var displacement_cascade0_view:TextureRect = $Displacement_cascade0
@onready var displacement_cascade1_view:TextureRect = $Displacement_cascade1
@onready var displacement_cascade2_view:TextureRect = $Displacement_cascade2
@onready var settings_view:PanelContainer = $PanelContainer
@onready var fps_view:Label = $VBoxContainer/FPS
@onready var ocean_fps_view:Label = $VBoxContainer/OceanFPS

#@onready var sun:DirectionalLight3D = $OceanEnvironment/DirectionalLight3D_Sun
#@onready var sky:DirectionalLight3D = $OceanEnvironment/DirectionalLight3D_Sky

@export var ocean:OceanEnvironment
@export var free_camera:Camera3D
@export var player_camera:Camera3D

var _debug_textures_initialized := false


var sun: DirectionalLight3D
var sky: DirectionalLight3D
var leanMapLight: SpotLight3D
var camera:Camera3D

var leanmap_debug:bool = false

func _ready():
	if ocean:  # Ensure ocean is assigned before accessing it
		sun = ocean.get_node("DirectionalLight3D_Sun")
		sky = ocean.get_node("DirectionalLight3D_Sky")
		leanMapLight = ocean.get_node("LeanMappingLight")
		camera = ocean.get_node("Camera3D")
		#setup_debug_light()
		
	else:
		print("Error: 'ocean' is not assigned in the Inspector.")

func _process(_delta):
	var fps := Engine.get_frames_per_second()
	
	fps_view.text = "%.1f Draw FPS" % [fps]
	ocean_fps_view.text = "%.1f Ocean TPS" % [fps / (ocean.ocean.simulation_frameskip + 1)]
	
	if not _debug_textures_initialized and ocean.ocean.initialized:
		#displacement_cascade0_view.texture = ocean.ocean.get_waves_texture()
		#displacement_cascade0_view.texture = ocean.ocean.get_lean_b_texture()
		displacement_cascade0_view.texture = ocean.ocean.get_lean_normal_texture()
		_debug_textures_initialized = true


#TODO : deactivate LEAN Mapping light when the rest are activated
func _input(event:InputEvent) -> void:
	if event.is_action_pressed("camera_mode_free") and free_camera != null:	
		free_camera.make_current()
	
	if event.is_action_pressed("camera_mode_ship") and player_camera != null:
		player_camera.make_current()
	
	if event.is_action_pressed("toggle_ocean_debug"):
		displacement_cascade0_view.visible = not displacement_cascade0_view.visible
		displacement_cascade1_view.visible = displacement_cascade0_view.visible
		displacement_cascade2_view.visible = displacement_cascade0_view.visible
		settings_view.visible = displacement_cascade0_view.visible
		
		if displacement_cascade0_view.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	#Press 0 to activate. Turns on lean mapping and a specular light to make this visible
	if event.is_action_pressed("lean_mapping_test_mode"):
		leanmap_debug = not leanmap_debug
		if(leanmap_debug):
			print("Lean map test mode activated check mark emoji")
			sun.visible = false
			leanMapLight.visible = true
		else:
			print("Lean map test mode deactivated x emoji")
			sun.visible = true
			sky.visible = false
			leanMapLight.visible = false
		print("Visible? " + str(leanMapLight.visible))

	get_viewport().get_camera_3d().motion_enabled = not displacement_cascade0_view.visible


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
