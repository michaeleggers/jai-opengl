#version 420

in vec4 in_Vertex;
in vec2 TexCoord;

out vec4 out_Color;

uniform sampler2D colorTex;

void main() {

    vec4 texColor = texture(colorTex, TexCoord);
    out_Color = vec4(texColor.rgb, 1.0);
}