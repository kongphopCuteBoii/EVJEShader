#version 460 compatibility

#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/coreFunctions/cloudSettings.glsl"

/* RENDERTARGETS: 14 */
layout(location = 0) out vec4 outCloud;

uniform sampler2D depthtex1;
uniform mat4  gbufferProjectionInverse,
              gbufferModelViewInverse;
uniform vec3  cameraPosition;
uniform float frameTimeCounter,
              viewWidth,
              viewHeight;
uniform int   isEyeInWater;

in vec2 texCoord;
flat in vec3 sunDir,
             sunC,
             skyC,
             horizonC;
flat in vec4 vAtlas;
flat in vec3 keyDir,
             keyDiscC,
             cloudSunC,
             cloudAmbC,
             cloudHazeExt;

#define saturate(x) clamp(x, 0.0, 1.0)

// (100) Half-Resolution Volumetric Clouds
// Output: rgb = cloud radiance, a = transmittance (a < 0 marks a texel that was never marched)
void main() {
#ifndef MIRAI_CLOUDS
    outCloud = vec4(0.0, 0.0, 0.0, 1.0);
    return;
#else
    // (101) Footprint Sky Test: only march when one of the 2x2 full-res pixels this texel covers shows sky
    ivec2 fp       = ivec2(gl_FragCoord.xy) * 2;
    float depthMax = max(max(texelFetch(depthtex1, fp, 0).r, texelFetch(depthtex1, fp + ivec2(1, 0), 0).r),
                         max(texelFetch(depthtex1, fp + ivec2(0, 1), 0).r, texelFetch(depthtex1, fp + ivec2(1, 1), 0).r));
    if (depthMax < 1.0) { outCloud = vec4(0.0, 0.0, 0.0, -1.0); return; }
    if (isEyeInWater != 0) { outCloud = vec4(0.0, 0.0, 0.0, 1.0); return; }

    // (102) View Ray Through The Centre Of The 2x2 Block
    vec4 clipFar = gbufferProjectionInverse * vec4((vec2(fp) + 1.0) / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
    vec3 rayDir  = normalize(mat3(gbufferModelViewInverse) * (clipFar.xyz / clipFar.w));

    // (103) Aerial Perspective Colour: the real sky in this direction (atlas + sun halo + sunset glow), so clouds sit INSIDE the atmosphere
    vec3 hazeCol = skyBody(rayDir, vAtlas, sunDir, sunC, horizonC) * CLOUD_HAZE_GAIN;

    // (104) March
    vec3  cloudRad;
    float cloudTrans;
    miraiCloudLayer(vec3(cameraPosition.x, cameraPosition.y - CLOUD_ALTITUDE_BIAS, cameraPosition.z),
                    rayDir, keyDir, cloudSunC, cloudAmbC,
                    frameTimeCounter * CLOUD_WIND_SPEED, CLOUD_MAX_DIST, cloudHazeExt, hazeCol,
                    cloudRad, cloudTrans);
    outCloud = vec4(cloudRad, cloudTrans);
#endif
}
