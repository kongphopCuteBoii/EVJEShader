// (i) Special thanks to afl_ext, bambosan
#ifndef SWELL_INCLUDED
#define SWELL_INCLUDED

// (001) User Options
#define WAVE_HEIGHT          0.06 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.4 0.5 0.75 1.0]
#define WAVE_BUMPINESS       0.05 // [0.04 0.06 0.08 0.1 0.12 0.15 0.18 0.22 0.26 0.3 0.35 0.4 0.5]
#define WAVE_LENGTH          6.0  // [4.0 6.0 8.0 12.0 16.0 20.0 24.0 32.0 48.0 64.0]
#define WAVE_DETAIL          16   // [6 8 10 12 14 16 20]
#define WAVE_RIPPLES         0.5  // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WAVE_CHOPPINESS      0.5  // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WAVE_DIRECTIONALITY  0.6  // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WAVE_GROUPS          0.4  // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WAVE_SPEED           0.7  // [0.0 0.25 0.5 0.7 1.0 1.5 2.0]
#define WIND_ANGLE           30   // [0 30 60 90 120 150 180 210 240 270 300 330]
#define WAVE_VARIATION       0.6  // [0.0 0.2 0.4 0.6 0.8 1.0]
#define WAVE_PATCHES         0.5  // [0.0 0.2 0.4 0.5 0.6 0.8 1.0]
#define WAVE_PATCH_SIZE      32.0 // [32.0 48.0 64.0 96.0 128.0 192.0 256.0]
#define WAVE_VERTEX_OCTAVES  4    // [2 3 4 5 6]
#define WAVE_SWELL           0.5  // [0.0 0.25 0.5 0.75 1.0]
#define WAVE_SLICKS          0.6  // [0.0 0.2 0.4 0.6 0.8 1.0]
#define WAVE_SLICK_SIZE      96.0 // [48.0 64.0 96.0 128.0 192.0 256.0]
#define WAVE_LOD             2.0  // [1.0 1.5 2.0 3.0]
#define WAVE_PARALLAX        1.0  // [0.0 0.25 0.5 0.75 1.0]
#define SWELL_KERNEL         0    // [0 1]

// (002) Internals
#define SWELL_OCTAVES_MAX 20
#define SWELL_PACKET_FREQ 0.12
#define SWELL_PERIOD      4096.0
#define SWELL_GUST_DRIFT  1.5

const float SWELL_TAU        = 6.2831853,
            SWELL_PI         = 3.1415927,
            SWELL_G          = 9.81,
            SWELL_Q          = 1.32,
            SWELL_LAT        = SWELL_PERIOD / SWELL_TAU,
            SWELL_K0         = SWELL_TAU / WAVE_LENGTH,
            SWELL_R          = 0.70 + 0.25 * WAVE_RIPPLES,
            SWELL_WIND       = radians(float(WIND_ANGLE)),
            SWELL_SW_DIR     = SWELL_WIND + radians(40.0),
            SWELL_SPREAD_SW  = 0.15,
            SWELL_SPREAD_LO  = mix(1.40, 0.15, WAVE_DIRECTIONALITY),
            SWELL_SPREAD_HI  = mix(3.14, 1.10, WAVE_DIRECTIONALITY),
            SWELL_GROUP_RMS  = sqrt(1.0 - WAVE_GROUPS + 0.375 * WAVE_GROUPS * WAVE_GROUPS),
            SWELL_WARP_SCALE = WAVE_LENGTH * 5.0,
            SWELL_WARP_AMP   = WAVE_LENGTH * 0.35 * WAVE_VARIATION;
#define SWELL_SLICK_DRIFT 0.3

const vec2  SWELL_MW = floor(2.0 * vec2(sin(SWELL_WIND), cos(SWELL_WIND)) + 0.5);
const float SWELL_ML = length(SWELL_MW);
const vec2  SWELL_MC = max(floor(SWELL_PERIOD / (SWELL_ML * vec2(4.0, 1.0) * WAVE_SLICK_SIZE)), 1.0);

#define SWELL_FAR_TEX
#ifdef SWELL_FAR_TEX
    uniform sampler2D swellNoiseTex;
    #ifndef SWELL_TEX
        #define SWELL_TEX swellNoiseTex
    #endif
