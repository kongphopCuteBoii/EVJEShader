#version 460 compatibility

uniform vec3 cameraPosition;
uniform mat4 dhProjection;

vec3 transform(mat4 m, vec3 pos) {
    return mat3(m) * pos + m[3].xyz;
}

out vec4 fColor;

void main() {
    fColor = gl_Color;
    vec3 cameraOffset = fract(cameraPosition);
    vec3 localPos = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;
    localPos = transform(gl_ModelViewMatrix, localPos);
    gl_Position = dhProjection * vec4(localPos, 1.0);
}
