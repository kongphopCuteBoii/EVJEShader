#ifndef CRYSTALINE_WATER_SSR_GLSL
#define CRYSTALINE_WATER_SSR_GLSL

// (002) Distant Horizons support
#ifdef DISTANT_HORIZONS
    uniform mat4 dhProjection;
    #ifndef WATER_SSR_MAX_DISTANCE_DH
        #define WATER_SSR_MAX_DISTANCE_DH 1024.0
    #endif
#endif

// (001) Tunables
#ifndef WATER_SSR_STEPS
    #define WATER_SSR_STEPS 20
#endif
#ifndef WATER_SSR_STRIDE
    #define WATER_SSR_STRIDE 2.0
#endif
#ifndef WATER_SSR_GROWTH
    #define WATER_SSR_GROWTH 1.6
#endif
#ifndef WATER_SSR_GAP_TRUST
    #define WATER_SSR_GAP_TRUST 0.6
#endif
#ifndef WATER_SSR_REFINE
    #define WATER_SSR_REFINE 4
#endif
#ifndef WATER_SSR_MAX_DISTANCE
    #define WATER_SSR_MAX_DISTANCE 96.0
#endif
#ifndef WATER_SSR_THICKNESS
    #define WATER_SSR_THICKNESS 0.1
#endif
#ifndef WATER_SSR_RELATIVE_THICKNESS
    #define WATER_SSR_RELATIVE_THICKNESS 0.004
#endif
#ifndef WATER_SSR_STEP_THICKNESS
    #define WATER_SSR_STEP_THICKNESS 0.5
#endif
#ifndef WATER_SSR_SUBMERGED_TOLERANCE
    #define WATER_SSR_SUBMERGED_TOLERANCE 0.15
#endif
#ifndef WATER_SSR_BACKFACE
    #define WATER_SSR_BACKFACE 1
#endif
#ifndef WATER_SSR_DISTORTION
    #define WATER_SSR_DISTORTION 0.8
#endif
#ifndef WATER_SSR_MAX_WOBBLE
    #define WATER_SSR_MAX_WOBBLE 0.06
#endif
#ifndef WATER_SSR_CONE
    #define WATER_SSR_CONE 1.0
#endif
#ifndef WATER_SSR_MAX_LOD
    #define WATER_SSR_MAX_LOD 4.0
#endif
#ifndef WATER_SSR_NORMAL_FLATTEN
    #define WATER_SSR_NORMAL_FLATTEN 0.42
#endif


#ifndef saturate
    #define saturate(x) clamp(x, 0.0, 1.0)
#endif

// (010) Depth Helpers
float waterSSRLinZ(float d, mat4 proj) {
    return proj[3][2] / (d * 2.0 - 1.0 + proj[2][2]);
}

float waterSSRSceneZ(vec2 uv) {
    float d = textureLod(depthtex1, uv, 0.0).r;
    if (d < 0.999999) return waterSSRLinZ(d, gbufferProjection);

    #ifdef DISTANT_HORIZONS
        float dhD = textureLod(dhDepthTex1, uv, 0.0).r;
        if (dhD < 0.999999) return waterSSRLinZ(dhD, dhProjection);
    #endif

    return 1e9;
}

bool waterSSRCovered(vec2 uv) {
    bool covered = textureLod(depthtex0, uv, 0.0).r
                 < textureLod(depthtex1, uv, 0.0).r - 1e-6;
    #ifdef DISTANT_HORIZONS
        covered = covered || textureLod(dhDepthTex0, uv, 0.0).r
                            < textureLod(dhDepthTex1, uv, 0.0).r - 1e-6;
    #endif
    return covered;
}

