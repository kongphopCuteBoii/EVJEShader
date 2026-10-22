#ifndef VOLUMETRIC_FOG_GLSL
#define VOLUMETRIC_FOG_GLSL

#include "/libs/skyGrade.h"

#ifndef PI
    #define PI 3.141592653589793
#endif
#ifndef saturate
    #define saturate(x) clamp(x, 0.0, 1.0)
#endif

// (071) Fog Constants
#ifndef FOG_STEPS
    #define FOG_STEPS 12
#endif
#ifndef FOG_STEPS_PER_BLOCK
    #define FOG_STEPS_PER_BLOCK 0.3
#endif

const float FOG_DENSITY           = 0.0035,
            FOG_BASE_HEIGHT       = 61.0,
            FOG_FALLOFF           = 16.0,
            FOG_MAX_EXPONENT      = 2.0,
            FOG_MARCH_DIST        = 160.0,
            FOG_SKY_DIST          = 512.0,
            FOG_SCATTER_ALBEDO    = 0.95,
            FOG_SUN_INTENSITY     = 0.60,
            FOG_AMBIENT_INTENSITY = 0.25,
            FOG_MIE_G_FORWARD     = 0.78,
            FOG_MIE_G_SOFT        = 0.25,
            FOG_MIE_BLEND         = 0.65,
            FOG_SHADOW_BIAS       = 0.0002,
            FOG_CAVE_FLOOR        = 0.10;
const vec3  FOG_TINT              = vec3(SKY_GRADE.x, SKY_GRADE.y * 0.95, SKY_GRADE.z) * 0.7;

// (072) Henyey-Greenstein Phase
float phaseHG(float cosTheta, float g) {
    float g2 = g * g,
          d  = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * PI * d * sqrt(d));
}

// (073) Exponential Height Density
float fogDensity(float worldY) {
    return FOG_DENSITY * exp(min(-(worldY - FOG_BASE_HEIGHT) / FOG_FALLOFF, FOG_MAX_EXPONENT));
}

// (074) Analytic Optical Depth
float fogOpticalDepth(float startY, float endY, float rayLen) {
    float floorY = FOG_BASE_HEIGHT - FOG_MAX_EXPONENT * FOG_FALLOFF,
          y0     = max(startY, floorY),
          y1     = max(endY, floorY),
          deltaY = y1 - y0,
          d0     = fogDensity(y0);
    if (abs(deltaY) < 1e-3) return d0 * rayLen;
    return d0 * rayLen * FOG_FALLOFF * (1.0 - exp(-deltaY / FOG_FALLOFF)) / deltaY;
}

// (075) Single-Tap Fog Shadow
vec3 fogDistortShadow(vec3 shadowClipPos) {
    shadowClipPos.xy /= length(shadowClipPos.xy) + 0.1;
    shadowClipPos.z  *= 0.5;
    return shadowClipPos;
}

float fogShadow(vec3 shadowClipPos) {
    vec3 shadowScreenPos = fogDistortShadow(shadowClipPos) * 0.5 + 0.5;
    if (saturate(shadowScreenPos) != shadowScreenPos) return 1.0;
    return step(shadowScreenPos.z - FOG_SHADOW_BIAS, textureLod(shadowtex1, shadowScreenPos.xy, 0.0).r);
}

