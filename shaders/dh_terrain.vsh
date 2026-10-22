#version 460 compatibility

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse, dhProjection;

out vec4 fColor;
out vec3 normalMap;
out vec2 lightCoord;
out vec3 worldPos;
flat out int isLeaves;

vec3 transform(mat4 m, vec3 pos) {
    return mat3(m) * pos + m[3].xyz;
}

void main() {
    fColor = gl_Color;
    normalMap = gl_NormalMatrix * gl_Normal;
    lightCoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * (32.0 / 30.0), 0., 1.);
    isLeaves   = (dhMaterialId == DH_BLOCK_LEAVES) ? 1 : 0;
    vec3 cameraOffset = fract(cameraPosition);
    vec3 localPos = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;
    localPos = transform(gl_ModelViewMatrix, localPos);
    worldPos = transform(gbufferModelViewInverse, localPos);
    gl_Position = dhProjection * vec4(localPos, 1.0);
}