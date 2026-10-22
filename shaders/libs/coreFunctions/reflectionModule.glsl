#ifndef REFLECTION_MODULE_GLSL
#define REFLECTION_MODULE_GLSL

// (001) Tunables
#ifndef REFLECTION_SKY_GAIN
    #define REFLECTION_SKY_GAIN     0.3
#endif
#ifndef REFLECTION_SKY_GRADE
    #define REFLECTION_SKY_GRADE    SKY_GRADE
#endif
#ifndef REFLECTION_OCCLUDED_SKY
    #define REFLECTION_OCCLUDED_SKY 0.15
#endif

// (002) Environment Reflection
vec3 environmentReflection(vec3 viewPos, vec3 nTraceView, vec3 nDetailView, vec3 reflectDirWorld, float roughness,
                           float surfaceWorldY, float maxDistance, float skyVisibility,
                           float skyGain, vec3 skyGrade, vec3 reflectionTint, out float ssrConfidence) {
    float ssrOcclusion = 0.0;
    vec4  ssr          = traceWaterSSR(viewPos, nTraceView, nDetailView, roughness, maxDistance, surfaceWorldY, ssrOcclusion);

    float skyPx = 2.0 / (gbufferProjection[1][1] * viewHeight);
    vec3  sky   = skyHDR(reflectDirWorld, vAtlas, sunDir, vec3(0.0), skyC, horizonC, skyPx * 1.5, skyPx) * skyGrade * skyGain;
    sky += nightSky(reflectDirWorld, sunDir, nightP, skyPx, frameTimeCounter, 0.0) * skyGain;
    sky *= mix(1.0, REFLECTION_OCCLUDED_SKY, ssrOcclusion) * skyVisibility;

    ssrConfidence = saturate(ssr.a);
    return mix(sky, ssr.rgb, ssrConfidence) * reflectionTint;
}

#endif
