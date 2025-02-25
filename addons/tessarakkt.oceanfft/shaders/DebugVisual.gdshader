shader_type spatial;
render_mode world_vertex_coords, depth_draw_always, cull_disabled;


#include "OceanCommon.gdshaderinc"


// Sun specular highlight
uniform float specular_strength = 1.0;
uniform float specular_power = 1500.0;

// ALPHA will begin decreasing to 0.0 after view_distance_max * view_fade_start
uniform float view_fade_start = 0.95;

// Colors
uniform vec4 deep_color:source_color = vec4(0.004f, 0.016f, 0.047f, 1.0);
uniform vec4 shallow_color:source_color = vec4(0, 0.729412, 0.988235, 1);


group_uniforms Fresnel;
/******************************************************************************/
// Note that PBR specular and metallic settings can significantly affect the
// result of fresnel shading. Consider playing with those settings if fresnel
// shading can't be made to look proper with just these settings.

// Fresnel Shading
uniform float fresnel_offset = 0.02;
uniform float fresnel_strength = 0.0;
uniform float fresnel_power = 5.0;
uniform float fresnel_exposure = 0.03;
uniform vec4 fresnel_sky_color:source_color = vec4(1.6f, 4.8f, 6.4f, 1.0);


group_uniforms PhysicallyBasedRendering;
/******************************************************************************/
uniform float pbr_specular_strength = 0.1;
uniform float pbr_specular_offset = 0.1;
uniform float pbr_metallic_strength = 0.0;


group_uniforms Refraction;
/******************************************************************************/
// TODO: Needs to be completely redone;

uniform float refraction_factor_min = 0.0;
uniform float refraction_factor_max = 0.025;
uniform float refraction_distance_power = 1.55;
uniform float refraction_distance_max = 30000.0;
uniform float refraction_background_brightness = 0.2;

// Adjusts how strong the refraction is based on the distance between the ocean
// pixel and the object behind it.
uniform float refraction_depth_factor = 0.00001;


group_uniforms SubSurfaceScattering;
/******************************************************************************/
uniform float sss_backlight_strength = 0.0125;
uniform float sss_backlight_fov = 10.0;
uniform float sss_backlight_depth = 15.0;
uniform float sss_upwelling = 0.075;
uniform vec4 sss_color:source_color = vec4(0, 0.729412, 0.988235, 1);


group_uniforms Whitecaps;
/******************************************************************************/
// Basic whitecap rendering using Jacobian determinant.
// TODO: Calculate Jacobian and foam in another shader to support temporal
//       effects like foam persisting and bubbling out.

uniform float foam_jacobian_limit = 0.5;
uniform float foam_coverage = 0.1;
uniform float foam_mix_strength = 1.0;
uniform float foam_diffuse_strength = 1.0;
uniform vec4 foam_diffuse_color:source_color = vec4(0.91764706373215, 0.96862745285034, 1.0, 1.0);
uniform sampler2D foam_texture : hint_default_white;


group_uniforms Internal;
/******************************************************************************/
// These are intended to be updated during runtime. Setting values in the editor
// may not have the desired result.

// The vertex resolution of the mesh tiles the shader is applied to.
uniform float vertex_resolution = 256.0;


group_uniforms Internal.WaveDeformModifiers;
/******************************************************************************/
// Adjust the wave displacement maps as they are applied to the surface.
// This will be correctly accounted for by normals and whitecaps.
// Settings will only affect buoyancy if set through Ocean3D

// Simple planetary curve approximation.
// Decrease height of surface exponentially as distance from camera increases.
uniform float planetary_curve_strength = 0.000001;

// Decreases the height of the wave deformation as distance from the camera
// increases.
// This occurs after surface normals and whitecap coverage has been calculated.
uniform float amplitude_scale_min = 0.25;
uniform float amplitude_scale_max = 1.0;
uniform float amplitude_scale_fade_distance = 12000.0;


uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;


// Instance Uniforms
/******************************************************************************/
instance uniform float patch_size = 512.0;
instance uniform float min_lod_morph_distance;
instance uniform float max_lod_morph_distance;



// Varyings
/******************************************************************************/
varying vec3 world_vertex;
varying float jacobian_determinant;
varying float wave_height;
varying float foam_mix_factor;
varying float foam_specular_factor;



void vertex() {
	world_vertex = VERTEX;

}


void fragment() {
	ALBEDO = get_displacement_tiling(world_vertex.xz );
}
