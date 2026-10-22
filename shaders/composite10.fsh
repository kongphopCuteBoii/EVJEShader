#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/coreFunctions/bloomKawase.glsl"

/* RENDERTARGETS: 13 */
layout(location = 0) out vec4 outBloom;

uniform sampler2D colortex12, colortex3;
in vec2 texCoord;

void main() {
    vec3 lower = kawaseUp(colortex12, texCoord, false),
         same  = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0).rgb;
    outBloom = vec4(mix(same, lower, BLOOM_SPREAD), 1.0); // (010) Up 1/4
}
