#version 420


in vec2 TexCoord;
in vec3 BaryCentricCoords;
in vec3 Normal;
in vec3 Color;

out vec4 out_Color;


void main() {

    // out_Color = vec4(1.0, 0.95, 0.0, 0.7);
    out_Color = vec4(Color, 0.7);
    //out_Color = vec4(normalColor + wireframe.rgb, 1.0);
}