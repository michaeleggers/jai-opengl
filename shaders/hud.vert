#version 420

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 bc;
layout (location = 3) in vec3 normal;


layout (std140, binding = 3) uniform HUDTransform {
    vec2 offset;
    vec2 scaleXY;
};

out vec2 TexCoord;
out vec3 BaryCentricCoords;

void main() {
    gl_Position = vec4( vec3(scaleXY * pos.xy, 0.0) + vec3(offset, 0.0), 1.0);
    
    TexCoord = uv;
    BaryCentricCoords = bc;
}
