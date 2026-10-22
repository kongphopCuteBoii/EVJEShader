#ifndef MATH_UTILS_GLSL
#define MATH_UTILS_GLSL

#ifndef saturate
    #define saturate(x) clamp(x, 0.0, 1.0)
#endif

// (001) sRGB-ish Curve -> Linear
vec3 pow_linear(vec3 x) {
    vec3 xSqrt025  = sqrt(sqrt(x)),
         xSqrt0125 = sqrt(xSqrt025);
    return mix(xSqrt0125, xSqrt025, 0.6) * (x * x);
}

// (002) Interleaved Gradient Noise
float getIGN(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
}

#endif
