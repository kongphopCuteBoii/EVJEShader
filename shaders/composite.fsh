#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/typeClassifier.h"
#include "/libs/gbufferPacking.h"

uniform sampler2D colortex0, colortex1, colortex2, colortex9;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform sampler2D shadowtex1;
uniform mat4 gbufferProjectionInverse, gbufferProjection, gbufferModelView, gbufferModelViewInverse;
uniform mat4 dhProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float viewHeight;
uniform ivec2 eyeBrightnessSmooth;

in vec2 texCoord;
in vec3 sunDir,
        moonDir;
flat in vec3 sunC,
             sunlightC,
             ambientC,
             skyC,
             horizonC,
             fogC;
flat in vec3 keyDir,
             keyDiscC,
             keySpecC;
flat in vec4 nightP,
             vAtlas;

#ifndef PI
    #define PI 3.141592653589793
#endif
#define saturate(x) clamp(x, 0.0, 1.0)

#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/nightEditor.h"
#define SWELL_SCALE vec2(1.0)
#define SWELL_DRIFT vec2(0.0, 0.5)
#define SWELL_AMP 0.35
#define SWELL_DRAG 0.5

#define WATER_F0                  0.02
#define WATER_BASE_ROUGHNESS      0.035
#define WATER_SUN_ROUGHNESS       0.26
#define WATER_WAVE_DETAIL_FREQ    4.0
#define WATER_TRACE_FLATTEN       0.8
#define WATER_REFLECTION_TINT     vec3(0.8, 1.0, 1.2)
#define WATER_SKY_GAIN            0.4

#include "/libs/coreFunctions/swellOcean.glsl"
#include "/libs/coreFunctions/waterSSR.glsl"
#include "/libs/coreFunctions/pbrModule.glsl"
#include "/libs/coreFunctions/reflectionModule.glsl"
#include "/libs/coreFunctions/volumetricFog.glsl"
#include "/libs/mathUtils.glsl"

#ifndef WATER_GLINT_MIN_ALPHA
    #define WATER_GLINT_MIN_ALPHA   0.014
#endif
#ifndef WATER_GLINT_SSR_MASK
    #define WATER_GLINT_SSR_MASK    0.5
#endif
#ifndef WATER_GLINT_MAX
    #define WATER_GLINT_MAX         6.0
#endif

#define REFLECT_SSR_DISTANCE      64.0
#define UW_SSR_DISTANCE           40.0

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#ifndef WATER_ABSORPTION
#define WATER_ABSORPTION vec3(0.30, 0.1, 0.12)
#endif
#ifndef WATER_SCATTER_COLOR
#define WATER_SCATTER_COLOR vec3(0.025, 0.13, 0.075)
#endif
#ifndef WATER_DEEP_COLOR
#define WATER_DEEP_COLOR vec3(0.006, 0.035, 0.065) * 0.1
#endif
#ifndef WATER_SCATTER_STRENGTH
#define WATER_SCATTER_STRENGTH 0.0
#endif
#ifndef WATER_DEEP_START
#define WATER_DEEP_START 2.0
#endif
#ifndef WATER_DEEP_END
#define WATER_DEEP_END 15.0
#endif
#ifndef WATER_ABSORPTION_MAX_THICKNESS
#define WATER_ABSORPTION_MAX_THICKNESS 256.0
#endif
#ifndef WATER_NO_BOTTOM_THICKNESS
#define WATER_NO_BOTTOM_THICKNESS 20.0
#endif

vec3 reconstructWaterViewPosition(vec2 uv, float depth) {
    vec4 h = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0,
                                             depth * 2.0 - 1.0, 1.0);
    return h.xyz / max(abs(h.w), 1e-6) * sign(h.w);
}

vec3 reconstructDHViewPosition(vec2 uv, float depth) {
    vec4 h = dhProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return h.xyz / h.w;
}

float getWaterColumnThickness(vec2 uv, float surfaceDepth, vec3 surfaceViewPos) {
    float opaqueDepth = textureLod(depthtex1, uv, 0.0).r;

    if (opaqueDepth >= 0.999999) return WATER_NO_BOTTOM_THICKNESS;

    if (surfaceDepth >= 0.0 && opaqueDepth <= surfaceDepth + 1e-6) return 0.0;

    vec3 opaqueViewPos = reconstructWaterViewPosition(uv, opaqueDepth);
    return clamp(length(opaqueViewPos - surfaceViewPos) * 3.,
                 0.0, WATER_ABSORPTION_MAX_THICKNESS);
}

