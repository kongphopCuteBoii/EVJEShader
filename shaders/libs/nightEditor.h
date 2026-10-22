#ifndef NIGHT_EDITOR_H
#define NIGHT_EDITOR_H

// (001) Moon Light (direct)
#define NIGHT_MOON_ILLUMINANCE   vec3(0.62, 0.74, 1.00) * 0.022
#define NIGHT_MOON_DISC_COLOR    vec3(0.78, 0.84, 1.00)
#define NIGHT_MOON_SPECULAR      vec3(1.0)
#define NIGHT_MOON_HORIZON_TINT  vec3(1.00, 0.72, 0.52)
#define NIGHT_MOON_RISE_START    0.0
#define NIGHT_MOON_RISE_END      0.14
#define NIGHT_MOON_MIN_PHASE     0.10

// (002) Night Ambient & Sky Children
#define NIGHT_AMBIENT_FLOOR      vec3(0.0022, 0.0032, 0.0055)
#define NIGHT_AMBIENT_MOON       vec3(0.0070, 0.0100, 0.0170)
#define NIGHT_SKY_ZENITH_FLOOR   vec3(0.00018, 0.00030, 0.00065)
#define NIGHT_SKY_ZENITH_MOON    vec3(0.00080, 0.00130, 0.00260)
#define NIGHT_SKY_HORIZON_FLOOR  vec3(0.00040, 0.00060, 0.00110)
#define NIGHT_SKY_HORIZON_MOON   vec3(0.00150, 0.00230, 0.00400)
#define NIGHT_FOG_FLOOR          vec3(1.0e-7, 1.6e-7, 3.0e-7)
#define NIGHT_FOG_MOON           vec3(4.0e-7, 6.0e-7, 1.1e-6)

// (003) Night Weight
#define NIGHT_WEIGHT_FROM        0.00
#define NIGHT_WEIGHT_TO         -0.20

// (004) Night Sky Pass
#define NIGHT_STARS              1
#define NIGHT_STAR_DENSITY       70.0
#define NIGHT_STAR_FRACTION      0.12
#define NIGHT_STAR_BRIGHTNESS    0.55
#define NIGHT_STAR_TWINKLE       0.25
#define NIGHT_MOON_DISC          1
#define NIGHT_MOON_RADIUS        0.0105
#define NIGHT_MOON_RADIANCE      2.2
#define NIGHT_MOON_EARTHSHINE    0.025
#define NIGHT_MOON_HALO          0.012
#define NIGHT_AIRGLOW_ZENITH     vec3(0.00022, 0.00040, 0.00085)
#define NIGHT_AIRGLOW_HORIZON    vec3(0.00060, 0.00090, 0.00160)

// (005) Physical Gates
#define NIGHT_RSM_GI             0
#define NIGHT_MOON_GLINT         1
#define NIGHT_MOON_CLOUDS        1
#define NIGHT_MOON_FOG_SHAFTS    1
#define NIGHT_WARM_HAZE          0

// (010) Night Weight
float nightWeightFromSun(float sunY) {
    return 1.0 - smoothstep(NIGHT_WEIGHT_TO, NIGHT_WEIGHT_FROM, sunY);
}

// (011) Moon Illumination
float moonIlluminationFromPhase(int phase) {
    return mix(NIGHT_MOON_MIN_PHASE, 1.0, 0.5 + 0.5 * cos(float(phase) * 0.7853982));
}

// (012) Key Light
void getKeyLight(vec3 sunDirW, vec3 shadowDirW, vec3 sunlightC, vec3 sunC, int phase,
                 out vec3 keyDir, out vec3 keyC, out vec3 keyDiscC, out vec3 keySpecC, out vec4 nightP) {
    float nightW   = nightWeightFromSun(sunDirW.y),
          moonIll  = moonIlluminationFromPhase(phase),
          moonY    = -sunDirW.y,
          moonVis  = smoothstep(NIGHT_MOON_RISE_START, NIGHT_MOON_RISE_END, moonY) * moonIll,
          phaseAng = float(phase) * 0.7853982;
    bool  shadowIsSun = dot(shadowDirW, sunDirW) > 0.0;

    vec3 moonLow = mix(NIGHT_MOON_HORIZON_TINT, vec3(1.0), smoothstep(0.0, 0.35, moonY)),
         moonC   = NIGHT_MOON_ILLUMINANCE * moonLow * moonVis;

    keyDir   = shadowDirW;
    keyC     = shadowIsSun ? sunlightC : moonC;
    keyDiscC = shadowIsSun ? sunC      : moonC;
    keySpecC = shadowIsSun ? sunC      : NIGHT_MOON_SPECULAR;
    nightP   = vec4(nightW, moonIll, cos(phaseAng), sin(phaseAng));
}

