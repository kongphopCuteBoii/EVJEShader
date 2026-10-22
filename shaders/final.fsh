#version 460 compatibility

#include "/libs/mathUtils.glsl"
#include "/libs/coreFunctions/bloomKawase.glsl"

uniform sampler2D colortex0, colortex7, colortex11;
uniform float viewWidth, viewHeight;
uniform int   isEyeInWater;
in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

// (200) Color-related Utilities
// (201) Luma Coefficient
const vec3 LUMA_COEFF = vec3(0.2126, 0.7152, 0.0722);

// (202) Uchimura Tonemapper
vec3 uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = vec3(1.0 - smoothstep(0.0, m, x));
    vec3 w2 = vec3(step(m + l0, x));
    vec3 w1 = vec3(1.0 - w0 - w2);

    vec3 T = vec3(m * pow(x / m, vec3(c)) + b);
    vec3 S = vec3(P - (P - S1) * exp(CP * (x - S0)));
    vec3 L = vec3(m + a * (x - m));

    return T * w0 + L * w1 + S * w2;
}

// (203) Uchimura Tonemapper
vec3 uchimura(vec3 x) {
    const float P = 1.0;
    const float a = 1.0;
    const float m = 0.22;
    const float l = 0.4;
    const float c = 1.33;
    const float b = 0.0;

    return uchimura(x, P, a, m, l, c, b);
}

#define AGX_SHADOW_LIFT 0.001 

vec3 agxDefaultContrastApprox(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    
    vec3 val = + 15.5 * x4 * x2
               - 40.14 * x4 * x
               + 31.96 * x4
               - 6.868 * x2 * x
               + 0.4298 * x2
               + 0.1191 * x;

    return max(val, 0.0);
}

vec3 agx(vec3 color) {
    const mat3 agx_mat = mat3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335996993436, 0.878468636469772,  0.0784336121205899,
        0.0792237451477422, 0.0791661274605434, 0.879142973414007
    );

    const mat3 agx_mat_inv = mat3(
        1.19687900512017, -0.0528968517579562, -0.0529716355084725,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.099029747070195, -0.0989611768137352, 1.15107367264188
    );

    color = max(color + vec3(AGX_SHADOW_LIFT), 0.0);

    color = agx_mat * color;

    const float min_ev = -12.47393;
    const float max_ev = 4.026069;

    color = clamp(log2(max(color, 1e-6)), min_ev, max_ev);
    color = (color - min_ev) / (max_ev - min_ev);

    color = agxDefaultContrastApprox(color);

    color = max(agx_mat_inv * color, 0.0);

    return color;
}

vec3 crystalineCG(vec3 color) {
    vec3 cC = color;
    cC.rg = mix(vec2(dot(cC.rg, LUMA_COEFF.rg)), cC.rg, 0.9) * 0.9;
    return pow(cC, vec3(0.6)) - 0.15;
}

void main() {
    vec3 color = texture(colortex0, texCoord).rgb;

    float smoothedLuma = texelFetch(colortex11, ivec2(0), 0).r;
    
    float exposure = exposureFromLuma(smoothedLuma);

    float bloomK = BLOOM_STRENGTH * clamp(pow(exposure / BLOOM_GLARE_REF, BLOOM_GLARE_POWER), 1.0 / BLOOM_GLARE_MAX, BLOOM_GLARE_MAX)
                 * ((isEyeInWater == 1) ? BLOOM_UNDERWATER : 1.0);
    color = mix(color, bloomBilinear(colortex7, texCoord).rgb, saturate(bloomK));

    color *= exposure;
    color = mix(vec3(dot(color, LUMA_COEFF)), color, 0.95);

    color = agx(color);

    float dither = (getIGN(gl_FragCoord.xy) - 0.5) / 255.0;
    color += dither;
    color = crystalineCG(color);
    fragColor = vec4(color, 1.0);
}