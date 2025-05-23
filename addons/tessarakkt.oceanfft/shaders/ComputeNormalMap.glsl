#[compute]
#version 460 core

#define WORK_GROUP_DIM 32
#define PI 3.14159265358979323846

layout(local_size_x = 32, local_size_y = 32) in;


// displacement map
layout(set = 0 ,binding = 21 , rg32f) uniform image2D u_spectrum_input;

layout(set = 0 , binding = 31 , rgba32f) uniform image2D u_normals_output;


void main(){
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(u_spectrum_input);
    if (coord.x >= size.x || coord.y >= size.y) return;

    vec2 uv = vec2(coord) / vec2(size);

    float offset = 1.0;

    float hC = imageLoad(u_spectrum_input, coord).r;
    vec3 center = vec3(0.0, hC, 0.0);

    float hR = imageLoad(u_spectrum_input, clamp(coord + ivec2(1, 0), ivec2(0), size - 1)).r;
    float hL = imageLoad(u_spectrum_input, clamp(coord - ivec2(1, 0), ivec2(0), size - 1)).r;
    float hU = imageLoad(u_spectrum_input, clamp(coord - ivec2(0, 1), ivec2(0), size - 1)).r;
    float hD = imageLoad(u_spectrum_input, clamp(coord + ivec2(0, 1), ivec2(0), size - 1)).r;

    vec3 right  = vec3( offset, hR, 0.0) - center;
    vec3 left   = vec3(-offset, hL, 0.0) - center;
    vec3 top    = vec3(0.0, hU, -offset) - center;
    vec3 bottom = vec3(0.0, hD,  offset) - center;

    vec3 n0 = cross(right, top);
    vec3 n1 = cross(top, left);
    vec3 n2 = cross(left, bottom);
    vec3 n3 = cross(bottom, right);

    vec3 normal = normalize((n0 + n1 + n2 + n3) );

    float jxx = right.x / offset;
    float jxy = right.y / offset;
    float jyx = bottom.x / offset;
    float jyy = bottom.y / offset;
    float jacobian = (jxx * jyy) - (jxy * jyx);
    jacobian = 1.0;

    // Output normal in [0,1] range
    imageStore(u_normals_output, coord, vec4(normal * 0.5 + 0.5, jacobian));

}



