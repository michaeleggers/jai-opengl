#version 420

in vec4 in_Vertex;
in vec2 TexCoord;
in vec3 BaryCentricCoords;
in vec3 Normal;

out vec4 out_Color;

layout (std140, binding = 1) uniform PerFrameSettings {
    uint drawWireframe;
};

uniform sampler2D colorTex;

float edgeFactor(){
    vec3 d = fwidth(BaryCentricCoords);
    vec3 a3 = smoothstep(vec3(0.0), d, BaryCentricCoords);
    return min(min(a3.x, a3.y), a3.z);
}

void main() {

    vec4 texColor = texture(colorTex, TexCoord);

    vec4 wireframe = vec4(0.0);
    if (drawWireframe) {
        wireframe = vec4(mix(vec3(1.0), vec3(0.0), edgeFactor()), 1.0);        
    }
    
    vec3 normalColor = 0.5*Normal + 0.5;
    out_Color = vec4(texColor.rgb + wireframe.rgb, 1.0);
    out_Color = vec4(normalColor + wireframe.rgb, 1.0);
}