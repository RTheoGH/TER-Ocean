#[compute]
#version 450 core

#define WORK_GROUP_DIM 256 

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 27, rg32f) uniform readonly image2D u_input;
layout(set = 0, binding = 28, rg32f) uniform writeonly image2D u_output;

shared vec3 localSum

void main(){
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dimensions = imageSize(u_input);

    if (coords.x >= dimensions.x || coords.y >= dimensions.y) {
        return;
    }

    vec2 uv = vec2(coords) / vec2(dimensions);

    vec3 input_color = imageLoad(u_input, coords).rgb;

    imageStore(u_output, coords, vec4(input_color,1.0));

}