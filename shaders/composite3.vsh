#version 460 compatibility

#include "/libs/exposure.h"

uniform sampler2D colortex11;

out vec2 texCoord;
flat out float exposure;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.st;

    // (001) Adapted Exposure (per-frame, read from the exposure texel)
    exposure = exposureFromLuma(texelFetch(colortex11, ivec2(0), 0).r);
}
