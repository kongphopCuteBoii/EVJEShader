#version 460 compatibility

uniform vec3 sunPosition, shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform int  moonPhase;

out vec2 texCoord;
out vec3 sunDir, moonDir;
flat out vec3 sunC, sunlightC, ambientC,
              skyC, horizonC, fogC;
flat out vec3 keyDir, keyDiscC, keySpecC;
flat out vec4 nightP;
flat out vec4 vAtlas;

#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/nightEditor.h"

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.st;

    sunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    moonDir = -sunDir;
    float sunElev = degrees(asin(clamp(sunDir.y, -1.0, 1.0)));
    vAtlas = atlasParams(sunDir, sunElev);
    getSkyChildren(sunElev, sunC, sunlightC, ambientC, skyC, horizonC, fogC);

    vec3 keyC;
    getKeyLight(sunDir, normalize(mat3(gbufferModelViewInverse) * shadowLightPosition), sunlightC, sunC, moonPhase,
                keyDir, keyC, keyDiscC, keySpecC, nightP);
    sunlightC = keyC;
    applyNightChildren(nightP, ambientC, skyC, horizonC, fogC);
}
