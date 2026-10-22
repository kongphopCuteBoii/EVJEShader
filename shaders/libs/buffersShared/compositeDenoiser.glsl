uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform float viewHeight;

#define TAPS 8
#define SIGMA_Z 0.08

vec3 decodeN(vec3 raw){ return raw * 2.0 - 1.0; }
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 vpos(vec2 uv, float z){
    return vec3((uv * 2.0 - 1.0) * vec2(gbufferProjectionInverse[0][0],
                                        gbufferProjectionInverse[1][1]) * z, -z);
}

vec4 denoise(float worldRadius, float rotation, float sigmaL, bool useStats){
    ivec2 p  = ivec2(gl_FragCoord.xy);
    ivec2 hs = textureSize(colortex7, 0);
    ivec2 hm = hs - 1;
    vec2  invHs = 1.0 / vec2(hs);

    vec4 c0 = texelFetch(colortex5, p, 0);
    vec4 g0 = texelFetch(colortex7, p, 0);
    if(g0.a <= 0.0) return c0;

    vec3 n0w = decodeN(g0.rgb), n0v = normalize(mat3(gbufferModelView) * n0w);
    vec3 p0  = vpos((vec2(p) + 0.5) * invHs, g0.a);

    float ref = luma(c0.rgb), sd = 0.0;
    if(useStats){
        float l1 = luma(texelFetch(colortex5, clamp(p + ivec2( 1, 0), ivec2(0), hm), 0).rgb);
        float l2 = luma(texelFetch(colortex5, clamp(p + ivec2(-1, 0), ivec2(0), hm), 0).rgb);
        float l3 = luma(texelFetch(colortex5, clamp(p + ivec2( 0, 1), ivec2(0), hm), 0).rgb);
        float l4 = luma(texelFetch(colortex5, clamp(p + ivec2( 0,-1), ivec2(0), hm), 0).rgb);
        float m1 = (ref + l1 + l2 + l3 + l4) * 0.2;
        float m2 = (ref*ref + l1*l1 + l2*l2 + l3*l3 + l4*l4) * 0.2;
        ref = m1;
        sd  = sqrt(max(m2 - m1*m1, 0.0));
    }

    float rPx = clamp(worldRadius / g0.a * viewHeight * 0.25 * gbufferProjection[1][1], 1.5, 12.0);

    vec4 sum = c0; float wsum = 1.0;
    for(int i = 0; i < TAPS; i++){
        float r = sqrt((float(i) + 0.5) / float(TAPS));
        float a = float(i) * 2.399963 + rotation;
        ivec2 tp = clamp(p + ivec2(round(vec2(cos(a), sin(a)) * r * rPx)), ivec2(0), hm);

        vec4 g = texelFetch(colortex7, tp, 0);
        if(g.a <= 0.0) continue;

        float wz = exp(-abs(dot(n0v, vpos((vec2(tp) + 0.5) * invHs, g.a) - p0)) / (SIGMA_Z * g.a));
        float wn = max(dot(n0w, decodeN(g.rgb)), 0.0);
        wn *= wn; wn *= wn; wn *= wn; wn *= wn;
        if(wz * wn < 0.002) continue;

        vec4 c  = texelFetch(colortex5, tp, 0);
        float wl = exp(-abs(luma(c.rgb) - ref) / (sigmaL * sd + 0.03));
        float w  = wz * wn * wl;
        sum += c * w; wsum += w;
    }
    vec4 res = sum / wsum;
    return (any(isnan(res)) || any(isinf(res))) ? c0 : res;
}