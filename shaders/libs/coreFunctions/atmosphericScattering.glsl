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

const float SUN_SIZE      = 7.0;
const float SUN_R         = 0.004652332871 * SUN_SIZE;
#ifndef SUN_DISC_GAIN
    #define SUN_DISC_GAIN 2.0
#endif
#ifndef SUN_HALO_GAIN
    #define SUN_HALO_GAIN 1.0
#endif
const float SUN_RADIANCE  = 150.0 * SUN_DISC_GAIN;
const vec3  SUN_LIMB_U    = vec3(0.50, 0.62, 0.80);
const float SUN_FLATTEN   = 0.14;
#ifndef SUN_LUMA_COMPRESS
    #define SUN_LUMA_COMPRESS 0.35
#endif
#ifndef SUN_HALO_FLATTEN
    #define SUN_HALO_FLATTEN 1.5
#endif
#ifndef SUNSET_GLOW
    #define SUNSET_GLOW 1.0
#endif
// Sun = a big, extremely hot disc (saturates to white after tonemap) + halo lobes that MODULATE the sky itself,
// so glow and sky share one hue instead of a separate additive blob. All smooth in (1 - cos): no seam anywhere.
const float HALO_TIGHT = 2.0,  HALO_TIGHT_K = 600.0;   // hot white shoulder around the disc (adds sun hue)
const float HALO_MID   = 2.5,  HALO_MID_K   = 60.0;    // sky-tinted brightening (multiplies atlas sky)
const float HALO_WIDE  = 0.9,  HALO_WIDE_K  = 7.0;     // horizon-tinted warm bloom (adds horizonC)

// x: tight lobe, y: mid lobe, z: wide lobe  (vertical offsets count more at low sun -> horizontal stretch)
vec3 sunLobes(vec3 v, vec3 ld) {
    vec3  d  = v - ld;
    float d2 = dot(d, d);
    float flatten = 1.0 + SUN_HALO_FLATTEN * (1.0 - smoothstep(0.0, 0.35, ld.y)),
          dg2     = d2 + (flatten * flatten - 1.0) * d.y * d.y;
    return exp2(-vec3(HALO_TIGHT_K * d2, HALO_MID_K * dg2, HALO_WIDE_K * dg2) * 0.5);
}

vec3 sunLight(vec3 v, vec3 ld, vec3 sunC, float px) {
    // Hue only from the table; brightness is a fixed huge radiance like a real overexposed sun
    float sunMax = max(max(sunC.r, sunC.g), sunC.b);
    vec3  hue    = sunC / max(sunMax, 1e-4);
    float lum    = pow(sunMax, SUN_LUMA_COMPRESS);

    vec3  d  = v - ld;
    float d2 = dot(d, d);
    float vy = d.y * inversesqrt(max(1.0 - ld.y * ld.y, 0.0025));
    float hz = max(d2 - d.y * d.y, 0.0);
    float sq = 1.0 + SUN_FLATTEN * (1.0 - smoothstep(0.0, 0.25, ld.y));
    float r  = sqrt(hz + vy * vy * sq * sq) / SUN_R;

    float mu   = sqrt(1.0 - min(r * r, 1.0));
    vec3  limb = (1.0 - SUN_LIMB_U * (1.0 - mu)) / (1.0 - SUN_LIMB_U / 3.0);
    float pr   = px / SUN_R;
    float edge = 1.0 - smoothstep(1.0 - max(pr, 0.15), 1.0 + max(pr, 0.15), r);

    vec3 discC = mix(hue, vec3(1.0), 0.6) * lum;
    return discC * (SUN_RADIANCE * limb * edge);
}

#include "skyEssentials.glsl"

// Sunset horizon glow: the table's horizon colour, concentrated toward the sun's azimuth and hugging the horizon
vec3 sunsetGlow(vec3 v, vec3 ld, vec3 horC) {
    float lowSun = (1.0 - smoothstep(0.05, 0.5, ld.y)) * smoothstep(-0.15, 0.0, ld.y),
          hv     = dot(v.xz, v.xz),
          hl     = dot(ld.xz, ld.xz),
          cosAz  = (hv > 1e-6 && hl > 1e-6) ? dot(v.xz, ld.xz) * inversesqrt(hv * hl) : 0.0,
          az     = max(cosAz, 0.0);
    return horC * (SUNSET_GLOW * lowSun * az * az * exp2(-4.0 * max(v.y, 0.0)));
}

vec3 underSky(vec3 v, vec3 skyC, vec3 horC) {
    float ny = max(-v.y, 0.0);
    vec3 voidColor = skyC * mix(0.7, 0.5, ny);
    return mix(horC * skyC.b * 20.0, voidColor, clamp(pow(ny, 0.04), 0.0, 1.0));
}

// Sky radiance without the sun disc (atlas sky + halo lobes + sunset glow). Clouds use this as their aerial-perspective colour,
// so a distant cloud converges to exactly the sky colour behind it.
vec3 skyBody(vec3 v, vec4 a, vec3 ld, vec3 sunC, vec3 horC) {
    vec3 vs = v.y > 0.0 ? v : (dot(v.xz, v.xz) > 1e-8 ? normalize(vec3(v.x, 0.0, v.z)) : vec3(1.0, 0.0, 0.0));
    vec3  sky   = atlasRadiance(vs, a);
    vec3  lobes = sunLobes(v, ld);
    float sMax  = max(max(sunC.r, sunC.g), sunC.b);
    vec3  sHue  = sunC / max(sMax, 1e-4);
    float lum   = pow(sMax, SUN_LUMA_COMPRESS) * SUN_HALO_GAIN;
    sky *= 1.0 + HALO_MID * lobes.y * lum;
    sky += sHue * (HALO_TIGHT * lobes.x * lum * 5.0) + horC * (HALO_WIDE * lobes.z * lum) + sunsetGlow(v, ld, horC);
    return sky;
}

vec3 skyHDR(vec3 rd, vec4 a, vec3 ld, vec3 sunC, vec3 skyC, vec3 horC, float w, float px) {
    vec3 v = normalize(rd);
    w = max(w, 1e-5);
    float s = smoothstep(-w, w, v.y);
    vec3 sky = vec3(0.0), under = vec3(0.0);
    if (s > 0.0) sky = skyBody(v, a, ld, sunC, horC) + sunLight(v, ld, sunC, px);
    if (s < 1.0) under = underSky(v, skyC, horC);
    return mix(under, sky, s);
}