const vec2  SWELL_P1 = floor(5.0 * vec2(sin(SWELL_WIND - 0.17), cos(SWELL_WIND - 0.17)) + 0.5),
            SWELL_P2 = floor(7.0 * vec2(sin(SWELL_WIND + 0.61), cos(SWELL_WIND + 0.61)) + 0.5);
const float SWELL_T1 = max(floor(SWELL_PERIOD / (14.0 * WAVE_LENGTH * length(SWELL_P1)) + 0.5), 1.0) / SWELL_PERIOD,
            SWELL_T2 = max(floor(SWELL_PERIOD / (10.0 * WAVE_LENGTH * length(SWELL_P2)) + 0.5), 1.0) / SWELL_PERIOD,
            SWELL_V1 = sqrt(SWELL_G / (SWELL_TAU * 14.0 * SWELL_T1 * length(SWELL_P1))) * WAVE_SPEED * length(SWELL_P1) * SWELL_T1,
            SWELL_V2 = sqrt(SWELL_G / (SWELL_TAU * 14.0 * SWELL_T2 * length(SWELL_P2))) * WAVE_SPEED * length(SWELL_P2) * SWELL_T2;
#endif

// (003) Data
struct SwellSample {
    float h;
    vec2  grad;
    float rough;
};

// (004) Coordinates
vec2 swellCoord(vec2 relXZ, vec3 camPos) {
    return mod(camPos.xz, SWELL_PERIOD) + relXZ;
}

vec2 swellSnap(vec2 kv) {
    return floor(kv * SWELL_LAT + 0.5) / SWELL_LAT;
}

