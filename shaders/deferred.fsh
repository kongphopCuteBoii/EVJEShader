#version 460 compatibility

#include "/libs/irisEssentials.h"

#include "/libs/typeClassifier.h"
#include "/libs/gbufferPacking.h"

/* DRAWBUFFERS:57 */
layout(location = 0) out vec4 outGIAO;
layout(location = 1) out vec4 outNormalDepth;

uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform vec3 sunPosition;
uniform sampler2D shadowtex0, shadowcolor0;
uniform sampler2D firstNoise;

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;
    uniform mat4 dhProjectionInverse;
#endif

uniform int frameCounter;
uniform vec3 cameraPosition;
uniform float viewWidth, viewHeight;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

in vec2 texCoord;

#include "/libs/mathUtils.glsl"

#include "/libs/coreFunctions/atmosphericScattering.glsl"
#include "/libs/nightEditor.h"

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneousPos = projectionMatrix * vec4(position, 1.0);
    return homogeneousPos.xyz / homogeneousPos.w;
}

float linZ(float depth) {
    float z = depth * 2.0 - 1.0;
    return -(gbufferProjectionInverse[2][2] * z + gbufferProjectionInverse[3][2])
          /  (gbufferProjectionInverse[2][3] * z + gbufferProjectionInverse[3][3]);
}

vec3 getViewPos(vec2 coord) {
    float z = linZ(textureLod(depthtex2, coord, 0.0).r);
    return vec3((coord * 2.0 - 1.0) * vec2(gbufferProjectionInverse[0][0], gbufferProjectionInverse[1][1]) * z, -z);
}

const mat2 GOLDEN_ROT = mat2(cos(2.3999632), sin(2.3999632), -sin(2.3999632), cos(2.3999632));

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy) + 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

vec3 unDistortShadowClipPos(vec3 shadowClipPos) {
    float L_prime = length(shadowClipPos.xy);
    if (L_prime < 0.0001) return shadowClipPos;
    float L = (0.1 * L_prime) / (1.0 - L_prime);
    shadowClipPos.xy *= (L / L_prime);
    shadowClipPos.z *= 2.0;
    return shadowClipPos;
}

vec3 getVPLWorldPos(vec2 shadowUV, float shadowDepth) {
    vec3 ndc = vec3(shadowUV, shadowDepth) * 2.0 - 1.0;
    ndc = unDistortShadowClipPos(ndc);
    vec4 shadowView = shadowProjectionInverse * vec4(ndc, 1.0);
    shadowView.xyz /= shadowView.w;
    vec4 worldPos = shadowModelViewInverse * vec4(shadowView.xyz, 1.0);
    return worldPos.xyz;
}

