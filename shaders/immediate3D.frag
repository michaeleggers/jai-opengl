#version 420


in vec2 TexCoord;
in vec3 BaryCentricCoords;
in vec3 Normal;

out vec4 out_Color;


void main() {

    out_Color = vec4(1.0, 0.1, 0.9, 0.5);
    //out_Color = vec4(normalColor + wireframe.rgb, 1.0);
}