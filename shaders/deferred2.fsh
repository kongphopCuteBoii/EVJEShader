#version 460 compatibility

/* DRAWBUFFERS:5 */
layout(location = 0) out vec4 outFilteredGIAO;
#include "/libs/buffersShared/compositeDenoiser.glsl"

void main() {
    outFilteredGIAO = denoise(0.45, 1.0, 1.5, false);
}

