#ifndef BLOOM_KAWASE_GLSL
#define BLOOM_KAWASE_GLSL

#include "/libs/exposure.h"

// (001) Tunables
#define BLOOM_STRENGTH        0.065
#define BLOOM_SPREAD          0.58
#define BLOOM_CLAMP           24.0
#define BLOOM_HIGHLIGHT       1.4
#define BLOOM_HIGHLIGHT_START 0.9
#define BLOOM_HIGHLIGHT_RANGE 5.0
#define BLOOM_GLARE_REF       0.40
#define BLOOM_GLARE_POWER     0.30
#define BLOOM_GLARE_MAX       2.0
#define BLOOM_UNDERWATER      1.7
#define BLOOM_MANUAL_BILINEAR 0

// (002) Bilinear Fetch
vec4 bloomBilinear(sampler2D tex, vec2 uv) {
    ivec2 size = textureSize(tex, 0);
    vec2  p    = uv * vec2(size) - 0.5,
          f    = fract(p);
    ivec2 i    = ivec2(floor(p)),
          hi   = size - 1;
    vec4  a = texelFetch(tex, clamp(i,               ivec2(0), hi), 0),
          b = texelFetch(tex, clamp(i + ivec2(1, 0), ivec2(0), hi), 0),
          c = texelFetch(tex, clamp(i + ivec2(0, 1), ivec2(0), hi), 0),
          d = texelFetch(tex, clamp(i + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 bloomTap(sampler2D tex, vec2 uv, bool manual) {
    #if BLOOM_MANUAL_BILINEAR
        return bloomBilinear(tex, uv).rgb;
    #else
        return manual ? bloomBilinear(tex, uv).rgb : textureLod(tex, uv, 0.0).rgb;
    #endif
}

// (003) Downsample
vec3 kawaseDown(sampler2D tex, vec2 uv, bool manual) {
    vec2 t = 1.0 / vec2(textureSize(tex, 0));
    return (bloomTap(tex, uv, manual) * 4.0
          + bloomTap(tex, uv + t * vec2(-1.0, -1.0), manual)
          + bloomTap(tex, uv + t * vec2( 1.0, -1.0), manual)
          + bloomTap(tex, uv + t * vec2(-1.0,  1.0), manual)
          + bloomTap(tex, uv + t * vec2( 1.0,  1.0), manual)) * 0.125;
}

// (004) Upsample
vec3 kawaseUp(sampler2D tex, vec2 uv, bool manual) {
    vec2 t = 1.0 / vec2(textureSize(tex, 0));
    return (bloomTap(tex, uv + vec2(-t.x, 0.0), manual)
          + bloomTap(tex, uv + vec2( t.x, 0.0), manual)
          + bloomTap(tex, uv + vec2(0.0, -t.y), manual)
          + bloomTap(tex, uv + vec2(0.0,  t.y), manual)
          + (bloomTap(tex, uv + t * vec2(-0.5, -0.5), manual)
           + bloomTap(tex, uv + t * vec2( 0.5, -0.5), manual)
           + bloomTap(tex, uv + t * vec2(-0.5,  0.5), manual)
           + bloomTap(tex, uv + t * vec2( 0.5,  0.5), manual)) * 2.0) * (1.0 / 12.0);
}

// (005) Prefilter Tap
vec3 bloomPrefilter(vec3 c, float exposure) {
    float lumaE = dot(c, vec3(0.2126, 0.7152, 0.0722)) * exposure;
    c *= min(1.0, BLOOM_CLAMP / max(lumaE, 1e-4));
    return c * (1.0 + BLOOM_HIGHLIGHT * smoothstep(BLOOM_HIGHLIGHT_START, BLOOM_HIGHLIGHT_START + BLOOM_HIGHLIGHT_RANGE, lumaE));
}

vec3 kawaseDownPrefilter(sampler2D tex, vec2 uv, float exposure) {
    vec2 t = 1.0 / vec2(textureSize(tex, 0));
    return (bloomPrefilter(textureLod(tex, uv, 0.0).rgb, exposure) * 4.0
          + bloomPrefilter(textureLod(tex, uv + t * vec2(-1.0, -1.0), 0.0).rgb, exposure)
          + bloomPrefilter(textureLod(tex, uv + t * vec2( 1.0, -1.0), 0.0).rgb, exposure)
          + bloomPrefilter(textureLod(tex, uv + t * vec2(-1.0,  1.0), 0.0).rgb, exposure)
          + bloomPrefilter(textureLod(tex, uv + t * vec2( 1.0,  1.0), 0.0).rgb, exposure)) * 0.125;
}

#endif
