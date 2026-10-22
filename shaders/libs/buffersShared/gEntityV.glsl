in vec2 vaUV0;
in ivec2 vaUV2;
in vec4 vaColor;
in vec3 vaPosition, vaNormal;

uniform int  blockEntityId;
uniform mat3 normalMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec3 fColor, normalMap;
flat out int isCloth;
out vec2 texCoord, lightCoord;

void main() {
    isCloth = (blockEntityId == 300) ? 1 : 0;
    normalMap = normalMatrix * vaNormal; texCoord = vaUV0; fColor = vaColor.rgb;
    lightCoord = vaUV2 * 3.9e-3 + 3.125e-2;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vaPosition, 1.0);
}
