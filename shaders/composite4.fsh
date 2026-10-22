#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/coreFunctions/bloomKawase.glsl"

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outBloom;

uniform sampler2D colortex5;
in vec2 texCoord;

void main() {
    outBloom = vec4(kawaseDown(colortex5, texCoord, true), 1.0); // (010) Down 1/4
}
