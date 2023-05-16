#version 420

// Copied from: https://web.archive.org/web/20200306081453/http://codeflow.org/entries/2012/aug/02/easy-wireframe-display-with-barycentric-coordinates/

in vec4 in_Vertex;
in vec2 TexCoord;
in vec3 BaryCentricCoords;

out vec4 out_Color;

float edgeFactor(){
    vec3 d = fwidth(BaryCentricCoords);
    vec3 a3 = smoothstep(vec3(0.0), d, BaryCentricCoords);
    return min(min(a3.x, a3.y), a3.z);
}

void main() {
    
    // vec3 edgeColor = smoothstep(0.1, 1.0, BaryCentricCoords);
    // vec4 edgeColor = vec4(0.4, 0.4, 0.4, 1.0);
    // if (any(lessThan(BaryCentricCoords, vec3(0.01)))) {
    //     edgeColor = vec4(1.0);
    // }
    
    out_Color = vec4(mix(vec3(1.0), vec3(0.5), edgeFactor()), 1.0);
}