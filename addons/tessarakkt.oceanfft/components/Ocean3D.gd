@icon("res://addons/tessarakkt.oceanfft/icons/Ocean3D.svg")
extends Resource
class_name Ocean3D


const UNIFORM_SET := 0
const WORK_GROUP_DIM := 32
const GOLDEN_RATIO := 1.618033989


enum Binding {
	SETTINGS = 0,
	INITIAL_SPECTRUM = 20,
	SPECTRUM = 21,
	PING = 25,
	PONG = 26,
	INPUT = 27,
	OUTPUT = 28,
	TB_DISPLACEMENT = 29,
	GAUSSIAN_AVERAGE = 30,
	LEAN_NORMAL = 31,
	LEAN_B = 32,
	LEAN_M = 33,
}


enum FFTResolution {
	FFT_2x2 = 2,
	FFT_4x4 = 4,
	FFT_8x8 = 8,
	FFT_16x16 = 16,
	FFT_32x32 = 32,
	FFT_64x64 = 64,
	FFT_128x128 = 128,
	FFT_256x256 = 256,
	FFT_512x512 = 512,
	FFT_1024x1024 = 1024,
	FFT_2048x2048 = 2048,
}


## Whether _simulate() should be called by _process(). The simulation_frameskip
## setting will control whether this calls every frame, or skips frames. This
## does not affect the ability to call _simulate() directly, but it probably
## should be disabled if you are calling the simulation directly.
@export var simulation_enabled := true

## The vertex and shader that will use the generated displacement maps to deform
## the surface geometry and apply visual shading.
@export var material:ShaderMaterial = preload("res://addons/tessarakkt.oceanfft/Ocean.tres")

@export_group("Simulation Settings")

## Controls how many frames the _process() skips calling _simulate().
## For a smooth visual simulation, _simulate() should be called at least 30
## frames per second (FPS / (frameskip + 1) >= 30).
## Set to 0 to disable frame skip.
@export_range(0, 30, 1) var simulation_frameskip := 0

## Controls how frequently _process() requests a heightmap sync when calling
## _simulate(). This is used by the buoyancy system, high frameskip settings
## may cause floating objects to appear disconnected from the rendered waves.
## When used in conjunction with simulation_frameskip, this will only count
## frames where _simulate() was called by _process().
## Set to -1 to disable heightmap sync (breaks buoyancy).
## Set to 0 to disable heightmap sync frame skip.
@export_range(-1, 30, 1) var heightmap_sync_frameskip := 0

## The resolution to generate the displacement maps at via FFT in the compute
## shaders.
@export var fft_resolution:FFTResolution = FFTResolution.FFT_256x256:
	set(new_fft_resolution):
		fft_resolution = new_fft_resolution
		_is_initial_spectrum_changed = true

## The horizontal distance the ocean patch should be simulated for.
@export_range(0, 4096) var horizontal_dimension := 4096:
	set(new_horizontal_dimension):
		horizontal_dimension = new_horizontal_dimension
		_is_initial_spectrum_changed = true

## The time scale for the simulation. Speeds up or slows down the waves.
@export_range(0.001, 5.0) var time_scale := 1.0

## The wave number ranges of the wave energy spectrum that each displacement
## cascade covers.
@export var cascade_range:Vector2 = Vector2(0,1)

## The UV scales applied to each displacement map cascade when applied to the
## surface geometry.
@export var cascade_scale: float = 1.0


@export_group("Surface Deform Modifiers")

## Reduce the height of the ocean surface exponentially as distance from the
## camera increases. Simulates planetary curve.
@export_range(0.0, 0.001, 0.0000001) var planetary_curve_strength := 0.000001:
	set(new_planetary_curve_strength):
		planetary_curve_strength = new_planetary_curve_strength
		material.set_shader_parameter("planetary_curve_strength", planetary_curve_strength)

@export_subgroup("Amplitude Distance Fade")

## Amplitude scale applied to the ocean surface at amplitude_scale_fade_distance
## from the camera.
@export_range(0.0, 5.0, 0.01) var amplitude_scale_min := 0.25:
	set(new_amplitude_scale_min):
		amplitude_scale_min = new_amplitude_scale_min
		material.set_shader_parameter("amplitude_scale_min", amplitude_scale_min)

