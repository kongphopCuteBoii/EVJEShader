#ifndef LAB_PBR_GLSL
#define LAB_PBR_GLSL

// (000) PBR Setups
struct PBRMaterial {
    float roughness;
    float reflectance;
    float metallic;
    float porosity;
    float subsurface;
    float emission;
};

PBRMaterial defaultMaterial() {
    PBRMaterial mat;
    mat.roughness   = DEFAULT_ROUGHNESS;
    mat.reflectance = DEFAULT_REFLECTANCE;
    mat.metallic    = DEFAULT_METALLIC;
    mat.porosity    = 0.0;
    mat.subsurface  = 0.0;
    mat.emission    = DEFAULT_EMISSION;
    return mat;
}

PBRMaterial decodeLabPBR(vec4 specularTex) {
    PBRMaterial mat;

    #ifndef MC_SPECULAR_MAP
    return defaultMaterial();
    #endif

    if (specularTex.rgb == vec3(0.0)) {
        return defaultMaterial();
    }

    mat.roughness = 1.0 - specularTex.r;

    int g = int(round(specularTex.g * 255.0));
    if (g < 230) {
        mat.metallic    = 0.0;
        mat.reflectance = 0.16 * (specularTex.g * specularTex.g);
    } else {
        mat.metallic    = 1.0;
        mat.reflectance = 0.0;
    }

    int b = int(round(specularTex.b * 255.0));
    if (b <= 64) {
        mat.porosity   = float(b) / 64.0;
        mat.subsurface = 0.0;
    } else {
        mat.porosity   = 0.0;
        mat.subsurface = float(b - 65) / 190.0;
    }

    int a = int(round(specularTex.a * 255.0));
    if (a < 255) mat.emission = float(a) / 254.0;
    else         mat.emission = 0.0;

    return mat;
}

#endif
