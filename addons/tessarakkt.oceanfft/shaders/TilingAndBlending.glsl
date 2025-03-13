#[compute]
#version 450 core

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 27, rg32f) uniform image2D u_input; // Displacement map (after FFT)
layout(set = 0, binding = 28, rg32f) uniform writeonly image2D u_output;

//
// A simple hash function returning a value in [0,1)
//
vec2 hash(vec2 p) {
    return fract(sin(p * mat2(127.1, 311.7,
                                269.5, 183.3)) * 43758.5453);
}

//
// TriangleGrid computes a simplex triangle grid from the normalized uv,
// returning barycentrics (w1, w2, w3) and vertex IDs (in grid space).
//
void TriangleGrid(in vec2 uv,
	out float w1, out float w2, out float w3,
	out vec2 vertex1, out vec2 vertex2, out vec2 vertex3)
{
    // Scale UV to set the tiling frequency (here 3.464 = 2*sqrt(3))
    vec2 uvScaled = uv * 3.464;

    // Skew the input space into a simplex (triangular) grid
    const mat2 gridToSkewedGrid = mat2(1.0, 0.0,
                                      -0.57735027, 1.15470054);
    vec2 skewedCoord = gridToSkewedGrid * uvScaled;

    // Get the integer cell (baseId) and the fractional part (local coordinates)
    vec2 baseId = floor(skewedCoord);
    vec3 temp = vec3(fract(skewedCoord), 0.0);
    temp.z = 1.0 - temp.x - temp.y;
    
    // Depending on which side of the triangle the point falls, choose the vertices and barycentrics.
    if (temp.z > 0.0) {
        w1 = temp.z;
        w2 = temp.y;
        w3 = temp.x;
        vertex1 = baseId;
        vertex2 = baseId + vec2(0.0, 1.0);
        vertex3 = baseId + vec2(1.0, 0.0);
    } else {
        w1 = -temp.z;
        w2 = 1.0 - temp.y;
        w3 = 1.0 - temp.x;
        vertex1 = baseId + vec2(1.0, 1.0);
        vertex2 = baseId + vec2(1.0, 0.0);
        vertex3 = baseId + vec2(0.0, 1.0);
    }
}

//
// This function computes the displacement tiling effect by
// computing a triangle grid, offsetting the UV coordinates via a hash,
// sampling three points from the input displacement texture, and blending them
// using the barycentrics.
//
vec3 get_displacement_tiling(vec2 uv) {
    // Get triangle grid info
    float w1, w2, w3;
    vec2 vertex1, vertex2, vertex3;
    TriangleGrid(uv, w1, w2, w3, vertex1, vertex2, vertex3);
		
    // Offset the input uv by a random (hash-based) amount for each vertex
    vec2 uv1 = uv + hash(vertex1);
    vec2 uv2 = uv + hash(vertex2);
    vec2 uv3 = uv + hash(vertex3);

    // Get the texture dimensions so we can sample in pixel space
    ivec2 dims = imageSize(u_input);
    // Use fract() to tile the displacement map, then scale to pixel coordinates.
    vec3 I1 = imageLoad(u_input, ivec2(fract(uv1) * vec2(dims))).rgb;
    vec3 I2 = imageLoad(u_input, ivec2(fract(uv2) * vec2(dims))).rgb;
    vec3 I3 = imageLoad(u_input, ivec2(fract(uv3) * vec2(dims))).rgb;
	
    // Blend the three samples using the barycentric weights.
    vec3 color = w1 * I1 + w2 * I2 + w3 * I3;
    return color;
}

void main(){
    // Compute the pixel coordinate this thread is responsible for.
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dims = imageSize(u_input);

    // Make sure we don't process out-of-bound pixels.
    if (coords.x >= dims.x || coords.y >= dims.y) {
        return;
    }

    // Compute normalized UV coordinates in [0, 1].
    vec2 uv = vec2(coords) / vec2(dims);

    // Get the blended displacement value.
    vec3 result = get_displacement_tiling(uv);

    // Store the result in the output image.
    imageStore(u_output, coords, vec4(result, 1.0));
}