## Amplitude scale applied to the ocean surface near the camera.
@export_range(0.0, 5.0, 0.01) var amplitude_scale_max := 1.0:
	set(new_amplitude_scale_max):
		amplitude_scale_max = new_amplitude_scale_max
		material.set_shader_parameter("amplitude_scale_max", amplitude_scale_max)

## Linear interpolate between amplitude_scale_min at 0 units from camera, and
## amplitude_scale_max at amplitude_scale_fade_distance units from camera.
@export_range(0.0, 32000.0, 10.0) var amplitude_scale_fade_distance := 12000.0:
	set(new_amplitude_scale_fade_distance):
		amplitude_scale_fade_distance = new_amplitude_scale_fade_distance
		material.set_shader_parameter("amplitude_scale_fade_distance", amplitude_scale_fade_distance)

@export_subgroup("Domain Warp")

## Noise texture used to domain warp the displacement maps as they are applied
## to the surface.
@export var domain_warp_texture:NoiseTexture2D:
	set(new_domain_warp_texture):
		material.set_shader_parameter("domain_warp_texture", new_domain_warp_texture)
		domain_warp_texture = new_domain_warp_texture
		await new_domain_warp_texture.changed
		_domain_warp_image = new_domain_warp_texture.get_image()

## Controls how much distortion is applied to the displacement map domain warp
@export_range(0.0, 5000.0) var domain_warp_strength := 1500.0:
	set(new_domain_warp_strength):
		material.set_shader_parameter("domain_warp_strength", new_domain_warp_strength)
		domain_warp_strength = new_domain_warp_strength

## Controls how large the domain_warp_texture is stretched horizontally.
## Smaller numbers result in more horizontal stretching.
## To stretch the texture to cover X world units, set this value to 1.0 / X
@export_range(0.0, 1.0, 0.0000001) var domain_warp_uv_scale := 0.0000625:
	set(new_domain_warp_uv_scale):
		material.set_shader_parameter("domain_warp_uv_scale", new_domain_warp_uv_scale)
		domain_warp_uv_scale = new_domain_warp_uv_scale


@export_group("Weather Settings")

## Wave choppiness value. Higher values give waves sharper crests, but can cause
## wave geometry to fold in over itself.
@export_range(0.0, 10.0) var choppiness := 1.5:
	set(new_choppiness):
		choppiness = new_choppiness

## The wind direction.
@export_range(0.0, 360.0) var wind_direction_degrees := 0.0:
	set(new_wind_direction_degrees):
		wind_direction_degrees = clamp(new_wind_direction_degrees, 0.0, 360.0)
		wind_direction = deg_to_rad(new_wind_direction_degrees)
	get:
		return rad_to_deg(wind_direction)

## Controls how much the generated displacement maps are scrolled horizontally
## over time.
@export_range(-10.0, 10.0) var wave_scroll_speed := 0.0

## The speed of the wind passed to the wave simulation.
@export_range(0.0, 1000.0) var wind_speed := 300.0:
	set(new_wave_length):
		wave_vector = wave_vector.normalized() * new_wave_length
	get:
		return wave_vector.length()


var initialized := false

## The "accumulated wind" that has blown, for wave scrolling from wind.
## Updated each frame by Ocean3D._process()
var wind_uv_offset := Vector2.ZERO

## The wind direction.
var wind_direction := 0.0

## TODO: figure out what this is actually supposed to do
var wave_vector := Vector2(300.0, 0.0):
	set(new_wave_vector):
		wave_vector = new_wave_vector
		_is_initial_spectrum_changed = true


var _uv_scale := 0.00390625

var _rd:RenderingDevice = RenderingServer.get_rendering_device()

var _fmt_r32f := RDTextureFormat.new()
var _fmt_rg32f := RDTextureFormat.new()
var _fmt_rgba32f := RDTextureFormat.new()

var _fmt_rg32f_mm := RDTextureFormat.new()

var _initial_spectrum_shader:RID
var _initial_spectrum_pipeline:RID
var _is_initial_spectrum_changed := true
var _initial_spectrum_settings_buffer: RID
var _initial_spectrum_settings_uniform: RDUniform
var _initial_spectrum_uniform:RDUniform
var _initial_spectrum_tex:RID