void main() {
    ivec2 fp = ivec2(gl_FragCoord.xy) * 2;
vec2 uv = (vec2(fp) + 0.5) / vec2(viewWidth, viewHeight);

float depth = texelFetch(depthtex0, fp, 0).r;
vec4 gbuf1 = texelFetch(colortex1, fp, 0);
int sceneType = unpackSceneType(gbuf1.a);
vec3 worldNormal = decodeNormalOct(gbuf1.rg);
vec3 hNormal = worldNormal * 0.5 + 0.5;

    #ifdef DISTANT_HORIZONS
        float dhDepth = texture(dhDepthTex0, uv).r;
        bool isDHTerrain = (sceneType == TYPE_TERRAIN_DH) || (depth >= 1.0 && dhDepth < 1.0);
        bool isSky = (depth >= 1.0) && (!isDHTerrain);
        
        vec3 screenPos = isDHTerrain ? vec3(uv, dhDepth) : vec3(uv, depth);
        vec3 ndcPos    = screenPos * 2.0 - 1.0;
        vec3 viewPos   = isDHTerrain ? projectAndDivide(dhProjectionInverse, ndcPos)
                                     : projectAndDivide(gbufferProjectionInverse, ndcPos);
    #else
        bool isDHTerrain = false;
        bool isSky = (depth >= 1.0);
        vec3 screenPos = vec3(uv, depth);
        vec3 ndcPos    = screenPos * 2.0 - 1.0;
        vec3 viewPos   = projectAndDivide(gbufferProjectionInverse, ndcPos);
    #endif
    outNormalDepth = vec4(hNormal, isSky ? 0.0 : linZ(depth));

    if (isSky || (sceneType != TYPE_TERRAIN && sceneType != TYPE_TERRAIN_DH)) {
        outGIAO = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 viewNormal = transpose(mat3(gbufferModelViewInverse)) * worldNormal;

    vec3 footPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 eyePlayerPos = footPlayerPos + gbufferModelViewInverse[3].xyz;
    vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;
    vec3 fragWorldSpace = eyeCameraPosition + eyePlayerPos;


    float noise = getIGN(gl_FragCoord.xy);
    float phi = noise * 6.2831853;
    float viewDist = max(abs(viewPos.z), 0.1);

    float visibility = 1.0;
    float aoFade = 1.0 - smoothstep(48.0, 80.0, viewDist);

    if (aoFade > 0.0 && !isDHTerrain) {
        float aspect = viewWidth / viewHeight;
        float aoRadius = 1.0;
        
        float projScale = 0.5 * aoRadius / viewDist;
        vec2 radiusUV = vec2(projScale / aspect, projScale);
        radiusUV = min(radiusUV, vec2(0.6 / aspect, 0.6));
        
        float aoSum = 0.0;
        const int AO_SAMPLES = 8;
        vec2  aoDir  = vec2(cos(phi), sin(phi));
        
        for (int i = 0; i < AO_SAMPLES; i++) {
            float t = float(i + 0.5) / float(AO_SAMPLES);
            float r = fract(t + noise);
            float rs = sqrt(r);
            r = rs * sqrt(rs);
            
            vec2 offset = aoDir * (r * radiusUV);
            aoDir = GOLDEN_ROT * aoDir;
            
            vec3 sPos = getViewPos(uv + offset);
            vec3 v = sPos - viewPos;
            float distSq = dot(v, v);
            
            float cosTheta = dot(v, viewNormal) * inversesqrt(max(distSq, 0.00001));
            float falloff = clamp(1.0 - distSq / (aoRadius * aoRadius), 0.0, 1.0);
            float bias = mix(0.12, 0.05, clamp(viewDist / 20.0, 0.0, 1.0));
            
            aoSum += max(cosTheta - bias, 0.0) * falloff;
        }
        
        float aoIntensity = 2.8;
        float occlusion = (aoSum / float(AO_SAMPLES)) * aoIntensity;
        
        visibility = mix(1.0, clamp(1.0 - occlusion, 0.0, 1.0), aoFade);
        visibility *= sqrt(visibility);
    }

    vec3 rsmRadiance = vec3(0.0);
    float rsmFade = 1.0 - smoothstep(60.0, 100.0, viewDist);
    const vec3 SUN_LIGHT_COLOR = vec3(1.0);

    bool nightNoGI = (NIGHT_RSM_GI == 0) && (normalize(mat3(gbufferModelViewInverse) * sunPosition).y < -0.03);
    if (rsmFade > 0.0 && !isDHTerrain && !nightNoGI) {
        const int   RSM_SAMPLES      = 24;
        const float RSM_WORLD_RADIUS = 2.0;
        const float RSM_MIN_DIST_SQ  = 0.25;
        const float RSM_MAX_DIST_SQ  = 64.0;

        mat3 rsmRot      = mat3(shadowModelView);
        vec3 nView       = rsmRot * worldNormal;
        vec3 rsmBaseView = (shadowModelView * vec4(footPlayerPos, 1.0)).xyz;
        vec2 rsmDir      = vec2(cos(phi), sin(phi));
        vec2 rsmBaseNDC  = rsmBaseView.xy * vec2(shadowProjection[0][0], shadowProjection[1][1]) + shadowProjection[3].xy;

        vec2 rsmRadiusNDC = RSM_WORLD_RADIUS * vec2(shadowProjection[0][0], shadowProjection[1][1]);

        for (int i = 0; i < RSM_SAMPLES; i++) {
            float t     = (float(i) + 0.5) / float(RSM_SAMPLES);
            float r     = t * sqrt(t);
            r = mix(r, fract(r + noise), 0.25);

            vec2 tapDir    = rsmDir * r;
            rsmDir         = GOLDEN_ROT * rsmDir;
            vec2 sampleNDC = rsmBaseNDC + tapDir * rsmRadiusNDC;

            vec2 sampleUV = sampleNDC / (length(sampleNDC) + 0.1) * 0.5 + 0.5;
            if (any(lessThan(sampleUV, vec2(0.0))) || any(greaterThan(sampleUV, vec2(1.0)))) continue;

            float vplDepth = textureLod(shadowtex0, sampleUV, 0.0).r;
            if (vplDepth >= 1.0) continue;

            vec3 diff = vec3(tapDir * RSM_WORLD_RADIUS,
                             (vplDepth * 2.0 - 1.0) * 2.0 * shadowProjectionInverse[2][2] + shadowProjectionInverse[3][2] - rsmBaseView.z);
            float distSq = dot(diff, diff);
            if (distSq < RSM_MIN_DIST_SQ || distSq > RSM_MAX_DIST_SQ) continue;

            float dist  = sqrt(distSq);
            float NdotL = dot(nView, diff) / dist;
            if (NdotL < 0.1) continue;
            NdotL = clamp((NdotL - 0.1) / 0.9, 0.0, 1.0);

            vec3 vplAlbedo = textureLod(shadowcolor0, sampleUV, 0.0).rgb;
            float vplLuma  = dot(vplAlbedo, vec3(0.2126, 0.7152, 0.0722));
            vec3 pumped    = max(mix(vec3(vplLuma), vplAlbedo, 1.1), 0.0);

            float falloff     = clamp(1.0 - dist / 8.0, 0.0, 1.0);
            float attenuation = NdotL * falloff / (distSq * 0.65 + dist * 0.5 + 0.15);

            rsmRadiance += pumped * SUN_LIGHT_COLOR * attenuation;
        }
        rsmRadiance = (rsmRadiance / float(RSM_SAMPLES)) * 5.0;
        rsmRadiance *= rsmFade;
    }
    outGIAO = vec4(rsmRadiance, visibility);

}