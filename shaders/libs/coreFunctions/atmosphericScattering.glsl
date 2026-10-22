uniform sampler2D skyAtlas;

const float ATLAS_LO     = -20.0;
const float ATLAS_RANGE  = 18.0;
const float ATLAS_W      = 50.0;
const float ATLAS_H      = 3424.0;
const vec3  SPECTRAL_GAIN = vec3(1.09982729, 1.01947006, 0.82653544);
const float SUN_DISC_RADIUS   = 0.004652332871;
const float SUN_DISC_RADIANCE = 24.0;
const float VIEW_MIN_RAD      = -0.02617993878;
const float INV_VIEW_STEP_RAD = 19.41138;

vec4 atlasParams(vec3 ld, float sunElevDeg) {
    float ps = clamp(sunElevDeg + 16.0, 0.0, 106.0);
    float s0 = min(floor(ps), 105.0);
    float ch = length(ld.xz);
    return vec4(s0 * 32.0 + 0.5, ps - s0,
                ch > 1e-4 ? ld.z / ch : 1.0,
                ch > 1e-4 ? ld.x / ch : 0.0);
}

float fastAsinPos(float x) {
    return 1.5707963 - sqrt(1.0 - x) * (1.5707288 + x * (-0.2121144 + x * (0.0742610 - 0.0187293 * x)));
}
float fastAtan2(float y, float x) {
    float ax = abs(x), ay = abs(y);
    float a = min(ax, ay) / max(ax, ay);
    float s = a * a;
    float r = ((-0.0464964749 * s + 0.15931422) * s - 0.327622764) * s * a + a;
    if (ay > ax) r = 1.57079637 - r;
    if (x < 0.0) r = 3.14159274 - r;
    return y < 0.0 ? -r : r;
}

vec3 atlasRadiance(vec3 v, vec4 a) {
    float pv = clamp((fastAsinPos(min(v.y, 1.0)) - VIEW_MIN_RAD) * INV_VIEW_STEP_RAD, 0.0, 31.0);
    float rx = v.x * a.z - v.z * a.w;
    float rz = v.x * a.w + v.z * a.z;
    rx += (rx >= 0.0 ? 1e-7 : -1e-7);
    float t = fract(fastAtan2(rz, rx) * 0.15915494) * 48.0;
    float u = (t + 1.0) * (1.0 / ATLAS_W);
    float y0 = (a.x + pv) * (1.0 / ATLAS_H);
    vec3 q = mix(textureLod(skyAtlas, vec2(u, y0), 0.0).rgb,
                 textureLod(skyAtlas, vec2(u, y0 + 32.0 / ATLAS_H), 0.0).rgb, a.y);
    return exp2(q * ATLAS_RANGE + ATLAS_LO) * SPECTRAL_GAIN;
}

const float SUN_SIZE      = 1.5;
const float SUN_R         = 0.004652332871 * SUN_SIZE;
const float SUN_RADIANCE  = 24.0;
const vec3  SUN_LIMB_U    = vec3(0.50, 0.62, 0.80);
const float SUN_FLATTEN   = 0.14;
const float AUR_TIGHT     = 1.2,  AUR_TIGHT_W = 0.020;
const float AUR_WIDE      = 0.02, AUR_WIDE_W  = 0.180;

vec3 sunLight(vec3 v, vec3 ld, vec3 sunC, float px) {
    vec3  d  = v - ld;
    float d2 = dot(d, d);

    float gt = 1.0 + d2 / (AUR_TIGHT_W * AUR_TIGHT_W),
          gw = 1.0 + d2 / (AUR_WIDE_W  * AUR_WIDE_W);
    vec3 glow = sunC * (AUR_TIGHT * inversesqrt(gt * gt * gt) + AUR_WIDE * inversesqrt(gw * gw * gw));

    float vy = d.y * inversesqrt(max(1.0 - ld.y * ld.y, 0.0025));
    float hz = max(d2 - d.y * d.y, 0.0);
    float sq = 1.0 + SUN_FLATTEN * (1.0 - smoothstep(0.0, 0.25, ld.y));
    float r  = sqrt(hz + vy * vy * sq * sq) / SUN_R;

    float mu   = sqrt(1.0 - min(r * r, 1.0));
    vec3  limb = (1.0 - SUN_LIMB_U * (1.0 - mu)) / (1.0 - SUN_LIMB_U / 3.0);
    float pr   = px / SUN_R;
    float edge = 1.0 - smoothstep(1.0 - pr, 1.0 + pr, r);

    return sunC * SUN_RADIANCE * limb * edge + glow;
}

#include "skyEssentials.glsl"

vec3 underSky(vec3 v, vec3 skyC, vec3 horC) {
    float ny = max(-v.y, 0.0);
    vec3 voidColor = skyC * mix(0.7, 0.5, ny);
    return mix(horC * skyC.b * 20.0, voidColor, clamp(pow(ny, 0.04), 0.0, 1.0));
}

vec3 skyHDR(vec3 rd, vec4 a, vec3 ld, vec3 sunC, vec3 skyC, vec3 horC, float w, float px) {
    vec3 v = normalize(rd);
    w = max(w, 1e-5);
    float s = smoothstep(-w, w, v.y);
    vec3 sky = vec3(0.0), under = vec3(0.0);
    if (s > 0.0) {
        vec3 vs = v.y > 0.0 ? v : (dot(v.xz, v.xz) > 1e-8 ? normalize(vec3(v.x, 0.0, v.z)) : vec3(1.0, 0.0, 0.0));
        sky = atlasRadiance(vs, a);
        if (dot(v, ld) > 0.0) sky += sunLight(v, ld, sunC, px) * 5.0;
    }
    if (s < 1.0) under = underSky(v, skyC, horC);
    return mix(under, sky, s);
}