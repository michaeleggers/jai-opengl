#version 420

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;

layout (std140, binding = 0) uniform ViewProjMatrices {
    mat4 view;
    mat4 proj;
};

void main() {
    gl_Position = proj * view * vec4(pos, 1.0);
}