var _phase_shader:RID
var _phase_pipeline:RID
var _phase_settings_buffer:RID
var _phase_settings_uniform := RDUniform.new()
var _ping_uniform:RDUniform
var _pong_uniform:RDUniform
var _ping_image:Image
var _ping_tex:RID
var _pong_tex:RID

var _spectrum_shader:RID
var _spectrum_pipeline:RID
var _is_spectrum_changed := true
var _spectrum_settings_buffer:RID
var _spectrum_settings_uniform := RDUniform.new()
var _spectrum_uniform:RDUniform
var _spectrum_tex:RID

var _fft_horizontal_shader:RID
var _fft_horizontal_pipeline:RID
var _fft_vertical_shader:RID
var _fft_vertical_pipeline:RID
var _fft_settings_buffer:RID
var _fft_settings_uniform := RDUniform.new()
var _sub_pong_uniform := RDUniform.new()
var _sub_pong_tex:RID

var _tb_shader:RID
var _tb_pipeline:RID
var _tb_settings_buffer:RID
var _tb_settings_uniform := RDUniform.new()
var _tb_uniform:RDUniform

var _gaussian_average_uniform: RDUniform = RDUniform.new()

var _waves_image:Image
var _waves_texture:Texture2DRD


## lean mapping normal 
var _lean_normal_shader:RID
var _lean_normal_pipeline:RID
var _lean_normal_settings_buffer:RID
var _lean_normal_settings_uniform := RDUniform.new()
var _lean_normal_uniform:RDUniform
var _lean_normal_tex : RID
var _lean_normal_image:Image
var _lean_normal_texture:Texture2DRD

## lean mapping B et M
var _lean_BM_shader:RID
var _lean_BM_pipeline:RID
var _lean_BM_settings_buffer:RID
var _lean_BM_settings_uniform := RDUniform.new()
var _lean_B_uniform:RDUniform
var _lean_M_uniform:RDUniform
var _lean_B_tex:RID
var _lean_M_tex:RID
var _lean_B_image:Image
var _lean_M_image:Image
var _lean_B_texture:Texture2DRD
var _lean_M_texture:Texture2DRD


var _is_ping_phase := true

var _frameskip := 0
var _heightmap_sync_frameskip := 0
var _accumulated_delta := 0.0

var _domain_warp_image:Image

var _rng := RandomNumberGenerator.new()

var _tb_enabled := true
var _tb_scale := 20.0

## Initialize the simulation
func initialize_simulation() -> void:
	_rng.randomize()
	material.set_shader_parameter("tb_enabled", _tb_enabled)
	material.set_shader_parameter("tb_scale", _tb_scale)
	RenderingServer.call_on_render_thread(_initialize_simulation)


## Simulate a single iteration of the ocean. Respects frameskip and simulation
## enabled settings.
func simulate(delta:float) -> void:
	assert(initialized, "Ocean3D not initialized")
	
	if simulation_enabled:
		_accumulated_delta += delta
		
		wind_uv_offset += Vector2(cos(wind_direction), sin(wind_direction)) * wave_scroll_speed * delta
		material.set_shader_parameter("wind_uv_offset", wind_uv_offset)
		
		if simulation_frameskip > 0:
			_frameskip += 1
			if _frameskip <= simulation_frameskip:
				return
			else:
				_frameskip = 0
		
		var sync_heightmap := heightmap_sync_frameskip != -1
		if heightmap_sync_frameskip > 0:
			_heightmap_sync_frameskip += 1
			if _heightmap_sync_frameskip <= heightmap_sync_frameskip:
				sync_heightmap = false
			else:
				sync_heightmap = true
				_heightmap_sync_frameskip = 0
		
		RenderingServer.call_on_render_thread(_simulate.bind(_accumulated_delta, sync_heightmap))
		_accumulated_delta = 0.0


## Simulate a single iteration of the ocean. Ignores frameskip and simulation
## enabled settings.
func force_simulate(delta:float, sync_heightmap:bool = false) -> void:
	RenderingServer.call_on_render_thread(_simulate.bind(delta, sync_heightmap))


