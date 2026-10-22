#version 460

in vec2 vaUV0;
in vec4 vaColor;
in vec3 vaPosition, vaNormal;

uniform vec3 chunkOffset;
uniform mat3 normalMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec3 fColor, normalMap;
out vec2 texCoord;

void main() {
    normalMap = normalMatrix * vaNormal; texCoord = vaUV0; fColor = vaColor.rgb;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vaPosition + chunkOffset, 1.0);
}