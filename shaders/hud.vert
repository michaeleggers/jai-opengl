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

    

    vec2 screenSpacePos = pos.xy / clientDimensions;
    screenSpacePos *= (2.0*scaleXY);   // Scale scale by 2 because we are now in ndc from -1 to +1, not 0 to 1.

    screenSpacePos.x += 2.0*(offset.x / clientDimensions.x) - 1.0;
    screenSpacePos.y += -2.0*(offset.y / clientDimensions.y) + 1.0;
    screenSpacePos.y -= 2.0*(scaleXY.y / clientDimensions.y);


    gl_Position = vec4(screenSpacePos, 0.0, 1.0);
    
    TexCoord = uv;
    BaryCentricCoords = bc;
}