// (005) Periodic value noise with analytic derivatives
float swellHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 swellHash2(vec2 p) {
    vec3 p3 = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 swellNoise(vec2 x, vec2 cells, float seed) {
    vec2 i  = floor(x), f = x - i;
    vec2 u  = f * f * f * (f * (f * 6.0 - 15.0) + 10.0),
         du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    vec2 i0 = mod(i, cells), i1 = mod(i + 1.0, cells);
    float a = swellHash(i0 + seed),
          b = swellHash(vec2(i1.x, i0.y) + seed),
          c = swellHash(vec2(i0.x, i1.y) + seed),
          d = swellHash(i1 + seed);
    float k1 = b - a, k2 = c - a, k4 = a - b - c + d;
    return vec3(a + k1 * u.x + k2 * u.y + k4 * u.x * u.y,
                du * (vec2(k1, k2) + k4 * u.yx));
}

vec3 swellNoise(vec2 x, float cells, float seed) {
    return swellNoise(x, vec2(cells), seed);
}

vec3 swellFbm(vec2 xz, float scale, float seed) {
    float cells  = max(floor(SWELL_PERIOD / scale), 1.0),
          toCell = cells / SWELL_PERIOD;
    vec3 n = swellNoise(xz * toCell,       cells,       seed)        * vec3(1.0, toCell, toCell)
           + swellNoise(xz * toCell * 2.0, cells * 2.0, seed + 71.0) * vec3(0.5, toCell, toCell);
    return vec3(n.x - 0.75, n.yz) / 0.75;
}

vec2 swellWarp(vec2 xz, out mat2 J) {
    const float cells  = max(floor(SWELL_PERIOD / SWELL_WARP_SCALE), 1.0),
                toCell = cells / SWELL_PERIOD,
                s      = 2.0 * SWELL_WARP_AMP;
    vec2 x  = xz * toCell,
         i  = floor(x), f = x - i,
         u  = f * f * f * (f * (f * 6.0 - 15.0) + 10.0),
         du = 30.0 * f * f * (f * (f - 2.0) + 1.0),
         i0 = mod(i, cells), i1 = mod(i + 1.0, cells);
    vec2 a  = swellHash2(i0),
         b  = swellHash2(vec2(i1.x, i0.y)),
         c  = swellHash2(vec2(i0.x, i1.y)),
         d  = swellHash2(i1),
         k1 = b - a, k2 = c - a, k4 = a - b - c + d;
    J = mat2(1.0) + (s * toCell) * mat2(du.x * (k1 + k4 * u.y), du.y * (k2 + k4 * u.x));
    return xz + s * (a + k1 * u.x + k2 * u.y + k4 * u.x * u.y - 0.5);
}

float swellGust(vec2 xz, float t) {
    const vec2  wd    = vec2(sin(SWELL_WIND), cos(SWELL_WIND));
    const float cells = max(floor(SWELL_PERIOD / WAVE_PATCH_SIZE), 1.0);
    float gn = 2.0 * swellNoise((xz - wd * (t * SWELL_GUST_DRIFT)) * (cells / SWELL_PERIOD), cells, 113.0).x - 1.0;
    return mix(1.0, 2.0 * smoothstep(-0.55, 0.55, gn), WAVE_PATCHES);
}
float swellMacro(vec2 xz, float t) {
    vec2  u = vec2(dot(xz, SWELL_MW) - t * (SWELL_SLICK_DRIFT * SWELL_ML),
                   dot(xz, vec2(-SWELL_MW.y, SWELL_MW.x))) * (SWELL_MC / SWELL_PERIOD);
    float n = 0.65 * swellNoise(u, SWELL_MC, 211.0).x
            + 0.35 * swellNoise(u * 3.0 + vec2(0.37, 0.71), SWELL_MC * 3.0, 307.0).x,
          s = smoothstep(0.3, 0.7, n);
    return mix(1.0, mix(0.25, 1.3, s), WAVE_SLICKS);
}

// (010) Kernel
#if SWELL_KERNEL == 0
    const float SWELL_K_MEAN = 0.4658, SWELL_K_HRMS = 0.302, SWELL_K_DRMS = 0.328;
    vec3 swellKernel(float x) {
        float s = sin(x), c = cos(x), v = exp(s - 1.0);
        return vec3(v, v * c, v * (c * c - s));
    }
#else
    const float SWELL_K_MEAN = 0.5, SWELL_K_HRMS = 0.3536, SWELL_K_DRMS = 0.3536;
    vec3 swellKernel(float x) {
        float s = sin(x), c = cos(x);
        return vec3(0.5 + 0.5 * s, 0.5 * c, -0.5 * s);
    }
#endif

// (015) Component Table
const int   SWELL_N = 29, SWELL_NPACK = 11;
const int   SWELL_NV = min(WAVE_VERTEX_OCTAVES <= 6 ? 2 * WAVE_VERTEX_OCTAVES + 2 : WAVE_VERTEX_OCTAVES + 9, SWELL_N);
const float SWELL_OCT[SWELL_N] = float[](-6.0, -4.5, -3.0,
    0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5,
    6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0);

#define SWELL_RN(j, a)  fract(float(j) * (a) + 0.5)
#define SWELL_KLEN(j)   (SWELL_K0 * pow(SWELL_Q, SWELL_OCT[j]) * (0.95 + 0.1 * SWELL_RN(j, 0.7548777)))
#define SWELL_HW(j)     ((j) < 3 ? SWELL_SPREAD_SW : min(SWELL_SPREAD_LO * pow(SWELL_Q, 0.625 * max(SWELL_OCT[j], 0.0)), SWELL_SPREAD_HI))
#define SWELL_ANG(j)    (((j) < 3 ? SWELL_SW_DIR : SWELL_WIND) + (2.0 * SWELL_RN(j, 0.6180340) - 1.0) * SWELL_HW(j))
#define SWELL_KV_(j)    (floor(vec2(sin(SWELL_ANG(j)), cos(SWELL_ANG(j))) * (SWELL_KLEN(j) * SWELL_LAT) + 0.5) / SWELL_LAT)

const vec2 SWELL_KVEC[SWELL_N] = vec2[](
    SWELL_KV_(0),  SWELL_KV_(1),  SWELL_KV_(2),  SWELL_KV_(3),  SWELL_KV_(4),  SWELL_KV_(5),  SWELL_KV_(6),  SWELL_KV_(7),
    SWELL_KV_(8),  SWELL_KV_(9),  SWELL_KV_(10), SWELL_KV_(11), SWELL_KV_(12), SWELL_KV_(13), SWELL_KV_(14), SWELL_KV_(15),
    SWELL_KV_(16), SWELL_KV_(17), SWELL_KV_(18), SWELL_KV_(19), SWELL_KV_(20), SWELL_KV_(21), SWELL_KV_(22), SWELL_KV_(23),
    SWELL_KV_(24), SWELL_KV_(25), SWELL_KV_(26), SWELL_KV_(27), SWELL_KV_(28));

#define SWELL_FQ(j)     length(SWELL_KVEC[j])
#define SWELL_S_(j)     (((j) < 3 ? WAVE_SWELL * pow(SWELL_Q, SWELL_OCT[j]) : pow(SWELL_R, SWELL_OCT[j]) * ((j) < 15 ? 0.7071068 : 1.0)) / ((j) < SWELL_NPACK ? SWELL_GROUP_RMS : 1.0))
#define SWELL_KW_(j)    vec4(SWELL_KVEC[j], sqrt(SWELL_G * SWELL_FQ(j)) * WAVE_SPEED, SWELL_TAU * SWELL_RN(j, 0.5698403))
#define SWELL_PK_(j)    vec4(floor(vec2(SWELL_KVEC[j].y, -SWELL_KVEC[j].x) * (SWELL_PACKET_FREQ * SWELL_LAT) + 0.5) / SWELL_LAT, 2.3999632 * float(j), smoothstep(1.0, 5.5, SWELL_OCT[j]))
#define SWELL_FS_(j)    vec4(SWELL_FQ(j), 1.0 / SWELL_FQ(j), SWELL_S_(j), smoothstep(6.0, 9.0, SWELL_TAU / SWELL_FQ(j)))

const vec4 SWELL_KW[SWELL_N] = vec4[](
    SWELL_KW_(0),  SWELL_KW_(1),  SWELL_KW_(2),  SWELL_KW_(3),  SWELL_KW_(4),  SWELL_KW_(5),  SWELL_KW_(6),  SWELL_KW_(7),
    SWELL_KW_(8),  SWELL_KW_(9),  SWELL_KW_(10), SWELL_KW_(11), SWELL_KW_(12), SWELL_KW_(13), SWELL_KW_(14), SWELL_KW_(15),
    SWELL_KW_(16), SWELL_KW_(17), SWELL_KW_(18), SWELL_KW_(19), SWELL_KW_(20), SWELL_KW_(21), SWELL_KW_(22), SWELL_KW_(23),
    SWELL_KW_(24), SWELL_KW_(25), SWELL_KW_(26), SWELL_KW_(27), SWELL_KW_(28));
const vec4 SWELL_PK[SWELL_N] = vec4[](
    SWELL_PK_(0),  SWELL_PK_(1),  SWELL_PK_(2),  SWELL_PK_(3),  SWELL_PK_(4),  SWELL_PK_(5),  SWELL_PK_(6),  SWELL_PK_(7),
    SWELL_PK_(8),  SWELL_PK_(9),  SWELL_PK_(10), SWELL_PK_(11), SWELL_PK_(12), SWELL_PK_(13), SWELL_PK_(14), SWELL_PK_(15),
    SWELL_PK_(16), SWELL_PK_(17), SWELL_PK_(18), SWELL_PK_(19), SWELL_PK_(20), SWELL_PK_(21), SWELL_PK_(22), SWELL_PK_(23),
    SWELL_PK_(24), SWELL_PK_(25), SWELL_PK_(26), SWELL_PK_(27), SWELL_PK_(28));
const vec4 SWELL_FS[SWELL_N] = vec4[](
    SWELL_FS_(0),  SWELL_FS_(1),  SWELL_FS_(2),  SWELL_FS_(3),  SWELL_FS_(4),  SWELL_FS_(5),  SWELL_FS_(6),  SWELL_FS_(7),
    SWELL_FS_(8),  SWELL_FS_(9),  SWELL_FS_(10), SWELL_FS_(11), SWELL_FS_(12), SWELL_FS_(13), SWELL_FS_(14), SWELL_FS_(15),
    SWELL_FS_(16), SWELL_FS_(17), SWELL_FS_(18), SWELL_FS_(19), SWELL_FS_(20), SWELL_FS_(21), SWELL_FS_(22), SWELL_FS_(23),
    SWELL_FS_(24), SWELL_FS_(25), SWELL_FS_(26), SWELL_FS_(27), SWELL_FS_(28));

int swellCount(int octaves) {
    return clamp(octaves <= 6 ? 2 * octaves + 2 : octaves + 9, 4, SWELL_N);
}

vec2 swellNorm(int n, bool swell) {
    const float rq = SWELL_R / SWELL_Q;
    float W2 = swell ? WAVE_SWELL * WAVE_SWELL : 0.0,
          nd = clamp(float(n - 3), 0.0, 12.0),
          ns = max(float(n - 15), 0.0);
    return vec2(W2 * (pow(SWELL_Q, -12.0) + pow(SWELL_Q, -9.0) + pow(SWELL_Q, -6.0))
              + 0.5 * (1.0 - pow(SWELL_R, nd)) / (1.0 - SWELL_R)
              + pow(SWELL_R, 12.0) * (1.0 - pow(SWELL_R, 2.0 * ns)) / (1.0 - SWELL_R * SWELL_R),
                3.0 * W2
              + 0.5 * (1.0 - pow(rq, nd)) / (1.0 - rq)
              + pow(rq, 12.0) * (1.0 - pow(rq, 2.0 * ns)) / (1.0 - rq * rq));
}

// (019) Far Texture
float swellFixedVar(int n, bool swell) {
    float v = (swell && WAVE_SWELL > 0.0) ? WAVE_SWELL * WAVE_SWELL * (pow(SWELL_Q, -12.0) + pow(SWELL_Q, -9.0) + pow(SWELL_Q, -6.0)) : 0.0;
    for (int j = 3; j < SWELL_N; ++j) {
        if (j >= n || SWELL_FS[j].w <= 0.0) break;
        float s = SWELL_FS[j].z * SWELL_FS[j].w;
        v += s * s * (j < SWELL_NPACK ? SWELL_GROUP_RMS * SWELL_GROUP_RMS : 1.0);
    }
    return v;
}

#ifdef SWELL_FAR_TEX
vec3 swellTexLayer(vec2 pos, float t, float f, vec2 P, float T, float V, float mL, float mR) {
    float ft = f * (T * length(P) * 256.0),
          fL = 1.0 - smoothstep(3.0, 8.0, ft),
          fH = 1.0 - smoothstep(0.5, 1.5, ft);
    if (fL <= 0.0) return vec3(0.0);
    vec2  uv = fract(vec2(dot(pos, P), dot(pos, vec2(-P.y, P.x))) * T - vec2(fract(t * V), 0.0));
    vec4  s  = textureLod(SWELL_TEX, uv, 0.0) * 6.0 - 3.0;
    vec2  d  = s.xy * (0.8 * fL * mL) + s.zw * (0.6 * fH * mR);
    return vec3(vec2(d.x * P.x - d.y * P.y, d.x * P.y + d.y * P.x) / length(P),
                0.64 * fL * fL + 0.36 * fH * fH);
}
#endif

SwellSample swellCore(vec2 xz, float t, int n, float chop, vec2 vh, vec2 fp, bool vtx, bool swell) {
    // (021) Macro domain warp
    mat2 J   = mat2(1.0);
    vec2 pos = xz;
    if (SWELL_WARP_AMP > 0.0) pos = swellWarp(xz, J);
    mat2 Jw   = J;
    vec2 posW = pos;

    // (022) Gusts
    float gust  = (!vtx && WAVE_PATCHES > 0.0) ? swellGust(xz, t) : 1.0,
          slick = (WAVE_SLICKS > 0.0) ? swellMacro(xz, t) : 1.0,
          mL    = mix(1.0, slick, 0.4),
          mR    = slick * gust;

    // (024) LOD setup
    vec2  fp2   = fp * fp * (WAVE_LOD * WAVE_LOD / (SWELL_PI * SWELL_PI)),
          g     = vec2(0.0);
    float chopL = chop * (1.0 - smoothstep(0.1, 0.3, fp.x)),
          gr2   = SWELL_GROUP_RMS * SWELL_GROUP_RMS,
          h     = 0.0, kept = 0.0, b2 = 0.0;
    int   m     = vtx ? min(n, SWELL_NV) : n;
    bool  useSw = swell && WAVE_SWELL > 0.0;
#ifdef SWELL_FAR_TEX
    if (!vtx) { float b = smoothstep(0.04, 0.10, fp.x); b2 = b * b; }
#endif

    for (int j = 0; j < SWELL_N; ++j) {
        if (j >= m) break;
        if (j < 3 && !useSw) continue;
        vec4  A   = SWELL_KW[j], B = SWELL_PK[j], C = SWELL_FS[j];
        vec2  dir = A.xy * C.y;
        float w   = C.z;

        // (023) Vertex
        if (vtx) {
            if (C.w <= 0.0) break;
            w *= C.w;
        } else {
            if (j >= 3 && b2 > 0.0) {
                float pw2 = 1.0 - b2 * (1.0 - C.w * C.w);
                if (pw2 <= 0.0) break;
                w *= sqrt(pw2);
            }
            float k2 = C.x * C.x;
            if (k2 * fp2.x >= 0.5625) break;
            float c    = dot(dir, vh),
                  fade = 1.0 - smoothstep(0.09, 0.5625, k2 * mix(fp2.x, fp2.y, c * c));
            if (fade <= 0.0) continue;
            w    *= fade;
            kept += w * w * (j < SWELL_NPACK ? gr2 : 1.0);
        }

        float wm = w * (j < 3 ? 1.0 : mix(mL, mR, B.w)),
              a  = wm * C.y;

        // (025) Wave with deep-water dispersion
        float x  = dot(A.xy, pos) - t * A.z + A.w;
        vec3  K  = swellKernel(x);
        float Kc = K.x - SWELL_K_MEAN;

        // (026) Wave groups along the crest line, long waves only
        float gm   = 1.0, dm = 0.0;
        vec2  rowP = vec2(0.0);
        if (WAVE_GROUPS > 0.0 && j < SWELL_NPACK) {
            float e = dot(B.xy, pos) + B.z;
            gm   = 1.0 - WAVE_GROUPS * (0.5 - 0.5 * sin(e));
            dm   = 0.5 * WAVE_GROUPS * cos(e);
            rowP = B.xy * J;
        }

        vec2 row = dir * J;
        h += a * gm * Kc;
        g += row * (K.y * wm * gm) + rowP * (Kc * a * dm);

        // (027) Choppiness
        if (chopL > 0.0) {
            float warp = chopL * gm;
            pos += dir * (-K.y * a * warp);
            J   += (-K.z * wm * warp) * mat2(dir * row.x, dir * row.y);
        }
    }

    vec2 N = swellNorm(n, swell);
#ifdef SWELL_FAR_TEX
    // (029) Far wind sea
    if (b2 > 0.0) {
        float Tv = b2 * max(N.x - swellFixedVar(n, swell), 0.0),
              ft = mix(fp.x, fp.y, 0.5) * WAVE_LOD;
        vec3  l1 = swellTexLayer(posW, t, ft, SWELL_P1, SWELL_T1, SWELL_V1, mL, mR),
              l2 = swellTexLayer(posW, t, ft, SWELL_P2, SWELL_T2, SWELL_V2, mL, mR);
        g    += ((l1.xy + l2.xy) * Jw) * (sqrt(0.5 * Tv) * SWELL_K_DRMS);
        kept += 0.5 * Tv * (l1.z + l2.z);
    }
#endif

    // (028) Normalization
    SwellSample o;
    o.grad  = g * (WAVE_BUMPINESS / (sqrt(N.x) * SWELL_K_DRMS));
    o.h     = 0.5 + 0.25 * h * SWELL_K0 / (sqrt(N.y) * SWELL_K_HRMS);
    o.rough = WAVE_BUMPINESS * sqrt(max(1.0 - kept / N.x, 0.0)) * mR;
    return o;
}

SwellSample swellEval(vec2 xz, float t, int octaves, float chop, vec2 viewXZ, vec2 fp) {
    return swellCore(xz, t, swellCount(octaves), chop, viewXZ, fp, false, true);
}

// (030) Public API
float swellHeight(vec2 xz, float t) {
    return (swellCore(xz, t, swellCount(WAVE_DETAIL), WAVE_CHOPPINESS, vec2(1.0, 0.0), vec2(0.0), true, true).h - 0.5) * WAVE_HEIGHT;
}

SwellSample swellDetail(vec2 xz, float t, vec3 viewDirWS, float viewDist, float pixelAngle) {
    float f    = viewDist * pixelAngle,
          cosV = max(abs(viewDirWS.y), 0.01),
          l    = length(viewDirWS.xz);
    vec2  vh   = l > 1e-4 ? viewDirWS.xz / l : vec2(1.0, 0.0);
    return swellEval(xz, t, WAVE_DETAIL, WAVE_CHOPPINESS, vh, vec2(f, f / cosV));
}

// (035) Parallax
SwellSample swellDetailParallax(vec2 xz, float t, vec3 viewDirWS, float viewDist, float pixelAngle) {
    float f = viewDist * pixelAngle,
          k = WAVE_PARALLAX * WAVE_HEIGHT * (1.0 - smoothstep(32.0, 64.0, viewDist))
            / max(abs(viewDirWS.y), 0.15);
    vec2  p = xz;
    if (k > 0.5 * f) {
        float hp = clamp(swellField(xz, t, 4.0, 0.0).h - 0.5, -0.5, 0.5);
        p -= viewDirWS.xz * (k * hp);
    }
    return swellDetail(p, t, viewDirWS, viewDist, pixelAngle);
}

SwellSample swellField(vec2 xz, float t, float octaves, float drag) {
    return swellCore(xz, t, swellCount(int(octaves + 0.5)), drag, vec2(1.0, 0.0), vec2(0.0), false, false);
}

vec3 swellNormalWS(vec2 grad) { return normalize(vec3(-grad.x, 1.0, -grad.y)); }
vec3 swellNormalTS(vec2 grad) { return normalize(vec3(-grad, 1.0)); }

// (040) Shading Helpers
float swellFresnel(vec3 N, vec3 V, float f0) {
    float c = 1.0 - max(dot(N, V), 0.0), c2 = c * c;
    return f0 + (1.0 - f0) * c2 * c2 * c;
}

vec3 swellReflect(vec3 V, vec3 N, vec3 up) {
    vec3 R = reflect(-V, N);
    return R - 2.0 * up * min(dot(R, up), 0.0);
}

float swellSpecSun(vec3 R, vec3 L, float sharp, float strength) {
    return pow(max(dot(R, L), 0.0), sharp) * strength;
}

float swellSpecGGX(vec3 N, vec3 V, vec3 L, float rough) {
    vec3  H  = normalize(V + L);
    float a2 = pow(rough, 4.0);
    float d  = max(dot(N, H), 0.0); d = d * d * (a2 - 1.0) + 1.0;
    return a2 / (SWELL_PI * d * d) * max(dot(N, L), 0.0);
}

vec3 swellScatter(vec3 col, float h01, float k) {
    return col * k * (0.2 + clamp(h01, 0.0, 1.0));
}

float swellCaustic(vec3 posRel, vec3 L, float t) {
    vec3 rL = refract(-L, vec3(0.0, 1.0, 0.0), 0.75);
    vec2 p  = (posRel - rL * posRel.y / rL.y).xz;
    return smoothstep(0.55, 0.95, swellCore(p, t, swellCount(8), 0.9, vec2(1.0, 0.0), vec2(0.0), false, false).h);
}

// (050) Compat
#ifdef SWELL_COMPAT
float waves1(vec2 p, float t) { return clamp(swellField(p, t, 10.0, 0.0).h, 0.0, 1.0); }
float waves2(vec2 p, float t) { return smoothstep(0.55, 0.95, swellField(p, t, 8.0, 0.9).h); }
vec3  calcWaterNormal(vec2 p, float t, float d) { return swellNormalTS(swellDetailParallax(p, t, d).grad); }
float calcCaustic(vec3 pos, vec3 L, float t) { return swellCaustic(pos, L, t); }
#endif

#endif