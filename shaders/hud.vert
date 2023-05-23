#version 420

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 bc;
layout (location = 3) in vec3 normal;


layout (std140, binding = 2) uniform HUDTransform {
    vec2 offset;
    vec2 scaleXY;
};

layout (std140, binding = 3) uniform HUDWindowData {
    vec2 clientDimensions;
};

out vec2 TexCoord;
out vec3 BaryCentricCoords;

void main() {

    vec2 pos01 = (pos.xy + vec2(1.0)) / 2.0;

    vec2 screenSpacePos = pos.xy / clientDimensions;
    screenSpacePos *= scaleXY;
    // screenSpacePos.x -= 0.5;
    // screenSpacePos.x += (1.0 - offset.x)/clientDimensions.x/2.0;
    // screenSpacePos.y += offset.y/clientDimensions.y/2.0;
    screenSpacePos.x += (offset.x/clientDimensions.x + 1.0) / 2.0;
    // screenSpacePos.x = (screenSpacePos.x + 1.0) / 3.0;



    gl_Position = vec4(screenSpacePos, 0.0, 1.0);
    
    TexCoord = uv;
    BaryCentricCoords = bc;
}