vec3 applyWaterColumnAbsorption(vec3 transmittedColor, float thickness) {
    vec3 T = exp(-WATER_ABSORPTION * thickness);

    float deepFade = smoothstep(WATER_DEEP_START, WATER_DEEP_END, thickness);
    vec3 scatterColor = mix(WATER_SCATTER_COLOR, WATER_DEEP_COLOR, deepFade);

    vec3 inScattering = scatterColor * (vec3(1.0) - T) * WATER_SCATTER_STRENGTH;

    return transmittedColor * T;
}

void main() {
    ivec2 pixelPos   = ivec2(gl_FragCoord.xy);
    vec3  sceneColor = texture(colortex0, texCoord).rgb;

    float marker = texture(colortex9, texCoord).a;
    float mainDepth = textureLod(depthtex0, texCoord, 0.0).r;
    bool hasMainDepth = mainDepth < 0.999999;

    bool isMainWater = abs(marker - 0.5) < 0.01 && hasMainDepth;
    bool isDHWater = abs(marker - 0.25) < 0.01 && !hasMainDepth;

    #ifdef DISTANT_HORIZONS
        const float waterSSRRange = WATER_SSR_MAX_DISTANCE_DH;
    #else
        const float waterSSRRange = WATER_SSR_MAX_DISTANCE;
    #endif

    if (!isMainWater && !isDHWater) {
        vec4 reflectData = texelFetch(colortex2, pixelPos, 0);
        if (marker < 0.01 && hasMainDepth && reflectData.a > 0.0 && isEyeInWater == 0) {
            vec4 gbuf1 = texelFetch(colortex1, pixelPos, 0);
            if (unpackSceneType(gbuf1.a) != TYPE_HAND) {
                vec3 viewPos   = reconstructWaterViewPosition(texCoord, mainDepth),
                     worldPos  = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition,
                     worldN    = decodeNormalOct(gbuf1.rg),
                     viewN     = normalize(mat3(gbufferModelView) * worldN),
                     V         = normalize(cameraPosition - worldPos),
                     reflDir   = reflect(-V, worldN);

                float ssrConfidence;
                vec3  reflection = environmentReflection(viewPos, viewN, viewN, reflDir, reflectData.a,
                                                         -1e9, REFLECT_SSR_DISTANCE, gbuf1.b * gbuf1.b * sqrt(gbuf1.b),
                                                         REFLECTION_SKY_GAIN, REFLECTION_SKY_GRADE, vec3(1.0), ssrConfidence);
                sceneColor += reflection * EnvBRDFApprox(reflectData.rgb, reflectData.a, max(dot(worldN, V), 1e-4));
            }
        }
        outColor = vec4(sceneColor, 1.0);
        return;
    }

    vec3 viewPos;
    float waterThickness;
    if (isDHWater) {
        float dhDepth = textureLod(dhDepthTex0, texCoord, 0.0).r;
        if (dhDepth >= 0.999999) {
            outColor = vec4(sceneColor, 1.0);
            return;
        }
        viewPos = reconstructDHViewPosition(texCoord, dhDepth);
        float dhBottom = textureLod(dhDepthTex1, texCoord, 0.0).r;
        waterThickness = (dhBottom >= 0.999999) ? WATER_NO_BOTTOM_THICKNESS
            : clamp(length(reconstructDHViewPosition(texCoord, dhBottom) - viewPos),
                    0.0, WATER_ABSORPTION_MAX_THICKNESS);
    } else {
        viewPos = reconstructWaterViewPosition(texCoord, mainDepth);
        waterThickness = getWaterColumnThickness(texCoord, mainDepth, viewPos);
    }
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    float viewDistance = length(viewPos);

    vec3 transmittedColor = (isEyeInWater == 1) ? sceneColor : applyWaterColumnAbsorption(sceneColor, waterThickness);

    const vec3 up = vec3(0.0, 1.0, 0.0);
    vec3  V          = normalize(cameraPosition - worldPos);
    float pixelAngle = 2.0 / (gbufferProjection[1][1] * viewHeight);

    vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    vec2 waveXZ    = swellCoord(playerPos.xz, cameraPosition);

    SwellSample wave = swellDetail(waveXZ, frameTimeCounter, V, viewDistance, pixelAngle);

    vec3  nDetail      = swellNormalWS(wave.grad);
    float roughness    = min(sqrt(WATER_BASE_ROUGHNESS * WATER_BASE_ROUGHNESS + wave.rough * wave.rough), 0.5),
          sunRoughness = min(sqrt(WATER_SUN_ROUGHNESS * WATER_SUN_ROUGHNESS + wave.rough * wave.rough), 0.6);
    vec3  nTrace       = normalize(mix(nDetail, up, WATER_TRACE_FLATTEN));

    vec3 nDetailView = normalize(mat3(gbufferModelView) * nDetail);
    vec3 nTraceView  = normalize(mat3(gbufferModelView) * nTrace);

    if (isEyeInWater == 1) {
        vec3  nDown   = -nDetail,
              nTraceD = normalize(mix(nDown, -up, WATER_TRACE_FLATTEN)),
              nDownV  = normalize(mat3(gbufferModelView) * nDown),
              nTraceV = normalize(mat3(gbufferModelView) * nTraceD),
              reflDir = reflect(-V, nDown);
        float cosI    = max(dot(nDown, V), 1e-3),
              tir     = 1.0 - smoothstep(0.60, 0.72, cosI),
              mirrorConf;
        vec3  mirror  = environmentReflection(viewPos, nTraceV, nDownV, reflDir, roughness, -1e9, UW_SSR_DISTANCE, 0.0, 0.0, vec3(1.0), vec3(1.0), mirrorConf),
              bodyCol = ambientC * UW_AMBIENT * UW_WATER_COLOR * UW_ALBEDO * exp(-UW_AMBIENT_EXT * uwEyeDepth());
        mirror = applyFog(mix(bodyCol, mirror, mirrorConf), gbufferModelViewInverse[3].xyz, playerPos, getIGN(gl_FragCoord.xy), 1.0, keyDir, keyDiscC, ambientC, false);
        float fresUp  = mix(F_Schlick(cosI, vec3(WATER_F0), roughness).x, 1.0, tir);
        outColor = vec4(mix(sceneColor, mirror, fresUp), 1.0);
        return;
    }

    vec3 reflectionDirWorld = reflect(-V, nDetail);
    reflectionDirWorld.y = abs(reflectionDirWorld.y);
    reflectionDirWorld = normalize(reflectionDirWorld);

    float ssrConfidence;
    vec3  reflection = environmentReflection(viewPos, nTraceView, nDetailView, reflectionDirWorld, roughness,
                                             worldPos.y, waterSSRRange, 1.0,
                                             WATER_SKY_GAIN, vec3(1.0), vec3(0.8, 1.0, 1.2), ssrConfidence);

    float fresnel = F_Schlick(max(dot(nDetail, V), 1e-3), vec3(WATER_F0), roughness).x;

    vec3 waterColor = mix(transmittedColor, reflection, fresnel);

    Material waterMat;
    waterMat.albedo   = vec3(0.0);
    waterMat.pRough   = sunRoughness;
    waterMat.alpha    = max(sunRoughness * sunRoughness, WATER_GLINT_MIN_ALPHA);
    waterMat.F0       = vec3(WATER_F0);
    waterMat.metallic = 0.0;
    waterMat.emissive = 0.0;
    vec3 glint = shadeSunSpecular(waterMat, nDetail, V, keyDir, sunlightC, keySpecC) * smoothstep(-0.02, 0.06, keyDir.y)
               * ((NIGHT_MOON_GLINT != 0) ? 1.0 : 1.0 - nightP.x);
    glint = glint / (1.0 + glint / WATER_GLINT_MAX);
    waterColor += glint * (1.0 - ssrConfidence * WATER_GLINT_SSR_MASK);

    float fogDither   = getIGN(gl_FragCoord.xy),
          skyExposure = mix(FOG_CAVE_FLOOR, 1.0, saturate(float(eyeBrightnessSmooth.y) / 240.0));
    waterColor = applyFog(waterColor, gbufferModelViewInverse[3].xyz, playerPos, fogDither, skyExposure, keyDir, keyDiscC * ((NIGHT_MOON_FOG_SHAFTS != 0) ? 1.0 : 1.0 - nightP.x), ambientC, false);

    outColor = vec4(waterColor, 1.0);
}