## Convert a global position (on the horizontal XZ plane) to a pixel coordinate
## for sampling the wave displacement texture directly. The Y coordinate is
## ignored.
func global_to_pixel(camera:Camera3D, global_pos:Vector3, apply_domain_warp:bool = true) -> Vector2i:
	## The order of operations in this function is dependent on the order of
	## operations used in the vertex shader to rotate and scale the displacement
	## map before applying it. Make sure to check if the vertex shader should be
	## updated to account for any changes made here.
	
	assert(initialized, "Ocean3D not initialized")
	
	## Convert to UV coordinate
	## The visual shader uses the global XZ coordinates as UV
	var uv_pos := Vector2.ZERO
	uv_pos.x = global_pos.x
	uv_pos.y = global_pos.z
	
	## Apply domain warp
	if apply_domain_warp and _domain_warp_image != null:
		var linear_dist:float = (global_pos - camera.global_position).length()
		
		## Recursive call; note that it is called with the apply_domain_warp
		## parameter set to false to avoid infinite recursion.
		var base_pixel_pos := global_to_pixel(camera, global_pos, false)
		var domain_warp := Vector2(
				_domain_warp_image.get_pixelv(base_pixel_pos * domain_warp_uv_scale).r,
				_domain_warp_image.get_pixelv(-base_pixel_pos * domain_warp_uv_scale).r)
		domain_warp *= domain_warp_strength * (linear_dist / camera.far)
		uv_pos += domain_warp
	
	## Apply UV scale
	uv_pos *= _uv_scale
	uv_pos *= 1.0 / cascade_scale
	
	## Offset by wind scrolling
	uv_pos += wind_uv_offset * cascade_scale
	
	## Normalize values to 0.0-1.0
	uv_pos.x -= floorf(uv_pos.x)
	uv_pos.y -= floorf(uv_pos.y)
	
	## Convert to pixel coordinate
	var pixel_pos := Vector2i.ZERO
	pixel_pos.x = floor((fft_resolution - 1) * uv_pos.x)
	pixel_pos.y = floor((fft_resolution - 1) * uv_pos.y)
	
	return pixel_pos


## Query the wave height at a given location on the horizontal XZ plane. The Y
## coordinate is ignored, and global position in this context is the position
## relative to the oceans parent node. Since each pixel encodes both a vertical
## and horizontal displacement, we need to offset the horizontal displacement 
## and resample a few times to get an accurate height. The number of resample
## iterations is defined by steps parameter.
func get_wave_height(camera:Camera3D, global_pos:Vector3, max_cascade:int = 1, steps:int = 2) -> float:
	assert(initialized, "Ocean3D not initialized")
	
	var pixel:Color
	var xz_offset := Vector3.ZERO
	var total_height := 0.0
	var linear_dist := (global_pos - camera.global_position).length()
	
	## Wave Displacements
	for cascade in range(max_cascade):
		for i in range(steps):
			var pixel_pos := global_to_pixel(camera, global_pos - xz_offset)
			
			pixel = _waves_image.get_pixelv(pixel_pos)
			xz_offset.x += pixel.r
			xz_offset.z += pixel.b
		
		total_height += pixel.g
		xz_offset = Vector3.ZERO
	
	## Wave Amplitude Distance Fade
	var amplitude_fade_range:float = clamp(linear_dist, 0.0, amplitude_scale_fade_distance) / amplitude_scale_fade_distance
	total_height *= lerp(amplitude_scale_max, amplitude_scale_min, amplitude_fade_range)
	
	## Planetary Curve
	var curvation:float = planetary_curve_strength * (pow(global_pos.x - camera.global_position.x, 2.0) + pow(global_pos.y - camera.global_position.z, 2.0))
	total_height -= curvation;
	
	return total_height


## Get the wave displacement map of a single cascade as an Image.
## This returns the displacement map already cached on the CPU, it will not
## call _simulate(), or marshall additional data from the GPU.
func get_waves() -> Image:
	assert(initialized, "Ocean3D not initialized")
	return _waves_image


## Get the wave displacement map of a single cascade as a Texture2DRD.
func get_waves_texture() -> Texture2DRD:
	assert(initialized, "Ocean3D not initialized")
	return _waves_texture

func get_lean_normal() -> Image:
	assert(initialized, "Ocean3D not initialized")
	return _lean_normal_image

func get_lean_normal_texture() -> Texture2DRD:
	assert(initialized, "Ocean3D not initialized")
	return _lean_normal_texture

func get_lean_B() -> Image:
	assert(initialized, "Ocean3D not initialized")
	return _lean_B_image

