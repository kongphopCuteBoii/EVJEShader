#version 460

uniform sampler2D gtexture;
uniform mat4 gbufferModelViewInverse;

/* DRAWBUFFERS:012 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outPBR;

in vec3 fColor, normalMap;
in vec2 texCoord;

void main() {
    discard;
}
