#version 460 compatibility

uniform sampler2D colortex0, colortex2, colortex9, depthtex0, depthtex1, dhDepthTex0, shadowtex1;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse, dhProjectionInverse, shadowModelView, shadowProjection;
uniform vec3 cameraPosition;
uniform float near, far, frameTimeCounter;
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
/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor;

#include "/libs/nightEditor.h"
#include "/libs/coreFunctions/cloudSettings.glsl"
#include "/libs/coreFunctions/volumetricFog.glsl"
#include "/libs/mathUtils.glsl"

#define REFRACT 0.06
#define ABERRATION 0.35
#define SCENE_GAIN 5.0

float linZ(float d) { return 2.0*near*far / (far + near - (d*2.0-1.0)*(far-near)); }

vec3 viewPosFromDepth(mat4 projInverse, vec2 uv, float depth) {
    vec3 n = vec3(uv, depth) * 2.0 - 1.0;
    return vec3(n.xy * vec2(projInverse[0][0], projInverse[1][1]), projInverse[2][2] * n.z + projInverse[3][2])
         / (projInverse[2][3] * n.z + projInverse[3][3]);
}

vec3 cloudsOverSurface(vec3 color, vec3 footPlayerPos) {
    #ifdef MIRAI_CLOUDS
        vec3  rayVec   = footPlayerPos - gbufferModelViewInverse[3].xyz,
              cloudCam = vec3(cameraPosition.x, cameraPosition.y - CLOUD_ALTITUDE_BIAS, cameraPosition.z);
        float rayEndY  = cloudCam.y + rayVec.y;
        if (max(cloudCam.y, rayEndY) > CLOUD_HEIGHT && min(cloudCam.y, rayEndY) < CLOUD_MAX_Y) {
            float surfaceDist = length(rayVec);
            vec3  rayDir      = rayVec / surfaceDist;
            float cloudTrans;
            vec3  cloudRad;
            color = CLOUD_GRADE * miraiCloudCompositeCut(
                cloudCam, rayDir, keyDir, keyDiscC * (CLOUD_SUN_INPUT * 5. * ((NIGHT_MOON_CLOUDS != 0) ? 1.0 : 1.0 - nightP.x)), ambientC * CLOUD_AMBIENT_INPUT,
                color / CLOUD_GRADE, frameTimeCounter * CLOUD_WIND_SPEED, surfaceDist, cloudTrans, cloudRad);
        }
    #endif
    return color;
}

void main() {
    vec3  color = texture(colortex0, texCoord).rgb;
    vec4  data  = texture(colortex9, texCoord);
    float depth = texture(depthtex0, texCoord).r;

    if (data.a > 0.5 && abs(data.a - 0.5) > 0.01) {
        vec4  glass  = texture(colortex2, texCoord);
        vec2  delta  = (data.rg * 2.0 - 1.0),
              off    = delta * REFRACT;
        float glassZ = linZ(depth);

        vec3 refr;
        for (int i = 0; i < 3; i++) {
            vec2 uv = texCoord + off * (1.0 + float(i - 1) * ABERRATION);
            if (linZ(texture(depthtex1, uv).r) < glassZ) uv = texCoord;
            refr[i] = texture(colortex0, uv)[i];
        }

        vec3 tint = mix(vec3(1.0), glass.rgb * 2.0, saturate(glass.a + 0.5));
        color = refr * tint;

        vec3  glassPlayer = (gbufferModelViewInverse * vec4(viewPosFromDepth(gbufferProjectionInverse, texCoord, depth), 1.0)).xyz;
        float skyExposure = mix(FOG_CAVE_FLOOR, 1.0, saturate(float(eyeBrightnessSmooth.y) / 240.0));
        color = applyFog(color, gbufferModelViewInverse[3].xyz, glassPlayer, getIGN(gl_FragCoord.xy), skyExposure, keyDir, keyDiscC * ((NIGHT_MOON_FOG_SHAFTS != 0) ? 1.0 : 1.0 - nightP.x), ambientC, false);
    }

    float dhDepth = (depth < 1.0) ? 1.0 : texture(dhDepthTex0, texCoord).r;
    if (isEyeInWater == 0 && (depth < 1.0 || dhDepth < 1.0)) {
        vec3 surfaceView = (depth < 1.0) ? viewPosFromDepth(gbufferProjectionInverse, texCoord, depth)
                                         : viewPosFromDepth(dhProjectionInverse, texCoord, dhDepth);
        color = cloudsOverSurface(color, (gbufferModelViewInverse * vec4(surfaceView, 1.0)).xyz);
    }

    outColor = vec4(color * SCENE_GAIN, 1.0);
}
