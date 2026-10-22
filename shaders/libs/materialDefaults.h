// (000) Material Defaults
#ifndef MATERIAL_DEFAULTS_H
#define MATERIAL_DEFAULTS_H

#define DEFAULT_ROUGHNESS   0.60
#define DEFAULT_REFLECTANCE 0.05
#define DEFAULT_METALLIC    0.0
#define DEFAULT_EMISSION    0.0

// (001) G-Buffer Layout (colortex2)
vec4 fallbackPBR() {
    return vec4(DEFAULT_ROUGHNESS, DEFAULT_METALLIC, DEFAULT_EMISSION, DEFAULT_REFLECTANCE);
}

// (002) Fallback As Minimum
vec4 mergePBR(vec4 pbr) {
    return vec4(min(pbr.r, DEFAULT_ROUGHNESS), pbr.g, pbr.b, max(pbr.a, DEFAULT_REFLECTANCE));
}

#endif
