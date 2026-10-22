#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/coreFunctions/bloomKawase.glsl"

/* RENDERTARGETS: 10 */
layout(location = 0) out vec4 outBloom;

uniform sampler2D colortex8, colortex6;
in vec2 texCoord;

void main() {
    vec3 lower = kawaseUp(colortex8, texCoord, false),
         same  = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rgb;
    outBloom = vec4(mix(same, lower, BLOOM_SPREAD), 1.0); // (010) Up 1/16
}
