#version 460 compatibility

#include "/libs/mathUtils.glsl"
#include "/libs/coreFunctions/bloomKawase.glsl"

uniform sampler2D colortex11;
uniform int isEyeInWater;

out vec2 texCoord;
flat out float exposure, bloomK;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.st;

    // (001) Adapted Exposure & Bloom Mix (per-frame, read from the exposure texel)
    exposure = exposureFromLuma(texelFetch(colortex11, ivec2(0), 0).r);
    bloomK   = saturate(BLOOM_STRENGTH * clamp(pow(exposure / BLOOM_GLARE_REF, BLOOM_GLARE_POWER), 1.0 / BLOOM_GLARE_MAX, BLOOM_GLARE_MAX)
                      * ((isEyeInWater == 1) ? BLOOM_UNDERWATER : 1.0));
}
