#version 420

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 bc;


layout (std140, binding = 0) uniform ViewProjMatrices {
    mat4 view;
    mat4 proj;
};

out vec2 TexCoord;
out vec3 BaryCentricCoords;

void main() {
    gl_Position = proj * view * vec4(pos, 1.0);
    TexCoord = uv;
    BaryCentricCoords = bc;
}
