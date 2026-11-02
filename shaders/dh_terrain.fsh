#version 460 compatibility
#include "/libs/typeClassifier.h"
#include "/libs/gbufferPacking.h"
#include "/libs/materialDefaults.h"
#include "/libs/mathUtils.glsl"

const int TYPE = 2;
uniform float viewWidth, viewHeight;
uniform sampler2D depthtex0;
uniform float far;
uniform vec3  cameraPosition;

#ifndef DH_FACE_SHADE
    #define DH_FACE_SHADE 1
#endif

/* DRAWBUFFERS:012 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outPBR;

in vec4 fColor;
in vec3 worldN;
in vec2 lightCoord;
in vec3 worldPos;
flat in int isLeaves;

#define DH_OVERDRAW_DISTANCE 16.0
#define DH_OVERDRAW_FADE_LENGTH 16.0
void main() {
    if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r < 1.0) discard;
    if (fColor.a < 0.1) discard;

    float dhFadeDistE = max(far - DH_OVERDRAW_DISTANCE, 0.0),
          dhFadeDistS = max(dhFadeDistE - DH_OVERDRAW_FADE_LENGTH, 0.0),
          dhFadeDist  = smoothstep(dhFadeDistS, dhFadeDistE, length(worldPos));
    if (dhFadeDist < getIGN(gl_FragCoord.xy)) discard;

    vec3 baseColor = fColor.rgb;
    vec3 worldNormal = normalize(worldN);
    #if DH_FACE_SHADE
        vec3  cubeN     = abs(worldNormal);
        float faceShade = dot(cubeN * cubeN, vec3(0.6, worldN.y > 0.0 ? 1.0 : 0.5, 0.8));
        baseColor *= faceShade;
    #endif
    vec3 albedo = pow_linear(baseColor);

    if (isLeaves != 0) {
        vec3 absPos     = worldPos + cameraPosition,
             p1         = absPos * 0.15,
             p2         = absPos * 0.35,
             macroClump = sin(p1.yzx * 1.5 + sin(p1.zxy * 2.0)) * 0.22
                        + sin(p2.zxy * 2.5) * 0.10;
        worldNormal = normalize(worldNormal * 0.40 + macroClump * 0.30 + vec3(0.0, 1.0, 0.0) * 0.30);
    }

    outColor      = vec4(albedo, fColor.a);
    outNormal     = vec4(encodeNormalOct(worldNormal), lightCoord.y,
                         packSceneClass(TYPE, isLeaves != 0 ? 2 : 0));

    outPBR        = fallbackPBR();
}