// (020) Ray Tracer
vec4 traceWaterSSR(vec3 surfaceViewPos, vec3 traceNormalView, vec3 detailNormalView,
                   float roughness, float maxDistance, float surfaceWorldY, out float occlusion) {
    occlusion = 0.0;

    // (021) Ray Setup
    vec3 V = normalize(surfaceViewPos),
         N = normalize(traceNormalView),
         D = normalize(reflect(V, N));
    if (D.z > -0.02) return vec4(0.0);
    float facingFade = smoothstep(0.02, 0.12, -D.z);

    vec3  O        = surfaceViewPos + N * 0.03;
    float surfaceZ = -surfaceViewPos.z;

    // (022) Screen-Space Segment
    vec4  c0 = gbufferProjection * vec4(O, 1.0),
          c1 = gbufferProjection * vec4(O + D * maxDistance, 1.0);
    float k0 = 1.0 / c0.w,
          k1 = 1.0 / c1.w,
          dk = k1 - k0;
    vec2  uv0 = c0.xy * k0 * 0.5 + 0.5,
          uv1 = c1.xy * k1 * 0.5 + 0.5,
          duv = uv1 - uv0;

    if (any(lessThan(uv0, vec2(0.002))) || any(greaterThan(uv0, vec2(0.998)))) return vec4(0.0);

    vec2  safeDuv = duv + (step(0.0, duv) * 2.0 - 1.0) * 1e-7,
          tClip   = (mix(vec2(0.002), vec2(0.998), step(0.0, duv)) - uv0) / safeDuv;
    float sEnd    = min(1.0, min(tClip.x, tClip.y));

    float pxPerS = length(duv * vec2(textureSize(depthtex1, 0)));
    if (sEnd * pxPerS < 2.0) return vec4(0.0);

    // (023) March Parameters
    float dsMin  = WATER_SSR_STRIDE / pxPerS,
          dsCap  = max(0.25 * sEnd, dsMin),
          jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float s = dsMin * jitter, ds = dsMin, prevS = 0.0, prevDelta = -1.0;

    // (024) Gap-Driven March
    for (int i = 0; i < WATER_SSR_STEPS; ++i) {
        s = min(s + ds, sEnd);

        float rayZ  = 1.0 / (k0 + dk * s),
              delta = rayZ - waterSSRSceneZ(uv0 + duv * s),
              zRate = abs(dk) * rayZ * rayZ;

        // (025) Crossing
        if (delta > 0.0 && prevDelta <= 0.0) {
            float lo = prevS, hi = s;
            for (int r = 0; r < WATER_SSR_REFINE; ++r) {
                float m = 0.5 * (lo + hi);
                if (1.0 / (k0 + dk * m) > waterSSRSceneZ(uv0 + duv * m)) hi = m; else lo = m;
            }

            vec2  hitUV     = uv0 + duv * hi;
            float hitRayZ   = 1.0 / (k0 + dk * hi),
                  hitSceneZ = waterSSRSceneZ(hitUV),
                  thick     = WATER_SSR_THICKNESS + hitSceneZ * WATER_SSR_RELATIVE_THICKNESS
                            + zRate * (s - prevS) * WATER_SSR_STEP_THICKNESS,
                  penetr    = hitRayZ - hitSceneZ;

            if (hitSceneZ < 1e8 && penetr <= thick) {
                float t = (-hitRayZ - O.z) / D.z;

                vec3  rowY = vec3(gbufferModelViewInverse[0][1], gbufferModelViewInverse[1][1], gbufferModelViewInverse[2][1]);
                float hitY = surfaceWorldY + dot(rowY, O + D * t - surfaceViewPos);
                bool  valid = hitY >= surfaceWorldY - WATER_SSR_SUBMERGED_TOLERANCE;

                #if WATER_SSR_BACKFACE
                    if (valid) {
                        vec4 hitG = texelFetch(colortex1, ivec2(hitUV * vec2(textureSize(colortex1, 0))), 0);
                        valid = dot(decodeNormalOct(hitG.rg), mat3(gbufferModelViewInverse) * D) < 0.25 && unpackSceneType(hitG.a) != TYPE_HAND;
                    }
                #endif

                if (valid) {
                    // (026) Detail re-aim
                    vec2 uvR = hitUV;
                    if (WATER_SSR_DISTORTION > 0.0) {
                        vec3 Dd = normalize(mix(D, reflect(V, normalize(detailNormalView)), WATER_SSR_DISTORTION)),
                             Pd = O + Dd * t;
                        if (Pd.z < -0.05) {
                            vec4 cd  = gbufferProjection * vec4(Pd, 1.0);
                            vec2 uvD = cd.xy / cd.w * 0.5 + 0.5;
                            uvD = hitUV + clamp(uvD - hitUV, vec2(-WATER_SSR_MAX_WOBBLE), vec2(WATER_SSR_MAX_WOBBLE));

                            bool inside      = all(greaterThan(uvD, vec2(0.002))) && all(lessThan(uvD, vec2(0.998)));
                            bool behindWater = waterSSRSceneZ(uvD) > surfaceZ + 0.5;
                                                        bool notCovered  = !waterSSRCovered(uvD);

                            if (inside && behindWater && notCovered) uvR = uvD;
                        }
                    }

                    // (027) Roughness cone
                    float travelPx = hi * pxPerS,
                          lod      = clamp(log2(max(travelPx * roughness * WATER_SSR_CONE, 1.0)), 0.0, WATER_SSR_MAX_LOD);

                    float edge = min(min(uvR.x, 1.0 - uvR.x), min(uvR.y, 1.0 - uvR.y)),
                          conf = smoothstep(0.0, 0.04, edge)
                               * (1.0 - smoothstep(0.8, 1.0, t / maxDistance))
                               * smoothstep(0.2, 1.0, t)
                               * (1.0 - smoothstep(0.5, 1.0, penetr / thick))
                               * facingFade;
                    return vec4(textureLod(colortex0, uvR, lod).rgb, conf);
                }
            }
        }

        // (028) Next Stride
        float grown   = ds * WATER_SSR_GROWTH,
              gapStep = delta <= 0.0 ? -delta / max(zRate, 1e-6) * WATER_SSR_GAP_TRUST : grown;
        ds        = clamp(gapStep, dsMin, min(grown, dsCap));
        prevDelta = delta;
        prevS     = s;
        if (s >= sEnd) break;
    }

    occlusion = smoothstep(0.0, 1.0, prevDelta) * facingFade;
    return vec4(0.0);
}
#endif