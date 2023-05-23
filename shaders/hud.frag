#version 420

in vec4 in_Vertex;
in vec2 TexCoord;
in vec3 BaryCentricCoords;

out vec4 out_Color;

uniform sampler2D colorTex;

void main() {

    vec4 texColor = texture(colorTex, TexCoord);

    out_Color = texColor;
    // out_Color = vec4(1.0, 0.0, 0.0, 1.0);
}