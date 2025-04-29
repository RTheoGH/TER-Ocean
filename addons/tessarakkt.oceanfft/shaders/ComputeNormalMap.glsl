#[compute]
#version 460 core

#define WORK_GROUP_DIM 256
#define PI 3.14159265358979323846

layout(local_size_x = 32, local_size_y = 32) in;


// displacement map
layout(set = 0 ,binding = 21 , rg32f) uniform image2D u_spectrum_input;

layout(set = 0 , binding = 31 , rgba32f) uniform image2D u_normals_output;


void main(){
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(u_spectrum_input);

    ivec2 left   = max(coord - ivec2(1, 0), ivec2(0));
    ivec2 right  = min(coord + ivec2(1, 0), size - ivec2(1));
    ivec2 up     = max(coord - ivec2(0, 1), ivec2(0));
    ivec2 down   = min(coord + ivec2(0, 1), size - ivec2(1));

    float heightL = imageLoad(u_spectrum_input, left).r;
    float heightR = imageLoad(u_spectrum_input, right).r;
    float heightU = imageLoad(u_spectrum_input, up).r;
    float heightD = imageLoad(u_spectrum_input, down).r;

    float dx = heightR - heightL;
    float dy = heightD - heightU;

    vec3 normal = normalize(vec3(-dx, -dy, 1.0));

    float jacobian = 1.0 - dx * dx - dy * dy; //pas utilise pour l'instant
    jacobian = 1.0;

    imageStore(u_normals_output, coord, vec4(normal * 0.5 + 0.5, jacobian)); 

}



