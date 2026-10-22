#version 460 compatibility

#include "/libs/irisEssentials.h"

/* DRAWBUFFERS:5 */
layout(location = 0) out vec4 outFilteredGIAO;
#include "/libs/buffersShared/compositeDenoiser.glsl"

void main() {
    outFilteredGIAO = denoise(0.15, 0.0, 2.5, true);
}

