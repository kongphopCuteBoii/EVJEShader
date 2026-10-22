#ifndef GBUFFER_PACKING_H
#define GBUFFER_PACKING_H

// (001) Octahedral Normal Encoding
vec2 encodeNormalOct(vec3 n) {
    n /= max(abs(n.x) + abs(n.y) + abs(n.z), 1e-5);
    vec2 folded = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0),
         oct    = n.z >= 0.0 ? n.xy : folded;
    return oct * 0.5 + 0.5;
}

vec3 decodeNormalOct(vec2 packedN) {
    vec2 f = packedN * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.xy += vec2(n.x >= 0.0 ? -t : t, n.y >= 0.0 ? -t : t);
    return normalize(n);
}

// (002) Scene Class
float packSceneClass(int type, int foliageCode) {
    return float(type + 16 * foliageCode) / 255.0;
}

int unpackSceneType(float packedClass)    { return int(round(packedClass * 255.0)) & 15; }
int unpackFoliageCode(float packedClass)  { return int(round(packedClass * 255.0)) >> 4; }

#endif
