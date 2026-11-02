#version 460 compatibility

uniform vec3 sunPosition, shadowLightPosition;
uniform mat4 gbufferModelViewInverse, gbufferProjection, shadowProjectionInverse;
uniform int  moonPhase;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewHeight;

out vec2 texCoord;
flat out vec3 sunDir, moonDir;
flat out vec3 sunC, ambientC,
              skyC, horizonC, fogC;
flat out vec3 keyDir, keyDiscC, keySpecC;
flat out vec4 nightP;
flat out vec4 vAtlas;

// Per-frame values hoisted out of the fragment stage (uniform-only math)
flat out vec3  fogKeyC, cloudSunC, cloudAmbC, cloudHazeExt, uwBodyC;
flat out vec2  uwSlantXZ;
flat out float skyPx, skyExposure, glintGate,
               keyFade, blocksPerDepth, rsmSunFade, horizonScale,
               uwEyeD;

#ifndef saturate
    #define saturate(x) clamp(x, 0.0, 1.0)
#endif

#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/nightEditor.h"
#include "/libs/fogConstants.h"
#define CLOUD_SETTINGS_ONLY
#include "/libs/coreFunctions/cloudSettings.glsl"

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.st;

    sunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    moonDir = -sunDir;
    float sunElev = degrees(asin(clamp(sunDir.y, -1.0, 1.0)));
    vAtlas = atlasParams(sunDir, sunElev);
    vec3 tableSunlight;
    getSkyChildren(sunElev, sunC, tableSunlight, ambientC, skyC, horizonC, fogC);

    vec3 keyC;
    getKeyLight(sunDir, normalize(mat3(gbufferModelViewInverse) * shadowLightPosition), sunC, sunC, moonPhase,
                keyDir, keyC, keyDiscC, keySpecC, nightP);
    applyNightChildren(nightP, ambientC, skyC, horizonC, fogC);

    // (100) Night-Gated Fog & Cloud Light Inputs
    fogKeyC   = keyDiscC * ((NIGHT_MOON_FOG_SHAFTS != 0) ? 1.0 : 1.0 - nightP.x);
    cloudSunC = keyDiscC * (CLOUD_SUN_INPUT * 5. * ((NIGHT_MOON_CLOUDS != 0) ? 1.0 : 1.0 - nightP.x));
    cloudAmbC = ambientC * CLOUD_AMBIENT_INPUT + horizonC * (CLOUD_AMBIENT_HORIZON * (1.0 - smoothstep(0.05, 0.55, sunDir.y)));

    // (101) Cloud Aerial Perspective: air extinction follows the sunlight tint, so blue dies first as the sun lowers
    float sunTintMax = max(max(keyDiscC.r, keyDiscC.g), keyDiscC.b);
    vec3  sunTint    = (sunTintMax > 1e-6) ? keyDiscC / sunTintMax : vec3(1.0);
    cloudHazeExt     = -log2(max(sunTint, 0.02)) / CLOUD_HAZE_DIST;

    // (110) Pixel Angle & Sky Exposure
    float skyLight = saturate(float(eyeBrightnessSmooth.y) / 240.0);
    skyPx       = 2.0 / (gbufferProjection[1][1] * viewHeight);
    skyExposure = mix(FOG_CAVE_FLOOR, 1.0, skyLight);

    // (120) Water Glint Gate
    glintGate = smoothstep(-0.02, 0.06, keyDir.y) * ((NIGHT_MOON_GLINT != 0) ? 1.0 : 1.0 - nightP.x);

    // (130) Terrain Lighting Constants
    keyFade        = smoothstep(0.0, 0.2, keyDir.y);
    blocksPerDepth = 2.0 * abs(shadowProjectionInverse[2][2]);
    rsmSunFade     = smoothstep(0.2, 0.4, sunDir.y);
    horizonScale   = clamp(dot(ambientC, vec3(0.3333)) / max(dot(mix(horizonC, skyC, 0.5), vec3(0.3333)), 1e-4), 0.5, 1.5);

    // (140) Underwater Medium (eye depth mirrors uwEyeDepth() in volumetricFog.glsl)
    uwEyeD    = (1.0 - skyLight) * UW_LIGHT_DEPTH;
    uwSlantXZ = keyDir.xz / max(keyDir.y, 0.3);
    uwBodyC   = ambientC * UW_AMBIENT * UW_WATER_COLOR * UW_ALBEDO * exp(-UW_AMBIENT_EXT * uwEyeD);
}