// (076) Raymarched In-Scatter + Transmittance
vec4 getVolumetricFog(vec3 rayStart, vec3 rayEnd, float dither, float skyExposure, vec3 sunDirW, vec3 sunCol, vec3 ambCol) {
    vec3  rayVec   = rayEnd - rayStart;
    float rayLen   = length(rayVec);
    vec3  rayDir   = rayVec / max(rayLen, 1e-4);
    float marchLen = min(rayLen, FOG_MARCH_DIST),
          cosTheta = dot(rayDir, sunDirW),
          sunPhase = mix(phaseHG(cosTheta, FOG_MIE_G_SOFT), phaseHG(cosTheta, FOG_MIE_G_FORWARD), FOG_MIE_BLEND);
    vec3  sunScatter = sunCol * (sunPhase * FOG_SUN_INTENSITY),
          ambScatter = ambCol * (FOG_AMBIENT_INTENSITY * skyExposure);

    vec3 marchEnd        = rayStart + rayDir * marchLen,
         shadowClipStart = (shadowProjection * vec4((shadowModelView * vec4(rayStart, 1.0)).xyz, 1.0)).xyz,
         shadowClipEnd   = (shadowProjection * vec4((shadowModelView * vec4(marchEnd, 1.0)).xyz, 1.0)).xyz;

    int   steps         = int(clamp(ceil(marchLen * FOG_STEPS_PER_BLOCK), 4.0, float(FOG_STEPS)));
    bool  sunLit        = max(sunScatter.r, max(sunScatter.g, sunScatter.b)) > 1e-5;
    float transmittance = 1.0,
          invSteps      = 1.0 / float(steps);
    vec3  inScatter     = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        float fracNear  = float(i) * invSteps,
              fracFar   = fracNear + invSteps,
              segNear   = fracNear * fracNear * marchLen,
              segFar    = fracFar  * fracFar  * marchLen,
              stepLen   = segFar - segNear,
              sampleT   = mix(segNear, segFar, dither),
              sampleY   = cameraPosition.y + rayStart.y + rayDir.y * sampleT,
              density   = fogDensity(sampleY),
              stepTrans = exp(-density * stepLen);
        vec3  stepLight = (sunLit ? sunScatter * fogShadow(mix(shadowClipStart, shadowClipEnd, sampleT / max(marchLen, 1e-4))) : vec3(0.0)) + ambScatter;
        inScatter     += transmittance * stepLight * (FOG_SCATTER_ALBEDO * (1.0 - stepTrans));
        transmittance *= stepTrans;
        if (transmittance < 0.01) break;
    }

    if (rayLen > marchLen) {
        float tailOptic = fogOpticalDepth(cameraPosition.y + marchEnd.y, cameraPosition.y + rayEnd.y, rayLen - marchLen),
              tailTrans = exp(-tailOptic);
        inScatter     += transmittance * (sunScatter + ambScatter) * (FOG_SCATTER_ALBEDO * (1.0 - tailTrans));
        transmittance *= tailTrans;
    }
    return vec4(inScatter * FOG_TINT, transmittance);
}

// (080) UNDERWATER MEDIUM
uniform int isEyeInWater;

#ifndef UW_STEPS
    #define UW_STEPS 10
#endif
const vec3  UW_EXTINCTION      = vec3(0.150, 0.052, 0.042),
            UW_LIGHT_EXT       = vec3(0.280, 0.085, 0.060),
            UW_AMBIENT_EXT     = vec3(0.110, 0.040, 0.030),
            UW_WATER_COLOR     = vec3(0.30, 1.00, 0.85);
const float UW_MARCH_DIST      = 72.0,
            UW_SKY_DIST        = 56.0,
            UW_LIGHT_DEPTH     = 15.0,
            UW_ALBEDO          = 0.92,
            UW_SUN_INTENSITY   = 1.5,
            UW_AMBIENT         = 2.2,
            UW_PHASE_G         = 0.72,
            UW_SHAFT_CONTRAST  = 0.55,
            UW_CAUSTIC_STRENGTH = 0.75,
            UW_CAUSTIC_FADE    = 0.10;

// (081) Eye Depth Below The Surface
float uwEyeDepth() {
    return (1.0 - saturate(float(eyeBrightnessSmooth.y) / 240.0)) * UW_LIGHT_DEPTH;
}

float uwDepthAt(float worldY, float eyeWorldY, float eyeDepth) {
    return max(eyeDepth + (eyeWorldY - worldY), 0.0);
}

// (082) Caustic Ripples
float uwCausticRidge(vec2 xz, float t) {
    vec2  q = xz * 0.65;
    float a = sin(q.x * 1.7 + sin(q.y * 1.3 + t * 0.8) * 1.4 + t * 0.9),
          b = sin(q.y * 1.9 + sin(q.x * 1.1 - t * 0.7) * 1.6 - t * 0.8);
    return 1.0 - abs(0.5 * (a + b));
}

