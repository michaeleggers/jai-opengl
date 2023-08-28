#version 420

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 bc;
layout (location = 3) in vec3 normal;
layout (location = 4) in vec3 color;
layout (location = 5) in uvec4 blendindices;
layout (location = 6) in vec4 blendweights;


layout (std140, binding = 0) uniform ViewProjMatrices {
    mat4 view;
    mat4 proj;
};

layout (std140, binding = 4) uniform TransformMatrix {
    mat4 transform;
};

layout (std140, binding = 5) uniform PoseMatrices {
    mat4 palette[96];
};

out vec2 TexCoord;
out vec3 BaryCentricCoords;
out vec3 Normal;

void main() {
    vec4 v = vec4(pos, 1.0);
    vec4 skinnedPos = (palette[blendindices.x] * v) * blendweights.x;
    skinnedPos += (palette[blendindices.y] * v) * blendweights.y;
    skinnedPos += (palette[blendindices.z] * v) * blendweights.z;
    skinnedPos += (palette[blendindices.w] * v) * blendweights.w;
    
    gl_Position = proj * view * transform * skinnedPos;
    
    TexCoord = uv;
    BaryCentricCoords = bc;
    Normal = normal;
}
