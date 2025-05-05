#[compute]
#version 460 core

#define WORK_GROUP_DIM 256
#define PI 3.14159265358979323846

//layout(local_size_x = WORK_GROUP_DIM) in;
layout(local_size_x = 32, local_size_y = 32) in;

//input/output

//normal map -> rgba cuz vec4
layout(set = 0 ,binding = 31 , rgba32f) uniform image2D u_normals_input;

//M and B (maybe change from sampler to image but idk LeWhatdatmean yet)
layout(set = 0 , binding = 32 , rg32f) uniform image2D u_B_output; //rg cuz xy
layout(set = 0 , binding = 33 , rgba32f) uniform image2D u_M_output; //rgv cuz xyz

void main(){
    //gets the coordinates of a pixel from our texture
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    vec3 normal = imageLoad(u_normals_input, pixel_coord).rgb;

    if (normal.z == 0.0) normal.z = 0.00001;
    vec2 B = normal.xy / normal.z;
    vec3 M = vec3(B.x * B.x, B.y * B.y, B.x * B.y);

    imageStore(u_B_output, pixel_coord, vec4(B, 0.0, 1.0));
    imageStore(u_M_output, pixel_coord, vec4(M, 1.0));

}