// (083) Underwater Fog
vec3 applyUnderwaterFog(vec3 color, vec3 rayStart, vec3 rayEnd, float dither, vec3 keyDirW, vec3 keyCol, vec3 ambCol, bool isSkyPx) {
    vec3  rayVec = rayEnd - rayStart;
    float rayLen = length(rayVec);
    vec3  rayDir = rayVec / max(rayLen, 1e-4);
    float eyeY   = cameraPosition.y + rayStart.y,
          eyeD   = uwEyeDepth();

    if (isSkyPx) {
        float window = smoothstep(0.55, 0.78, rayDir.y);
        color *= window * exp(-UW_EXTINCTION * (eyeD / max(rayDir.y, 0.2)));
        rayLen = UW_SKY_DIST;
        rayEnd = rayStart + rayDir * rayLen;
    }

    float marchLen = min(rayLen, UW_MARCH_DIST),
          cosTheta = dot(rayDir, keyDirW),
          phase    = phaseHG(cosTheta, UW_PHASE_G) + 0.08;
    vec3  sunScatter = keyCol * (phase * UW_SUN_INTENSITY),
          marchEnd   = rayStart + rayDir * marchLen,
          clipStart  = (shadowProjection * vec4((shadowModelView * vec4(rayStart, 1.0)).xyz, 1.0)).xyz,
          clipEnd    = (shadowProjection * vec4((shadowModelView * vec4(marchEnd, 1.0)).xyz, 1.0)).xyz;

    float invSteps = 1.0 / float(UW_STEPS),
          slant    = 1.0 / max(keyDirW.y, 0.3),
          time     = frameTimeCounter;
    vec2  lightXZ  = keyDirW.xz * slant;
    vec3  trans    = vec3(1.0),
          inScatter = vec3(0.0);

    for (int i = 0; i < UW_STEPS; i++) {
        float fracNear = float(i) * invSteps,
              fracFar  = fracNear + invSteps,
              segNear  = fracNear * fracNear * marchLen,
              segFar   = fracFar  * fracFar  * marchLen,
              stepLen  = segFar - segNear,
              sampleT  = mix(segNear, segFar, dither),
              depth    = uwDepthAt(eyeY + rayDir.y * sampleT, eyeY, eyeD);
        vec3  stepTrans = exp(-UW_EXTINCTION * stepLen);

        vec3  samplePos = rayStart + rayDir * sampleT;
        float shaft     = mix(1.0, 0.45 + 1.1 * smoothstep(0.25, 0.95, uwCausticRidge(cameraPosition.xz + samplePos.xz - lightXZ * depth, time)), UW_SHAFT_CONTRAST),
              lit       = fogShadow(mix(clipStart, clipEnd, sampleT / max(marchLen, 1e-4)));
        vec3  stepLight = sunScatter * exp(-UW_LIGHT_EXT * (depth * slant)) * (lit * shaft)
                        + ambCol * UW_AMBIENT * exp(-UW_AMBIENT_EXT * depth);
        inScatter += trans * stepLight * (UW_ALBEDO * (vec3(1.0) - stepTrans));
        trans     *= stepTrans;
        if (max(trans.r, max(trans.g, trans.b)) < 0.01) break;
    }

    if (rayLen > marchLen) {
        vec3 tailTrans = exp(-UW_EXTINCTION * (rayLen - marchLen));
        float tailDepth = uwDepthAt(eyeY + rayDir.y * rayLen, eyeY, eyeD);
        inScatter += trans * ambCol * UW_AMBIENT * exp(-UW_AMBIENT_EXT * tailDepth) * (UW_ALBEDO * (vec3(1.0) - tailTrans));
        trans     *= tailTrans;
    }
    return color * trans + inScatter * UW_WATER_COLOR;
}

// (090) Fog Dispatcher
vec3 applyFog(vec3 color, vec3 rayStart, vec3 rayEnd, float dither, float skyExposure, vec3 keyDirW, vec3 keyCol, vec3 ambCol, bool isSkyPx) {
    if (isEyeInWater == 1) return applyUnderwaterFog(color, rayStart, rayEnd, dither, keyDirW, keyCol, ambCol, isSkyPx);
    vec4 fog = getVolumetricFog(rayStart, rayEnd, dither, skyExposure, keyDirW, keyCol, ambCol);
    return color * fog.a + fog.rgb;
}

#endif
