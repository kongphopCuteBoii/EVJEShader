#version 460 compatibility

#include "/libs/nightEditor.h"

uniform vec3  sunPosition;
uniform float viewWidth, viewHeight;
uniform mat4  gbufferModelViewInverse;

out vec2 texCoord;
flat out int   nightNoGI;
flat out float aspect;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.st;

    // (001) Per-Frame GI Gate & Aspect Ratio
    nightNoGI = ((NIGHT_RSM_GI == 0) && (normalize(mat3(gbufferModelViewInverse) * sunPosition).y < -0.03)) ? 1 : 0;
    aspect    = viewWidth / viewHeight;
}
