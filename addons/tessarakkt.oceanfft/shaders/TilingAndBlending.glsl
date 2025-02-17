#[compute]
#version 450 core

#define WORK_GROUP_DIM 256 

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 27, rg32f) uniform image2D u_input; //la carte de déplacement après fft
layout(set = 0, binding = 28, rg32f) uniform writeonly image2D u_output;

void TriangleGrid(vec2 uv,
	out float w1, out float w2, out float w3,
	out vec2 vertex1, out vec2 vertex2, out vec2 vertex3)
{
	// Scaling of the input
	uv *= 3.464; // 2 * sqrt(3)

	// Skew input space into simplex triangle grid
	const mat2 gridToSkewedGrid = mat2(1.0, 0.0, -0.57735027, 1.15470054);
	vec2 skewedCoord = gridToSkewedGrid * uv;

	// Compute local triangle vertex IDs and local barycentric coordinates
	vec2 baseId = vec2(floor(skewedCoord));
	vec3 temp = vec3(fract(skewedCoord), 0);
	temp.z = 1.0 - temp.x - temp.y;
	if (temp.z > 0.0)
	{
		w1 = temp.z;
		w2 = temp.y;
		w3 = temp.x;
		vertex1 = baseId;
		vertex2 = baseId + vec2(0, 1);
		vertex3 = baseId + vec2(1, 0);
	}
	else
	{
		w1 = -temp.z;
		w2 = 1.0 - temp.y;
		w3 = 1.0 - temp.x;
		vertex1 = baseId + vec2(1, 1);
		vertex2 = baseId + vec2(1, 0);
		vertex3 = baseId + vec2(0, 1);
	}
}

vec2 hash(vec2 p)
{
	return fract(sin((p) * mat2(127.1, 311.7, 269.5, 183.3) )*43758.5453);
}

vec3 get_displacement_tiling(vec2 uv)
{
	// Get triangle info
	float w1, w2, w3;
	vec2 vertex1, vertex2, vertex3;
	TriangleGrid(uv, w1, w2, w3, vertex1, vertex2, vertex3);
		
	// Assign random offset to each triangle vertex
	vec2 uv1 = uv + hash(vec2(vertex1));
	vec2 uv2 = uv + hash(vec2(vertex2));
	vec2 uv3 = uv + hash(vec2(vertex3));

    vec3 I1 = imageLoad(u_input, ivec2(uv1)).rgb;
    vec3 I2 = imageLoad(u_input, ivec2(uv2)).rgb;
    vec3 I3 = imageLoad(u_input, ivec2(uv3)).rgb;
	
	vec3 color = w1 * I1 + w2 * I2 + w3 * I3;

	return color;
}

void main(){
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dimensions = imageSize(u_input);

    if (coords.x >= dimensions.x || coords.y >= dimensions.y) {
        return;
    }

    vec2 uv = vec2(coords) / vec2(dimensions);

    vec3 input_color = get_displacement_tiling(uv);

    

    imageStore(u_output, coords, vec4(input_color,1.0));

}