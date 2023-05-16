#version 420

in vec4 in_Vertex;
in vec2 TexCoord;
in vec3 BaryCentricCoords;

out vec4 out_Color;

void main() {    
    out_Color = vec4(1.0);
}