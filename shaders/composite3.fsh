#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/coreFunctions/bloomKawase.glsl"

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outBloom;

uniform sampler2D colortex0;
in vec2 texCoord;
flat in float exposure;

void main() {
    outBloom = vec4(kawaseDownPrefilter(colortex0, texCoord, exposure), 1.0); // (010) Down 1/2, prefiltered
}
