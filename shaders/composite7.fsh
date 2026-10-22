#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/coreFunctions/bloomKawase.glsl"

/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 outBloom;

uniform sampler2D colortex6;
in vec2 texCoord;

void main() {
    outBloom = vec4(kawaseDown(colortex6, texCoord, false), 1.0); // (010) Down 1/32
}
