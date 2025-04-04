#[compute]
#version 460 core

#define WORK_GROUP_DIM 256
#define PI 3.14159265358979323846

layout(local_size_x = WORK_GROUP_DIM) in;

layout(set = 0 ,binding = 30 , rgba16f) uniform readonly image2D displacement_tex;  
layout(set = 0 ,binding = 31, rgba16f) uniform writeonly image2D normal_tex; 

// layout(set = 0, binding = 0) buffer UniformsBuffer {
//     int total_count;
//     int subseq_count;
// } u;


void main() {
    //stole that from normals_jacobians from the vertex shader
    //will need to adapt to using tiling and blending prolly

    //FIXME : i'm just using this as a placeholder to work with ivec2 instead of vec2
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(coord) + 0.5) / vec2(imageSize(displacement_tex));
    float offset = 1.0;

    vec3 displacement = vec3(0.0, imageLoad(displacement_tex, coord).y, 0.0);

    vec3 right = vec3(offset, imageLoad(displacement_tex, coord + ivec2(offset, 0)).y, 0.0) - displacement;
    vec3 left = vec3(-offset, imageLoad(displacement_tex, coord + ivec2(-offset, 0)).y, 0.0) - displacement;
    vec3 bottom = vec3(0.0, imageLoad(displacement_tex, coord + ivec2(0, offset)).y, offset) - displacement;
    vec3 top = vec3(0.0, imageLoad(displacement_tex, coord + ivec2(0, -offset)).y, -offset) - displacement;

    vec3 top_right = cross(right, top);
    vec3 top_left = cross(top, left);
    vec3 bottom_left = cross(left, bottom);
    vec3 bottom_right = cross(bottom, right);   
    
    vec3 normal = normalize(top_right + top_left + bottom_left + bottom_right);

    imageStore(normal_tex, coord, vec4(normal, 1.0));
}
