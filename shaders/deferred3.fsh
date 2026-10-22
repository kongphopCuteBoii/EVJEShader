#version 460 compatibility

#include "/libs/irisEssentials.h"

#include "/libs/typeClassifier.h"
#include "/libs/gbufferPacking.h"
#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/nightEditor.h"
#include "/libs/shadowEssentials.h"

#include "/libs/coreFunctions/cloudSettings.glsl"
/* DRAWBUFFERS:02 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outReflect;


uniform mat4 gbufferProjectionInverse,
             gbufferModelViewInverse,
             shadowModelView,
             shadowProjection,
             shadowProjectionInverse;
#ifdef DISTANT_HORIZONS
    uniform mat4      dhProjectionInverse;
    uniform sampler2D dhDepthTex0;
#endif
uniform sampler2D colortex0,
                  colortex1,
                  colortex2,
                  colortex5,
                  colortex7,
                  depthtex1,
                  shadowtex0,
                  shadowtex1,
                  shadowcolor0;
uniform vec3  shadowLightPosition,
              cameraPosition,
              sunPosition;
uniform float frameTimeCounter,
              viewWidth,
              viewHeight;
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



// (010) Math & Coordinate Utilities
// (011) Constants & Macros
#ifndef PI
    #define PI 3.141592653589793
#endif

#define saturate(x) clamp(x, 0.0, 1.0)

float sq(float x)    { return x * x; }
float cube(float x)  { return x * x * x; }
float pow15(float x) { return x * sqrt(x); }

const mat2 GOLDEN_ROT  = mat2(cos(2.3999632), sin(2.3999632), -sin(2.3999632), cos(2.3999632)),
           GOLDEN_ROT4 = mat2(cos(9.5998528), sin(9.5998528), -sin(9.5998528), cos(9.5998528));

#ifndef HAND_DEPTH
    #define HAND_DEPTH 0.125
#endif

// (012) Depth Linearization & Normals
float linZ(float depthVal) {
    float ndcDepth = depthVal * 2.0 - 1.0;
    return -gbufferProjectionInverse[3][2] / (gbufferProjectionInverse[2][3] * ndcDepth + gbufferProjectionInverse[3][3]);
}

vec3 decodeN(vec3 rawNormal) { return rawNormal * 2.0 - 1.0; }

// (013) Projection Helpers
vec3 projectAndDivide(mat4 projMatrix, vec3 pos) {
    return vec3(pos.xy * vec2(projMatrix[0][0], projMatrix[1][1]), projMatrix[2][2] * pos.z + projMatrix[3][2]) / (projMatrix[2][3] * pos.z + projMatrix[3][3]);
}

// (014) Dithering & Noise
float getIGN(vec2 fragCoord) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(fragCoord, magic.xy)));
}



// (020) PCF Shadow Utilities
// (021) Shadow Tap
float shadowTap(float depthSample, float receiverDepth, float softK, float floorK) {
    if (softK <= 0.0) return step(receiverDepth, depthSample);
    float t = exp(-max(receiverDepth - depthSample, 0.0) * softK);
    return mix(floorK, 1.0, t);
}



// (030) Surface Shading & Material Models
// (031) Unified PBR Module
#include "/libs/coreFunctions/pbrModule.glsl"



// (040) Shadow Processing & Filtering
// (041) Soft Shadow Depth Test & Foliage Beer-Lambert Extinction
float shadowTap(float depthSample, float receiverDepth, float softK) {
    return (softK > 0.0) ? exp(-max(receiverDepth - depthSample, 0.0) * softK) : step(receiverDepth, depthSample);
}

// (042) Non-Linear Shadow Map Distortion
vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy) + 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z  *= 0.5;
    return shadowClipPos;
}

// (043) Soft Knee Helper
vec3 softKnee(vec3 x, float knee) {
    vec3 excess = max(x - knee, 0.0);
    return x - excess + excess / (1.0 + excess);
}



// (050) Burley Normalized Diffusion SSS
const float SSS_PI = 3.14159265;

// (051) Shape Factor Parameterisation
vec3 burleyS(vec3 albedo) {
    vec3 delta = albedo - 0.8;
    return 1.9 - albedo + 3.5 * delta * delta;
}

// (052) Per-Channel Scattering Distance
vec3 burleyD(vec3 albedo, vec3 mfp) {
    return mfp / burleyS(albedo);
}

// (053) Radial Profile Evaluation
vec3 burleyShape(float dist, vec3 diffScale) {
    dist = max(dist, 1e-5);
    return (exp(-dist / diffScale) + exp(-dist / (3.0 * diffScale))) / (8.0 * SSS_PI * diffScale * dist);
}

// (054) Exact Inverse-CDF Profile Radius Sampling
float sampleBurleyRadius(float randomSample, float diffScale, out float pdfR) {
    float sampleVal = max(1.0 - randomSample, 1e-6),
          rootParam = 2.0 * sampleVal + sqrt(4.0 * sampleVal * sampleVal + 1.0),
          cubeDiff  = pow(rootParam, 1.0 / 3.0) - pow(rootParam, -1.0 / 3.0),
          radiusFac = -3.0 * log(max(cubeDiff, 1e-6));

    pdfR = (exp(-radiusFac) + cubeDiff) / (4.0 * diffScale);
    return radiusFac * diffScale;
}

// (055) Thin-Slab Slab Transmission
vec3 burleyTransmittance(vec3 albedo, vec3 mfp, float slabThickness) {
    vec3 expTerm = exp(-slabThickness / (3.0 * burleyD(albedo, mfp)));
    return 0.25 * albedo * (expTerm * expTerm * expTerm + 3.0 * expTerm);
}



// (060) Ambient Occlusion & Global Illumination
// (061) Multi-Bounce Approximated GTAO
vec3 GTAOMultiBounce(float visibility, vec3 albedo) {
    vec3 quadA = 2.0404 * albedo - 0.3324,
         quadB = -4.7951 * albedo + 0.6417,
         quadC = 2.7552 * albedo + 0.6903;
    float vis  = visibility;

    return max(vec3(vis), ((vis * quadA + quadB) * vis + quadC) * vis);
}

// (062) Joint Bilateral GI / AO Upsampling
vec4 upsampleGIAO(float depth0, vec3 normal0) {
    vec2  pixelCoord = gl_FragCoord.xy;
    if (depth0 >= 1.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float linearZ0   = linZ(depth0),
          invDepthTol = 1.0 / (0.03 * linearZ0);

    vec2  halfCoord    = (pixelCoord - 0.5) * 0.5,
          subFrac      = halfCoord - vec2(ivec2(floor(halfCoord)));
    ivec2 baseCoord    = ivec2(floor(halfCoord)),
          maxHalfCoord = textureSize(colortex7, 0) - 1;

    vec4  accumColor = vec4(0.0);
    float weightSum  = 0.0;

    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            ivec2 sampleCoord = clamp(baseCoord + ivec2(i, j), ivec2(0), maxHalfCoord);
            vec4  guideTexel  = texelFetch(colortex7, sampleCoord, 0);
            if (guideTexel.a <= 0.0) continue;

            float weightBilinear = (i == 0 ? 1.0 - subFrac.x : subFrac.x) * (j == 0 ? 1.0 - subFrac.y : subFrac.y),
                  weightDepth    = exp(-abs(guideTexel.a - linearZ0) * invDepthTol),
                  normalDot      = max(dot(normal0, decodeN(guideTexel.rgb)), 0.0),
                  normal4        = sq(sq(normalDot)),
                  weightNormal   = sq(sq(normal4)),
                  totalWeight    = weightBilinear * weightDepth * weightNormal;

            accumColor += texelFetch(colortex5, sampleCoord, 0) * totalWeight;
            weightSum  += totalWeight;
        }
    }
    if (weightSum > 1e-4) return accumColor / weightSum;

    float bestScore = 1e9;
    vec4  bestTexel = vec4(0.0, 0.0, 0.0, 1.0);

    for (int j = -1; j <= 2; j++) {
        for (int i = -1; i <= 2; i++) {
            ivec2 sampleCoord = clamp(baseCoord + ivec2(i, j), ivec2(0), maxHalfCoord);
            vec4  guideTexel  = texelFetch(colortex7, sampleCoord, 0);
            if (guideTexel.a <= 0.0) continue;

            float normalDot = dot(normal0, decodeN(guideTexel.rgb));
            if (normalDot < 0.5) continue;

            float score = abs(guideTexel.a - linearZ0) / linearZ0 + (1.0 - normalDot);
            if (score < bestScore) {
                bestScore = score;
                bestTexel = texelFetch(colortex5, sampleCoord, 0);
            }
        }
    }
    return bestTexel;
}



// (070) Volumetric Fog
#include "/libs/coreFunctions/volumetricFog.glsl"



void main() {
    // (100) G-Buffer Decoding & Scene Detection
    // (101) Raw Buffer Samples
    ivec2 pixelPos = ivec2(gl_FragCoord.xy);
    float ign      = getIGN(gl_FragCoord.xy);
    vec4  albedo   = texelFetch(colortex0, pixelPos, 0),
          gbuf1    = texelFetch(colortex1, pixelPos, 0);
    float depth    = texelFetch(depthtex1, pixelPos, 0).r;

    vec3 worldNormal = decodeNormalOct(gbuf1.rg);

    // (102) Scene Classification
    int sceneType   = unpackSceneType(gbuf1.a),
        foliageCode = unpackFoliageCode(gbuf1.a),
        isFoliage   = foliageCode > 0 ? 1 : 0,
        isLeaves    = foliageCode == 2 ? 1 : 0,
        isCloth     = foliageCode == 3 ? 1 : 0;

    vec4  upscaledGIAO = (sceneType == TYPE_TERRAIN || sceneType == TYPE_TERRAIN_DH) ? upsampleGIAO(depth, worldNormal) : vec4(0.0, 0.0, 0.0, 1.0);
    vec3  rsmRadiance  = upscaledGIAO.rgb;
    float visibility   = upscaledGIAO.a;

    // (103) Screen-Space & Depth Reconstruction
    float handDepthFix = (sceneType == TYPE_HAND) ? 1.0 / HAND_DEPTH : 1.0;
    #ifdef DISTANT_HORIZONS
        float dhDepth     = texelFetch(dhDepthTex0, pixelPos, 0).r;
        bool  isDhTerrain = (sceneType == TYPE_TERRAIN_DH) || (depth >= 1.0 && dhDepth < 1.0),
              isSky       = (depth >= 1.) && (!isDhTerrain);
        vec3  screenPos   = isDhTerrain ? vec3(texCoord, dhDepth) : vec3(texCoord, depth),
              ndcPos      = vec3(screenPos.xy * 2.0 - 1.0, (screenPos.z * 2.0 - 1.0) * handDepthFix),
              viewPos     = isDhTerrain ? projectAndDivide(dhProjectionInverse, ndcPos) : projectAndDivide(gbufferProjectionInverse, ndcPos);
    #else
        bool  isDhTerrain = false,
              isSky       = (depth >= 1.0);
        vec3  screenPos   = vec3(texCoord, depth),
              ndcPos      = vec3(screenPos.xy * 2.0 - 1.0, (screenPos.z * 2.0 - 1.0) * handDepthFix),
              viewPos     = projectAndDivide(gbufferProjectionInverse, ndcPos);
    #endif

    // (104) Material Attribute Reconstruction
    vec4 pbrData = texelFetch(colortex2, pixelPos, 0);
    Material mat = decodeMaterial(pbrData, albedo.rgb);

    bool isShaded     = (sceneType == TYPE_TERRAIN || sceneType == TYPE_TERRAIN_DH || sceneType == TYPE_ENTITY || sceneType == TYPE_BLOCK || sceneType == TYPE_HAND),
         isGlossy     = isShaded && !isSky && sceneType != TYPE_HAND && isReflective(mat);



    // (200) Camera & View Space Vectors
    // (201) Player & World Position Derivation
    vec3 footPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz,
         eyePlayerPos  = footPlayerPos + gbufferModelViewInverse[3].xyz,
         eyeCameraPos  = cameraPosition + gbufferModelViewInverse[3].xyz,
         fragWorldPos  = eyeCameraPos + eyePlayerPos;

    // (202) Directional Ray & Light Vectors
    vec3 viewDir    = normalize(cameraPosition - fragWorldPos),
         rayDir     = -viewDir,
         lightPos   = keyDir,
         finalColor = albedo.rgb;

    float skyPx = 2.0 * gbufferProjectionInverse[1][1] / viewHeight,
          skyW  = 1.8 * skyPx;



    vec3 uwLightTint = vec3(1.0);

    // (300) Composite & Lighting Pipeline
    // (301) Sky Pass Rendering
    if (isSky) {
        /*
        finalColor = renderAtmosphericSky(
            cameraPosition, rayDir, lightPos, 
            gl_FragCoord.xy, frameTimeCounter, 999999.0, dither
        );
        */
        vec3 skyCol = skyHDR(rayDir, vAtlas, sunDir, sunC, skyC, horizonC, skyW, skyPx) * SKY_GRADE;
        skyCol += nightSky(rayDir, sunDir, nightP, skyPx, frameTimeCounter, 1.0);
        #ifdef MIRAI_CLOUDS
            float cloudTrans;
            vec3  cloudRad;
            if (isEyeInWater == 0) skyCol = miraiCloudComposite(
                vec3(cameraPosition.x, cameraPosition.y - CLOUD_ALTITUDE_BIAS, cameraPosition.z),
                rayDir, keyDir, keyDiscC * (CLOUD_SUN_INPUT * 5. * ((NIGHT_MOON_CLOUDS != 0) ? 1.0 : 1.0 - nightP.x)), ambientC * CLOUD_AMBIENT_INPUT,
                skyCol, frameTimeCounter * CLOUD_WIND_SPEED, cloudTrans, cloudRad);
        #endif
        finalColor = skyCol * 0.3;
    } 
    else if (isShaded) {
        // (302) Terrain Shadow & Ambient Constants
        const float SHADOW_BLUR_SCALE       = 0.015,
                    SHADOW_MAX_BLUR         = 0.007,
                    SHADOW_CONTACT_EXPONENT = 1.15,
                    AMBIENT_INTENSITY       = 0.03,
                    CAVE_MIN_LIGHT          = 0.020,
                    CAVE_FALLOFF_CURVE      = 1.15;

        const vec3 SUN_HAZE_COLOR       = vec3(1.00, 0.98, 0.92),
                   GROUND_AMBIENT_COLOR = vec3(0.20, 0.20, 0.20);

        // (303) Shadow Projection & Distortion Bias
        float NdotL       = saturate(dot(worldNormal, lightPos)),
              skyLightMap = gbuf1.b,
              sunLeakMask = smoothstep(0.0, 0.10, skyLightMap);

        vec3 shadowSamplePos   = (sceneType == TYPE_HAND) ? gbufferModelViewInverse[3].xyz : footPlayerPos;

        vec3 shadowViewPosRaw  = (shadowModelView * vec4(shadowSamplePos, 1.0)).xyz;
        vec4 shadowClipRaw     = shadowProjection * vec4(shadowViewPosRaw, 1.0);
        float distortionFactor = length(shadowClipRaw.xy) + 0.1,
              slope            = sqrt(saturate(1.0 - NdotL * NdotL)) / max(NdotL, 0.05),
              normalBias       = (0.008 + 0.025 * clamp(distortionFactor, 0.0, 1.0)) * clamp(slope, 0.5, 3.0);

        vec3 biasedPos       = shadowSamplePos + worldNormal * normalBias + lightPos * (normalBias * 0.5),
             shadowViewPos   = (shadowModelView * vec4(biasedPos, 1.0)).xyz;
        vec4 shadowClipPos   = shadowProjection * vec4(shadowViewPos, 1.0);

        float distScale      = clamp(0.12 / distortionFactor, 0.08, 1.0);
        shadowClipPos.xyz    = distortShadowClipPos(shadowClipPos.xyz);

        vec3  shadowNdcPos    = shadowClipPos.xyz / shadowClipPos.w,
              shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
        float receiverDepth   = shadowScreenPos.z;
        vec2  shadowUv        = shadowScreenPos.xy;

        float noise   = ign,
              phi     = noise * 6.2831853;
        vec2  phiDir  = vec2(cos(phi), sin(phi));

        // (304) Variable Penumbra Shadow & Foliage Pseudo-SSS
        const float FOLIAGE_SHADOW_RADIUS   = 0.0075,
                    FOLIAGE_SHADOW_BIAS     = 0.0012,
                    FOLIAGE_DENSITY         = 2.5,
                    FOLIAGE_DIFFUSION       = 0.0035,
                    FOLIAGE_MAX_DEPTH       = 3.0,
                    FOLIAGE_SHADOW_FLOOR    = 0.12,
                    FOLIAGE_AMBIENT_FILL    = 0.35,

                    PLANT_SHADOW_BIAS       = 0.0009,
                    PLANT_RECEIVE_GAP       = 0.15,
                    PLANT_DENSITY           = 3.0,
                    PLANT_SHADOW_FLOOR      = 0.40,
                    PLANT_SOLID_FLOOR       = 0.04,
                    PLANT_SOLID_START       = 0.50,
                    PLANT_SOLID_END         = 1.20;

        float shadow       = 1.0,
              foliageDepth = 0.0;
        vec3 glassTint = vec3(1.0);
        if (sunLeakMask > 0.0 && shadowUv.x > 0.0 && shadowUv.x < 1.0 && shadowUv.y > 0.0 && shadowUv.y < 1.0 && receiverDepth > 0.0 && receiverDepth < 1.0) {
            float blocksPerDepth = 2.0 * abs(shadowProjectionInverse[2][2]),
                  softK          = (isLeaves != 0) ? FOLIAGE_DENSITY * blocksPerDepth
                                  : (isFoliage != 0) ? PLANT_DENSITY * blocksPerDepth
                                  : 0.0,
                  blockerBias    = 0.0004 * distortionFactor,
                  centerDepth    = textureLod(shadowtex1, shadowUv, 0.0).r;
            bool  centerInShadow = (centerDepth < receiverDepth - blockerBias);

            float pcfBias        = (isLeaves != 0) ? (FOLIAGE_SHADOW_BIAS * distortionFactor)
                                  : (isFoliage != 0) ? (PLANT_SHADOW_BIAS * distortionFactor + PLANT_RECEIVE_GAP / blocksPerDepth)
                                  : (0.0003 * distortionFactor),
                  biasedReceiver = receiverDepth - pcfBias,
                  filterRadius   = 0.0;
            bool  skipPcf        = false;

            if (isLeaves != 0) {
                float depthBlocks = clamp((biasedReceiver - centerDepth) * blocksPerDepth, 0.0, FOLIAGE_MAX_DEPTH);
                foliageDepth = 1.0 - exp(-0.8 * depthBlocks);
                filterRadius = min((FOLIAGE_SHADOW_RADIUS + depthBlocks * FOLIAGE_DIFFUSION) * distScale, SHADOW_MAX_BLUR * distScale);
            } else if (isFoliage != 0) {
                float blockerDist = max(biasedReceiver - centerDepth, 0.0) * blocksPerDepth,
                      plantFloor  = mix(PLANT_SHADOW_FLOOR, PLANT_SOLID_FLOOR, smoothstep(PLANT_SOLID_START, PLANT_SOLID_END, blockerDist));
                shadow  = shadowTap(centerDepth, biasedReceiver, softK, plantFloor);
                skipPcf = true;
            } else {
                float searchRadius = 0.012 * distScale,
                      blockerSum   = centerInShadow ? centerDepth : 0.0,
                      blockerCount = centerInShadow ? 1.0 : 0.0;

                vec2 searchDir = phiDir;
                for (int i = 0; i < 6; i++) {
                    float r      = sqrt(float(i) + 0.5) * 0.4082;
                    vec2  offset = searchDir * (r * searchRadius);
                    searchDir    = GOLDEN_ROT * searchDir;

                    float d = textureLod(shadowtex1, shadowUv + offset, 0.0).r;
                    if (d < receiverDepth - blockerBias) {
                        blockerSum += d;
                        blockerCount += 1.0;
                    }
                }

                if (blockerCount == 0.0) {
                    shadow  = 1.0;
                    skipPcf = true;
                } else {
                    float avgBlockerDepth = blockerSum / blockerCount;

                    vec4 projReceiver = shadowProjectionInverse * vec4(0.0, 0.0, receiverDepth * 2.0 - 1.0, 1.0),
                         projBlocker  = shadowProjectionInverse * vec4(0.0, 0.0, avgBlockerDepth * 2.0 - 1.0, 1.0);
                    float zReceiver = projReceiver.z / projReceiver.w,
                          zBlocker  = projBlocker.z / projBlocker.w;

                    float separation       = abs(zReceiver - zBlocker),
                          scaledSeparation = pow(separation, SHADOW_CONTACT_EXPONENT),
                          penumbra         = (scaledSeparation * SHADOW_BLUR_SCALE) / (abs(zBlocker) + 0.001);
                    filterRadius = min(penumbra * distScale, SHADOW_MAX_BLUR * distScale);
                }
            }

            if (!skipPcf) {
                float floorK = (isLeaves != 0) ? FOLIAGE_SHADOW_FLOOR : 0.0,
                      centerVis = (isLeaves != 0) ? shadowTap(centerDepth, biasedReceiver, softK, floorK) : (centerInShadow ? 0.0 : 1.0);

                float earlyShadowSum = 0.0;
                vec2 ringDir = phiDir;
                for (int i = 0; i < 4; i++) {
                    vec2  offset = ringDir * filterRadius;
                    ringDir      = vec2(-ringDir.y, ringDir.x);
                    float d = textureLod(shadowtex1, shadowUv + offset, 0.0).r;
                    earlyShadowSum += shadowTap(d, biasedReceiver, softK, floorK);
                }

                if (earlyShadowSum == 0.0 && centerInShadow && filterRadius < 0.008 && isFoliage == 0) shadow = 0.0;
                else if (earlyShadowSum > 3.99 && centerVis > 0.99) shadow = 1.0;
                else {
                    const float RING_W = 0.4;
                    float shadowSum = earlyShadowSum * RING_W + centerVis,
                          weightSum = 4.0 * RING_W + 1.0;
                    vec2 diskDir = GOLDEN_ROT4 * phiDir;
                    for (int i = 0; i < 12; i++) {
                        float r      = sqrt(float(i + 4) + 0.5) * 0.25;
                        vec2  offset = diskDir * (r * filterRadius);
                        diskDir      = GOLDEN_ROT * diskDir;

                        float d = textureLod(shadowtex1, shadowUv + offset, 0.0).r,
                            w = 1.0 - 0.6 * r * r;
                        shadowSum += w * shadowTap(d, biasedReceiver, softK, floorK);
                        weightSum += w;
                    }
                    shadow = shadowSum / weightSum;

                    //if (isFoliage != 0) shadow *= 3.14;
                }
            }

            float shadowEdge = max(abs(shadowNdcPos.x), abs(shadowNdcPos.y)),
                  shadowFade = smoothstep(0.985, 0.999, shadowEdge);
            shadow = mix(shadow, 1.0, shadowFade) * smoothstep(0.0, 0.2, lightPos.y);
            //shadow = 1.;
            foliageDepth *= 1.0 - shadowFade;

            const int   TINT_TAPS   = 8;
            const float TINT_RADIUS = 0.004;
            const float TINT_POWER  = 2.0;

            vec3 tintSum = vec3(0.0);
            vec2 tintDir = phiDir;
            for (int i = 0; i < TINT_TAPS; i++) {
                float r     = sqrt((float(i) + 0.5) / float(TINT_TAPS));
                vec2  uv    = shadowUv + tintDir * (r * TINT_RADIUS * distScale);
                tintDir     = GOLDEN_ROT * tintDir;

                float dAll = textureLod(shadowtex0, uv, 0.0).r;
                float dOpq = textureLod(shadowtex1, uv, 0.0).r;

                bool glassBlocks = (dAll < dOpq - 1e-5) && (dAll < biasedReceiver - blockerBias);

                vec3 tint = vec3(1.0);
                if (glassBlocks) {
                    vec4 c = textureLod(shadowcolor0, uv, 0.0);
                    tint = pow(mix(vec3(1.0), c.rgb, c.a), vec3(TINT_POWER));
                }
                tintSum += tint;
            }
            glassTint = mix(tintSum / float(TINT_TAPS), vec3(1.0), shadowFade);
        }

        const float DH_FAKE_SHADOW_START = 0.9,
                    DH_FAKE_SHADOW_END   = 0.95,
                    DH_FAKE_SHADOW_FLOOR = 0.0;

        if (isDhTerrain) {
            float dhLit = smoothstep(DH_FAKE_SHADOW_START, DH_FAKE_SHADOW_END, skyLightMap);
            shadow       = min(shadow, mix(DH_FAKE_SHADOW_FLOOR, 1.0, dhLit)) * smoothstep(0.0, 0.2, lightPos.y);
            foliageDepth = max(foliageDepth, 1.0 - dhLit);
        }

        // (304c) Thin-Plant Smooth Self-Shade
        float plantSelf = 1.0;
        if (isFoliage != 0 && isLeaves == 0 && isCloth == 0) {
            const float PLANT_CLUMP_TOP    = 0.90,
                        PLANT_CLUMP_RADIUS = 0.55,
                        PLANT_SELF_DENSITY = 2.6,
                        PLANT_SELF_MIN     = 0.15,
                        PLANT_BACK_RANGE   = 0.30,
                        PLANT_UPPER_FADE   = 0.35;

            vec2  lightXZ  = lightPos.xz,
                  faceDir  = -footPlayerPos.xz * inversesqrt(max(dot(footPlayerPos.xz, footPlayerPos.xz), 1e-4));
            float backFace = smoothstep(0.0, PLANT_BACK_RANGE, -dot(faceDir, lightXZ));

            if (backFace > 0.0) {
                vec3  plantWorldPos = cameraPosition + footPlayerPos;
                bool  isUpper       = (foliageCode == 4);
                vec2  clumpUv       = 0.5 * sin(plantWorldPos.xz * 5.0 + 1.6 * sin(plantWorldPos.zx * 3.1));
                float plantY        = fract(plantWorldPos.y + 0.02),
                      clumpH        = isUpper ? 1.0 + plantY : plantY,
                      clumpTop      = isUpper ? 1.0 + PLANT_CLUMP_TOP : PLANT_CLUMP_TOP,
                      invExitY      = max(lightPos.y, 0.0) / max(clumpTop - clumpH, 0.02);
                vec2  invExitXZ     = abs(lightXZ) / max(PLANT_CLUMP_RADIUS - clumpUv * sign(lightXZ), 0.02),
                      exitSq        = invExitXZ * invExitXZ;
                float invExit4      = dot(exitSq, exitSq) + sq(sq(invExitY)),
                      pathLen       = inversesqrt(sqrt(max(invExit4, 1e-6)));

                plantSelf = mix(1.0, mix(PLANT_SELF_MIN, 1.0, exp(-PLANT_SELF_DENSITY * pathLen)), backFace);
                if (isUpper) plantSelf = mix(1.0, plantSelf, smoothstep(0.0, PLANT_UPPER_FADE, plantY));
            }
        }
        shadow      *= plantSelf;
        foliageDepth = max(foliageDepth, 1.0 - plantSelf);

        // (304d) Underwater Lighting
        if (isEyeInWater == 1) {
            float uwDepth   = uwDepthAt(fragWorldPos.y, eyeCameraPos.y, uwEyeDepth());
            vec2  causticXZ = fragWorldPos.xz - keyDir.xz / max(keyDir.y, 0.3) * uwDepth;
            float caustic   = mix(0.45, 1.6, pow(uwCausticRidge(causticXZ, frameTimeCounter), 3.0));
            shadow         *= mix(1.0, caustic, UW_CAUSTIC_STRENGTH * exp(-UW_CAUSTIC_FADE * uwDepth));
            uwLightTint     = exp(-mix(UW_AMBIENT_EXT, UW_LIGHT_EXT, 0.6) * uwDepth);
        }

        // (305) Foliage Canopy Sunlit Tinting
        const float FOLIAGE_DEEP_TINT = 1.0;

        vec3 sunLight = sunlightC * shadow;
        if (isFoliage != 0) {
            vec3 leafHue = normalize(albedo.rgb + 1e-4) * 1.7320508;
            sunLight *= mix(vec3(1.0), leafHue, foliageDepth * FOLIAGE_DEEP_TINT);
        }

        // (306) Environmental Irradiance & Ambient Assembly
        const float SSGI_INTENSITY = 0.06;

        float rawSkyFactor    = worldNormal.y * 0.5 + 0.5,
              skyWeight       = smoothstep(0.20, 0.85, rawSkyFactor),
              sunSkyHaze      = NdotL * NdotL,
              finalVisibility = ((isFoliage == 1) ? mix(visibility, 1.0, 0.42) : visibility) * mix(1.0, plantSelf, PLANT_SELF_AO);

        vec3 localSky              = mix(ambientC, SUN_HAZE_COLOR, sunSkyHaze * 0.45 * ((NIGHT_WARM_HAZE != 0) ? 1.0 : 1.0 - nightP.x)),
             ambientDome           = mix(GROUND_AMBIENT_COLOR, localSky, skyWeight),
             environmentIrradiance = ambientDome * (skyLightMap * skyLightMap * sqrt(skyLightMap)),
             caveFloorIrradiance   = vec3(0.08, 0.09, 0.12) * (CAVE_MIN_LIGHT * 50.0),
             indirectBounce        = rsmRadiance * SSGI_INTENSITY * mix(0.7, 1.0, visibility) * smoothstep(0.2, 0.4, sunDir.y),
             skyIrradiance         = (environmentIrradiance + caveFloorIrradiance) * AMBIENT_INTENSITY + indirectBounce,
             skyReflection         = mix(GROUND_AMBIENT_COLOR, localSky, skyWeight) * skyLightMap;

        vec3  reflectDir   = reflect(-viewDir, worldNormal);
        float reflectUp    = saturate(reflectDir.y),
              horizonScale = clamp(dot(ambientC, vec3(0.3333)) / max(dot(mix(horizonC, skyC, 0.5), vec3(0.3333)), 1e-4), 0.5, 1.5);
        vec3  skyAtReflect = mix(horizonC, skyC, sqrt(reflectUp)) * horizonScale;
        skyReflection      = mix(GROUND_AMBIENT_COLOR, skyAtReflect, smoothstep(-0.15, 0.35, reflectDir.y)) * skyLightMap;

        // (307) Foliage & Plant Canopy Shading
        if (isFoliage != 0) {
            if (isLeaves != 0) {
                const float FOLIAGE_SUN_POWER            = 1.05,
                            FOLIAGE_WRAP_AMOUNT          = 0.2,
                            FOLIAGE_NOON_SQUASH          = 0.0,
                            FOLIAGE_MIE_STRENGTH         = 4.50,
                            FOLIAGE_MIE_G                = 0.55,
                            FOLIAGE_MS_WEIGHT            = 0.0,
                            FOLIAGE_DEEP_TINT            = 0.70,
                            FOLIAGE_TWO_SIDED            = 0.5,
                            FOLIAGE_NOON_START           = 0.5,
                            FOLIAGE_NOON_SSS_FADE        = 0.7,
                            FOLIAGE_NOON_SHADOW_CONTRAST = 1.5,
                            FOLIAGE_SHADOW_FLOOR_MIE     = 0.12,
                            FOLIAGE_MIE_EDGE_POWER       = 2.0;

                const vec3 FOLIAGE_TRANSMIT_TINT = vec3(1.30, 1.50, 0.35);

                float noLRaw        = dot(worldNormal, lightPos),
                      foliageNoL = mix(max(noLRaw, 0.0), abs(noLRaw), FOLIAGE_TWO_SIDED),
                      directNoL     = clamp(foliageNoL * (1.0 - FOLIAGE_WRAP_AMOUNT) + FOLIAGE_WRAP_AMOUNT, 0.0, 1.0),
                      noonZenith    = clamp(lightPos.y, 0.0, 1.0),
                      noonDampen    = 1.0 - (noonZenith * FOLIAGE_NOON_SQUASH * (1.0 - max(foliageNoL, 0.0) * 0.25)),
                      noonWeight    = smoothstep(FOLIAGE_NOON_START, 1.0, noonZenith),
                      noonShadow    = pow(shadow, 1.0 + noonWeight * FOLIAGE_NOON_SHADOW_CONTRAST),
                      sssElevation  = 1.0 - noonWeight * FOLIAGE_NOON_SSS_FADE,
                      leafLuma      = dot(mat.albedo, vec3(0.2126, 0.7152, 0.0722)),
                      cosTheta      = -dot(viewDir, lightPos),
                      g2            = FOLIAGE_MIE_G * FOLIAGE_MIE_G,
                      miePhase      = pow15((1.0 - FOLIAGE_MIE_G) * (1.0 - FOLIAGE_MIE_G) / (1.0 + g2 - 2.0 * FOLIAGE_MIE_G * cosTheta)) * FOLIAGE_MIE_STRENGTH,
                      backFace      = clamp(-noLRaw, 0.0, 1.0),
                      edgeBase      = 1.0 - abs(dot(viewDir, worldNormal)),
                      rim           = cube(edgeBase),
                      sssCanopyMask = smoothstep(0.70, 0.98, skyLightMap),
                      sssShadow     = mix(noonShadow, sqrt(sqrt(noonShadow)), FOLIAGE_MS_WEIGHT),
                      mieShadow     = sq(saturate((noonShadow - FOLIAGE_SHADOW_FLOOR_MIE) / (1.0 - FOLIAGE_SHADOW_FLOOR_MIE))) * (1.0 - foliageDepth),
                      mieEdge       = pow(edgeBase, FOLIAGE_MIE_EDGE_POWER);

                vec3 leafChroma   = mat.albedo / max(leafLuma, 1e-4),
                     depthTint    = mix(vec3(1.0), leafChroma, foliageDepth * FOLIAGE_DEEP_TINT),
                     diffuseLight = mat.albedo * sunlightC * depthTint * (directNoL * noonShadow * sunLeakMask * FOLIAGE_SUN_POWER * noonDampen),
                     sssTint      = mat.albedo * FOLIAGE_TRANSMIT_TINT * depthTint,
                     foliageSss   = sssTint * sunlightC * (rim * (0.25 * sssShadow + miePhase * mieShadow * mieEdge) * sssCanopyMask * sunLeakMask * sssElevation);

                vec3 ambientLighting = shadeAmbient(mat, worldNormal, viewDir, skyIrradiance, skyReflection, finalVisibility),
                     selfEmission    = mat.albedo * mat.emissive * 5.0;

                finalColor = diffuseLight + foliageSss + ambientLighting + selfEmission;
                if(isDhTerrain) finalColor = diffuseLight + foliageSss + ambientLighting;
            } else {
                const float PLANT_WRAP_AMOUNT    = 0.35,
                            PLANT_THICKNESS      = 0.05,
                            PLANT_MFP_SCALE      = 0.12,
                            PLANT_TRANSMIT_POWER = 0.6,
                            PLANT_RIM_SHARPNESS  = 2.0;

                float NoL       = dot(worldNormal, lightPos),
                      directNoL = clamp(NoL * (1.0 - PLANT_WRAP_AMOUNT) + PLANT_WRAP_AMOUNT, 0.0, 1.0),
                      grazing   = pow(1.0 - max(dot(worldNormal, viewDir), 0.0), PLANT_RIM_SHARPNESS);

                vec3 diffuseLight    = mat.albedo * sunlightC * directNoL * shadow * sunLeakMask,
                     plantMfp        = PLANT_MFP_SCALE * (0.15 + mat.albedo),
                     transmit        = burleyTransmittance(mat.albedo, plantMfp, PLANT_THICKNESS)
                                       * saturate(-NoL) * mix(0.25, 1.0, grazing) * PLANT_TRANSMIT_POWER
                                       * sunlightC * shadow * sunLeakMask,
                     ambientLighting = shadeAmbient(mat, worldNormal, viewDir, skyIrradiance, skyReflection, finalVisibility),
                     selfEmission    = mat.albedo * mat.emissive * 5.0;

                finalColor = diffuseLight + transmit + ambientLighting + selfEmission;
            }
            finalColor *= 0.3183 * glassTint;
        } else {
            // (308) Standard Terrain PBR Surface Shading
            float sunContactAo   = mix(0.0, 1.0, visibility);
            vec3  sunIlluminance = sunlightC * sunLeakMask * sunContactAo * glassTint,
                  sunSpecular    = keySpecC * sunLeakMask * glassTint;

            finalColor = PBRModule(
                mat, worldNormal, viewDir, lightPos,
                sunIlluminance, sunSpecular, shadow,
                skyIrradiance, skyReflection, finalVisibility,
                5.0
            );

            /*
            const float SSS_MFP_SCALE = 0.25,
                        SSS_STRENGTH  = 1.0;

            if (mat.sss > 0.0) {
                vec3 mfp = SSS_MFP_SCALE * mat.sss * (0.15 + mat.albedo);

                vec3 inwardShadowPos = getShadowCoord(worldPos - worldNormal * 0.05);
                float thickness      = sssThickness(inwardShadowPos);

                finalColor += SSS_STRENGTH * sssTransmission(worldNormal, lightPos, mat.albedo, mfp, thickness, sunlightC * sunLeakMask);
            }
            */
        }
    }
    finalColor *= uwLightTint;
    float fogDither   = ign,
              skyExposure = mix(FOG_CAVE_FLOOR, 1.0, saturate(float(eyeBrightnessSmooth.y) / 240.0));
        vec3  fogStart    = gbufferModelViewInverse[3].xyz,
              fogDir      = normalize(footPlayerPos - fogStart),
              fogEnd      = isSky ? fogStart + fogDir * FOG_SKY_DIST : footPlayerPos;
        finalColor = applyFog(finalColor, fogStart, fogEnd, fogDither, skyExposure, keyDir, keyDiscC * ((NIGHT_MOON_FOG_SHAFTS != 0) ? 1.0 : 1.0 - nightP.x), ambientC, isSky);

    // (400) Output Buffer Assignment
    outColor   = vec4(finalColor, 1.0);
    outReflect = isGlossy ? vec4(mat.F0, mat.pRough) : vec4(0.0);
}