// (013) Night Sky Children
void applyNightChildren(vec4 nightP, inout vec3 ambientC, inout vec3 skyC, inout vec3 horizonC, inout vec3 fogC) {
    float w = nightP.x, m = nightP.y;
    ambientC += w * (NIGHT_AMBIENT_FLOOR     + NIGHT_AMBIENT_MOON     * m);
    skyC     += w * (NIGHT_SKY_ZENITH_FLOOR  + NIGHT_SKY_ZENITH_MOON  * m);
    horizonC += w * (NIGHT_SKY_HORIZON_FLOOR + NIGHT_SKY_HORIZON_MOON * m);
    fogC     += w * (NIGHT_FOG_FLOOR         + NIGHT_FOG_MOON         * m);
}

// (020) Stars
vec4 nightHash4(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.xxyz + p.yzzx) * p.zyxx);
}

vec3 nightStars(vec3 v, float px, float time) {
    #if NIGHT_STARS
        vec3  a    = abs(v);
        vec2  uv;
        float face;
        if (a.x >= a.y && a.x >= a.z)  { uv = v.yz / a.x; face = v.x > 0.0 ? 0.0 : 1.0; }
        else if (a.y >= a.z)           { uv = v.xz / a.y; face = v.y > 0.0 ? 2.0 : 3.0; }
        else                           { uv = v.xy / a.z; face = v.z > 0.0 ? 4.0 : 5.0; }

        vec2  g    = uv * NIGHT_STAR_DENSITY,
              cell = floor(g);
        vec4  h    = nightHash4(vec3(cell, face));
        if (h.x > NIGHT_STAR_FRACTION) return vec3(0.0);

        vec2  centre = (h.yz - 0.5) * 0.7,
              d      = fract(g) - 0.5 - centre;
        float radius = max(px * NIGHT_STAR_DENSITY * 1.1, 0.03),
              mag    = h.w * h.w * h.w,
              spark  = smoothstep(radius, 0.0, length(d)) * min(1.0, 0.06 / radius),
              twink  = 1.0 + NIGHT_STAR_TWINKLE * sin(time * (2.0 + 4.0 * h.y) + h.z * 40.0);
        vec3  tint   = mix(vec3(1.0, 0.80, 0.62), vec3(0.70, 0.82, 1.0), h.y);
        return tint * (spark * mag * twink * NIGHT_STAR_BRIGHTNESS);
    #else
        return vec3(0.0);
    #endif
}

// (021) Moon Disc
vec3 nightMoon(vec3 v, vec3 md, vec4 nightP, float px) {
    #if NIGHT_MOON_DISC
        float cosToMoon = dot(v, md);
        if (cosToMoon < 0.98) return vec3(0.0);

        vec3 e1 = normalize(cross(md, vec3(0.0, 1.0, 0.0)) + vec3(1e-5, 0.0, 0.0)),
             e2 = cross(e1, md),
             d  = v - md;
        vec2  p  = vec2(dot(d, e1), dot(d, e2)) / NIGHT_MOON_RADIUS;
        float rr = length(p);

        float ang  = sqrt(max(2.0 - 2.0 * cosToMoon, 0.0)),
              halo = NIGHT_MOON_HALO / (1.0 + (ang * ang) / (0.045 * 0.045));
        vec3  col  = NIGHT_MOON_DISC_COLOR * (halo * nightP.y);

        float pr   = px / NIGHT_MOON_RADIUS,
              edge = 1.0 - smoothstep(1.0 - pr, 1.0 + pr, rr);
        if (edge > 0.0) {
            float z    = sqrt(max(1.0 - rr * rr, 0.0));
            vec3  n    = e1 * p.x + e2 * p.y - md * z,
                  L    = -md * nightP.z + e1 * nightP.w;
            float lit  = smoothstep(-0.04, 0.12, dot(n, L)),
                  mare = 0.62 + 0.38 * smoothstep(-0.3, 0.5, sin(p.x * 3.1 + 1.3) * sin(p.y * 2.7 - 0.4) + 0.35 * sin(dot(p, vec2(5.3, 4.1))));
            col += NIGHT_MOON_DISC_COLOR * (NIGHT_MOON_RADIANCE * mare * mix(NIGHT_MOON_EARTHSHINE, 1.0, lit) * edge);
        }
        return col;
    #else
        return vec3(0.0);
    #endif
}

// (022) Night Sky
vec3 nightSky(vec3 v, vec3 sunDirW, vec4 nightP, float px, float time, float moonScale) {
    float w = nightP.x;
    if (w <= 0.0) return vec3(0.0);

    float up    = max(v.y, 0.0),
          horizonFade = smoothstep(0.0, 0.18, v.y);
    vec3  glow  = mix(NIGHT_AIRGLOW_HORIZON, NIGHT_AIRGLOW_ZENITH, sqrt(up));
    vec3  stars = nightStars(v, px, time) * horizonFade * (1.0 - 0.85 * nightP.y * 0.5);
    vec3  moon  = (moonScale > 0.0) ? nightMoon(v, -sunDirW, nightP, px) * moonScale : vec3(0.0);
    return (glow * (0.6 + 0.4 * nightP.y) + stars + moon) * w;
}

#endif