func get_lean_B_texture() -> Texture2DRD:
	assert(initialized, "Ocean3D not initialized")
	return _lean_B_texture

func get_lean_M() -> Image:
	assert(initialized, "Ocean3D not initialized")
	return _lean_M_image

func get_lean_M_texture() -> Texture2DRD:
	assert(initialized, "Ocean3D not initialized")
	return _lean_M_texture

func _pack_initial_spectrum_settings() -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scale]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([cascade_range.x, cascade_range.y, wave_vector.x, wave_vector.y]).to_byte_array())
	return settings_bytes


func _pack_phase_settings(delta_time:float) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scale]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([delta_time]).to_byte_array())
	return settings_bytes


func _pack_spectrum_settings() -> PackedByteArray:
	var settings_bytes = PackedInt32Array([horizontal_dimension * cascade_scale]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([choppiness, fft_resolution]).to_byte_array())
	return settings_bytes


func _pack_fft_settings(subseq_count:int) -> PackedByteArray:
	return PackedInt32Array([fft_resolution, subseq_count]).to_byte_array()


#### Render Thread Code
################################################################################
## All code below this point must be run on the main render thread via
## RenderingServer.call_on_render_thread().


## Initialize the ocean simulation. Compiles shaders, prepares texture and
## settings buffers.
## This must be called via RenderingServer.call_on_render_thread().
func _initialize_simulation() -> void:
	var shader_file:Resource
	var settings_bytes:PackedByteArray
	var initial_image_rf := Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
	var initial_image_rgf := Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
	
	#### Initialize RDTextureFormats
	############################################################################
	## These are initialized once and reused as needed.
	
	_fmt_r32f.width = fft_resolution
	_fmt_r32f.height = fft_resolution
	_fmt_r32f.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	_fmt_r32f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	_fmt_rg32f.width = fft_resolution
	_fmt_rg32f.height = fft_resolution
	_fmt_rg32f.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	_fmt_rg32f.usage_bits = _fmt_r32f.usage_bits
	
	_fmt_rgba32f.width = fft_resolution
	_fmt_rgba32f.height = fft_resolution
	_fmt_rgba32f.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	_fmt_rgba32f.usage_bits = _fmt_r32f.usage_bits


	_fmt_rg32f_mm.width = fft_resolution
	_fmt_rg32f_mm.height = fft_resolution
	_fmt_rg32f_mm.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	_fmt_rg32f_mm.usage_bits = _fmt_r32f.usage_bits
	_fmt_rg32f_mm.mipmaps = 8
	
	#### Compile & Initialize Initial Spectrum Shader
	############################################################################
	## The Initial Spectrum texture is initialized empty. It will be generated
	## by the Initial Spectrum shader based on the wind, FFT resolution, and
	## horizontal dimension inputs. It will be static and constant for a given
	## set of inputs, and doesn't need to be recalculated per frame, only when
	## inputs change.
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/InitialSpectrum.glsl")
	_initial_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_initial_spectrum_pipeline = _rd.compute_pipeline_create(_initial_spectrum_shader)

	

	## Initialize Settings Buffer
	settings_bytes = _pack_initial_spectrum_settings()
	_initial_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_initial_spectrum_settings_uniform = RDUniform.new()
	_initial_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_initial_spectrum_settings_uniform.binding = Binding.SETTINGS
	_initial_spectrum_settings_uniform.add_id(_initial_spectrum_settings_buffer)

	## Initialized empty, it will be generated on the first frame
	_initial_spectrum_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [initial_image_rf.get_data()])
	_initial_spectrum_uniform = RDUniform.new()
	_initial_spectrum_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_initial_spectrum_uniform.binding = Binding.INITIAL_SPECTRUM
	_initial_spectrum_uniform.add_id(_initial_spectrum_tex)
	
	#### Compile & Initialize Phase Shader
	############################################################################
	## Applies time based flow to a crafted random data spectrum.
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/Phase.glsl")
	_phase_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_phase_pipeline = _rd.compute_pipeline_create(_phase_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_phase_settings(0.0)
	_phase_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_phase_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_phase_settings_uniform.binding = Binding.SETTINGS
	_phase_settings_uniform.add_id(_phase_settings_buffer)
	
	#### Initialize Ping Pong Buffer Textures
	############################################################################
	## These act as the input and output buffers for the Phase shader.
	##
	## They are a form of double buffer to work around the fact that due to
	## asynchronous execution, the shader can't safely read and write from the
	## same texture in the same execution.
	##
	## On even numbered frames (the "ping phase"), we read from the Ping buffer.
	## The output is written to the Pong buffer.
	## On odd numbered frames ("pong phase"), we do the opposite, we read from
	## Pong, and write to Ping.
	##
	## On first start up, Ping gets initialized with crafted random data.
	
	var ping_data:PackedFloat32Array = []
	
	## The Ping buffer must be initialized with this crafted randomized data
	for i in range(fft_resolution * fft_resolution):
		if ping_data.append(_rng.randf_range(0.0, 1.0) * 2.0 * PI):
			print("error generating initial ping data")
	
	_ping_image = Image.create_from_data(fft_resolution, fft_resolution, false, Image.FORMAT_RF, ping_data.to_byte_array())
	_ping_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_ping_image.get_data()])
	_ping_uniform = RDUniform.new()
	_ping_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_ping_uniform.binding = Binding.PING
	_ping_uniform.add_id(_ping_tex)
	
	## The Pong buffer is initialized empty; it will be generated as the output
	## of the first iteration of the Phase shader based on the Ping input
	_pong_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [initial_image_rf.get_data()])
	_pong_uniform = RDUniform.new()
	_pong_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_pong_uniform.binding = Binding.PONG
	_pong_uniform.add_id(_pong_tex)
	
	#### Compile & Initialize Spectrum Shader
	############################################################################
	## Merges the weather parameters calculated in the Initial Spectrum with the
	## crafted time varying randomness calculated in Phase (and stored in the
	## Ping/Pong textures)
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/Spectrum.glsl")
	_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_spectrum_pipeline = _rd.compute_pipeline_create(_spectrum_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_spectrum_settings()
	_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_spectrum_settings_uniform.binding = Binding.SETTINGS
	_spectrum_settings_uniform.add_id(_spectrum_settings_buffer)
	

	## Initialized empty, it will be generated each frame
	_spectrum_tex = _rd.texture_create(_fmt_rg32f, RDTextureView.new(), [initial_image_rgf.get_data()])
	_spectrum_uniform = RDUniform.new()
	_spectrum_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_spectrum_uniform.binding = Binding.SPECTRUM
	_spectrum_uniform.add_id(_spectrum_tex)

	## Lean mapping init

	#lean normal

	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/ComputeNormalMap.glsl")
	_lean_normal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_lean_normal_pipeline = _rd.compute_pipeline_create(_lean_normal_shader)

	_lean_normal_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_lean_normal_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_lean_normal_settings_uniform.binding = Binding.SETTINGS
	_lean_normal_settings_uniform.add_id(_lean_normal_settings_buffer)

	_lean_normal_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF)
	

	_lean_normal_tex = _rd.texture_create(_fmt_rgba32f, RDTextureView.new(), [_lean_normal_image.get_data()])
	_lean_normal_uniform = RDUniform.new()
	_lean_normal_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_lean_normal_uniform.binding = Binding.LEAN_NORMAL
	_lean_normal_uniform.add_id(_lean_normal_tex)

	_lean_normal_texture = Texture2DRD.new()
	_lean_normal_texture.texture_rd_rid = _lean_normal_tex

	# Lean B et M 
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/ComputeLeanBM.glsl")
	_lean_BM_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_lean_BM_pipeline = _rd.compute_pipeline_create(_lean_BM_shader)

	_lean_BM_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_lean_BM_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_lean_BM_settings_uniform.binding = Binding.SETTINGS
	_lean_BM_settings_uniform.add_id(_lean_BM_settings_buffer)

	# B
	_lean_B_image = Image.create(fft_resolution, fft_resolution, true, Image.FORMAT_RGF)

	print(_lean_B_image.get_mipmap_count())
	_lean_B_image.generate_mipmaps()

	#_lean_B_tex = _rd.texture_create(_fmt_rg32f_mm, RDTextureView.new(), [_lean_B_image.get_data()])
	_lean_B_tex = _rd.texture_create(_fmt_rg32f_mm, RDTextureView.new(), [])
	_lean_B_uniform = RDUniform.new()
	_lean_B_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_lean_B_uniform.binding = Binding.LEAN_B
	_lean_B_uniform.add_id(_lean_B_tex)

	_lean_B_texture = Texture2DRD.new()
	_lean_B_texture.texture_rd_rid = _lean_B_tex

	# M
	_lean_M_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF)

	_lean_M_tex = _rd.texture_create(_fmt_rgba32f, RDTextureView.new(), [_lean_M_image.get_data()])
	_lean_M_uniform = RDUniform.new()
	_lean_M_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_lean_M_uniform.binding = Binding.LEAN_M
	_lean_M_uniform.add_id(_lean_M_tex)
	
	_lean_M_texture = Texture2DRD.new()
	_lean_M_texture.texture_rd_rid = _lean_M_tex
	
	## Bind the displacement map cascade texture to the visual shader
	_waves_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
	_waves_texture = Texture2DRD.new()
	_waves_texture.texture_rd_rid = _spectrum_tex


	
	
	material.set_shader_parameter("cascade_displacements", _waves_texture)
	material.set_shader_parameter("cascade_uv_scales", cascade_scale)
	material.set_shader_parameter("uv_scale", _uv_scale)

	material.set_shader_parameter("lean_normal_texture", _lean_normal_texture)
	material.set_shader_parameter("lean_B_texture", _lean_B_texture)
	material.set_shader_parameter("lean_M_texture", _lean_M_texture)
	
	
	#### Compile & Initialize FFT Shaders
	############################################################################
	## Converts the result of the Spectrum shader into a usable displacement map.
	##
	## Uses the Spectrum texture and SubPong texture as ping pong buffers. The
	## resulting displacement map will be stored in the Specturm texture.
	
	## Compile Shaders
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/FFTHorizontal.glsl")
	_fft_horizontal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_horizontal_pipeline = _rd.compute_pipeline_create(_fft_horizontal_shader)
	
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/FFTVertical.glsl")
	_fft_vertical_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_vertical_pipeline = _rd.compute_pipeline_create(_fft_vertical_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_fft_settings(0)
	_fft_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_fft_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_fft_settings_uniform.binding = Binding.SETTINGS
	_fft_settings_uniform.add_id(_fft_settings_buffer)
	
	## Initialize empty, will be calculated based on the Spectrum
	_sub_pong_tex = _rd.texture_create(_fmt_rg32f, RDTextureView.new(), [initial_image_rgf.get_data()])
	_sub_pong_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_sub_pong_uniform.add_id(_sub_pong_tex)
	



	initialized = true



## Simulate a single iteration of the ocean. The resulting displacement map
## texture can be retrieved using the get_waves_texture() function, or as an
## Image via get_waves(). The texture is the same buffer in VRAM the compute
## shaders operate on. The image is stored in CPU RAM and is only updated when
## sync_heightmap is true.
## This must be called via RenderingServer.call_on_render_thread().
func _simulate(delta: float, sync_heightmap: bool) -> void:
	if _is_initial_spectrum_changed:
		_run_initial_spectrum_pass()
	_run_phase_pass(delta)
	_run_spectrum_pass()
	_run_fft_passes()

	_run_lean_normal_pass()
	_run_lean_mapping_pass()

	_is_ping_phase = not _is_ping_phase



func _run_lean_normal_pass() -> void:
	#_update_buffer(_lean_normal_settings_buffer, _pack_phase_settings(0.0), "lean normal settings")
	
	_spectrum_uniform.binding = Binding.SPECTRUM

	var uniform_set := _create_uniform_set([

		_lean_normal_uniform,
		_spectrum_uniform
	], _lean_normal_shader)

	_dispatch_compute(_lean_normal_pipeline, uniform_set, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM)

	_rd.free_rid(uniform_set)

func _run_lean_mapping_pass() -> void:
	#_update_buffer(_lean_normal_settings_buffer, _pack_phase_settings(0.0), "lean mapping settings")

	var uniform_set := _create_uniform_set([
		_lean_normal_uniform,
		_lean_B_uniform,
		_lean_M_uniform,
	], _lean_BM_shader)

	_dispatch_compute(_lean_BM_pipeline, uniform_set, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM)

	_rd.free_rid(uniform_set)


#### Update Initial Spectrum
########################################################################
## Only executed on first frame, or if Wind, FFT Resolution, or
## Horizontal Dimension inputs are changed, as the output is constant
## for a given set of inputs. The Initial Spectrum is cached in VRAM. It
## is not returned to CPU RAM.
func _run_initial_spectrum_pass() -> void:
	_update_buffer(_initial_spectrum_settings_buffer, _pack_initial_spectrum_settings(), "initial spectrum settings")

	var uniform_set := _create_uniform_set([
		_initial_spectrum_settings_uniform,
		_initial_spectrum_uniform
	], _initial_spectrum_shader)

	_dispatch_compute(_initial_spectrum_pipeline, uniform_set, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM)

	_rd.free_rid(uniform_set)

#### Execute Phase Shader; Updates Ping Pong Buffers
########################################################################
func _run_phase_pass(delta: float) -> void:
	_swap_ping_pong_bindings()

	_update_buffer(_phase_settings_buffer, _pack_phase_settings(delta * time_scale), "phase settings")

	var uniform_set := _create_uniform_set([
		_phase_settings_uniform,
		_ping_uniform,
		_pong_uniform
	], _phase_shader)

	_dispatch_compute(_phase_pipeline, uniform_set, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM)

	_rd.free_rid(uniform_set)

#### Execute Spectrum Shader Cascades
########################################################################
func _run_spectrum_pass() -> void:
	_update_buffer(_spectrum_settings_buffer, _pack_spectrum_settings(), "spectrum settings")

	_spectrum_uniform.binding = Binding.SPECTRUM

	var uniform_set := _create_uniform_set([
		_spectrum_settings_uniform,
		_initial_spectrum_uniform,
		_spectrum_uniform,
		_ping_uniform,
		_pong_uniform
	], _spectrum_shader)

	_dispatch_compute(_spectrum_pipeline, uniform_set, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM)

	_rd.free_rid(uniform_set)

#### Execute FFT Shaders
########################################################################
func _run_fft_passes() -> void:
	var is_sub_ping_phase := true
	var p := 1
	while p < fft_resolution:
		is_sub_ping_phase = _run_fft_pass(p, is_sub_ping_phase, true)
		p <<= 1

	p = 1
	while p < fft_resolution:
		is_sub_ping_phase = _run_fft_pass(p, is_sub_ping_phase, false)
		p <<= 1


func _run_fft_pass(p: int, is_sub_ping_phase: bool, is_horizontal: bool) -> bool:
	var shader
	var pipeline
	var label

	if is_horizontal:
		shader = _fft_horizontal_shader
		pipeline = _fft_horizontal_pipeline
		label = "horizontal FFT"
	else:
		shader = _fft_vertical_shader
		pipeline = _fft_vertical_pipeline
		label = "vertical FFT"

	if is_sub_ping_phase:
		_spectrum_uniform.binding = Binding.INPUT
		_sub_pong_uniform.binding = Binding.OUTPUT
	else:
		_spectrum_uniform.binding = Binding.OUTPUT
		_sub_pong_uniform.binding = Binding.INPUT

	_update_buffer(_fft_settings_buffer, _pack_fft_settings(p), label)

	var uniform_set := _create_uniform_set([
		_fft_settings_uniform,
		_sub_pong_uniform,
		_spectrum_uniform
	], shader)

	_dispatch_compute(pipeline, uniform_set, fft_resolution, 1)

	_rd.free_rid(uniform_set)

	return not is_sub_ping_phase


func _update_buffer(buffer: RID, data: PackedByteArray, label: String) -> void:
	if _rd.buffer_update(buffer, 0, data.size(), data) != OK:
		print("error updating %s buffer" % label)


func _create_uniform_set(uniforms: Array, shader: RID) -> RID:
	return _rd.uniform_set_create(uniforms, shader, UNIFORM_SET)


#Lance le compute Shader
func _dispatch_compute(pipeline: RID, uniform_set: RID, x: int, y: int, z: int = 1) -> void:
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
	_rd.compute_list_dispatch(compute_list, x, y, z)
	_rd.compute_list_end()


func _swap_ping_pong_bindings() -> void:
	if _is_ping_phase:
		_ping_uniform.binding = Binding.PING
		_pong_uniform.binding = Binding.PONG
	else:
		_ping_uniform.binding = Binding.PONG
		_pong_uniform.binding = Binding.PING
