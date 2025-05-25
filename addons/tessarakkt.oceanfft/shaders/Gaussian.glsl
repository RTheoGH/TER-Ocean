#[compute]
#version 450 core

#define WORK_GROUP_DIM 256 

#extension GL_EXT_shader_atomic_float:enable


layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 27, rg32f) uniform readonly image2D u_input;
layout(set = 0, binding = 28, rg32f) uniform writeonly image2D u_output;
//layout(set = 0, binding = 30, float) uniform writeonly float u_gaussian_average;


shared vec3 color_sum;
shared vec3 variance_sum;
shared int count;

void main(){
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dimensions = imageSize(u_input);

    if (coords.x >= dimensions.x || coords.y >= dimensions.y) {
        return;
    }

    vec2 uv = vec2(coords) / vec2(dimensions);

    int nb_pixels = dimensions.x * dimensions.y;

    vec3 input_color = imageLoad(u_input, coords).rgb;

    //somme des couleurs
    atomicAdd(color_sum.r, input_color.r);
    atomicAdd(color_sum.g, input_color.g);
    atomicAdd(color_sum.b, input_color.b);

    atomicAdd(count, 1);

    barrier(); //on attend les autres threads

    vec3 mean_color = color_sum / nb_pixels;

    atomicAdd( variance_sum.r, (input_color.r - mean_color.r)  * (input_color.r - mean_color.r) );
    atomicAdd( variance_sum.g, (input_color.g - mean_color.g)  * (input_color.g - mean_color.g) );
    atomicAdd( variance_sum.b, (input_color.b - mean_color.b)  * (input_color.b - mean_color.b) );

    barrier();

    vec3 variance_color = variance_sum / nb_pixels;

    vec3 ecart_type = sqrt(variance_color);

    vec3 new_color = (input_color - mean_color) / ecart_type;

    imageStore(u_output, coords, vec4(new_color.x, new_color.y, 0.0,0.0));

    imageStore(u_output, coords, vec4(count, count, 0.0,0.0));

}