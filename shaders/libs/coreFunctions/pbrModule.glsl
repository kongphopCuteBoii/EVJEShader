#ifndef PBR_MODULE_GLSL
#define PBR_MODULE_GLSL

#ifndef PI
    #define PI 3.141592653589793
#endif

// (000) Ambient Specular
#ifndef PBR_AMBIENT_SPECULAR
    #define PBR_AMBIENT_SPECULAR 0.0
#endif

// (001) Reflective Surfaces
#ifndef PBR_REFLECTIVE_ROUGHNESS
    #define PBR_REFLECTIVE_ROUGHNESS 0.40
#endif

// (002) Material Struct Definition
struct Material {
    vec3  albedo;
    float alpha;
    float pRough;
    vec3  F0;
    float metallic;
    float emissive;
};

// (003) G-Buffer Decode
Material decodeMaterial(vec4 pbrData, vec3 albedo) {
    Material mat;
    mat.albedo   = albedo;
    mat.emissive = pbrData.b;
    mat.pRough   = pbrData.r;
    mat.metallic = pbrData.g;
    mat.F0       = mix(vec3(pbrData.a), albedo, pbrData.g);
    mat.alpha = max(mat.pRough * mat.pRough, 0.002);
    return mat;
}

// (010) GGX Normal Distribution Function
float D_GGX(float NdotH, float alpha) {
    float alphaSq = alpha * alpha,
          denom   = NdotH * NdotH * (alphaSq - 1.0) + 1.0;
    return alphaSq / (PI * denom * denom);
}

// (011) Correlated Smith Visibility Function
float V_SmithGGXCorrelated(float NdotV, float NdotL, float alpha) {
    float alphaSq = alpha * alpha,
          geomV   = NdotL * sqrt(NdotV * NdotV * (1.0 - alphaSq) + alphaSq),
          geomL   = NdotV * sqrt(NdotL * NdotL * (1.0 - alphaSq) + alphaSq);
    return 0.5 / max(geomV + geomL, 1e-5);
}

// (012) Schlick Fresnel
vec3 F_Schlick(float VdotH, vec3 F0, float pRough) {
    float m       = 1.0 - VdotH,
          m2      = m * m,
          fresnel = m2 * m2 * m;
    return F0 + (max(vec3(1.0 - pRough), F0) - F0) * fresnel;
}

// (013) Split-Sum Environment BRDF Approximation (Lazarov)
vec3 EnvBRDFApprox(vec3 F0, float pRough, float NdotV) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572,  0.022),
               c1 = vec4( 1.0,  0.0425,  1.04,  -0.04);

    vec4  curveR  = pRough * c0 + c1;
    float a004    = min(curveR.x * curveR.x, exp2(-9.28 * NdotV)) * curveR.x + curveR.y;
    vec2  scaleAB = vec2(-1.04, 1.04) * a004 + curveR.zw;

    return F0 * scaleAB.x + scaleAB.y;
}

// (014) Reflective Surface Test
bool isReflective(Material mat) {
    return mat.metallic > 0.5 || mat.pRough < PBR_REFLECTIVE_ROUGHNESS;
}

// (019) Sun Specular Lobe
vec3 specularLobe(Material mat, float NdotL, float NdotV, float NdotH, vec3 fresnel, vec3 lightIlluminance, vec3 sunCol) {
    return fresnel * (D_GGX(NdotH, mat.alpha) * V_SmithGGXCorrelated(NdotV, NdotL, mat.alpha)) * sunCol * 2.0 * lightIlluminance * NdotL;
}

vec3 shadeSunSpecular(Material mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightIlluminance, vec3 sunCol) {
    float NdotL = dot(normal, lightDir);
    if (NdotL <= 0.0) return vec3(0.0);

    vec3  halfDir = normalize(viewDir + lightDir);
    float NdotV   = max(dot(normal, viewDir), 1e-4),
          NdotH   = clamp(dot(normal, halfDir), 0.0, 1.0),
          VdotH   = clamp(dot(viewDir, halfDir), 0.0, 1.0);

    return specularLobe(mat, NdotL, NdotV, NdotH, F_Schlick(VdotH, mat.F0, mat.pRough), lightIlluminance, sunCol);
}

// (020) Direct Analytical Light Evaluation
vec3 shadeDirect(Material mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightIlluminance, vec3 sunCol) {
    float NdotL = dot(normal, lightDir);
    if (NdotL <= 0.0) return vec3(0.0);

    vec3  halfDir  = normalize(viewDir + lightDir);
    float NdotV    = max(dot(normal, viewDir), 1e-4),
          NdotH    = clamp(dot(normal, halfDir), 0.0, 1.0),
          VdotH    = clamp(dot(viewDir, halfDir), 0.0, 1.0);
    vec3  fresnel  = F_Schlick(VdotH, mat.F0, mat.pRough),
          diffuse  = (1.0 - fresnel) * (1.0 - mat.metallic) * mat.albedo / PI;

    return diffuse * lightIlluminance * NdotL + specularLobe(mat, NdotL, NdotV, NdotH, fresnel, lightIlluminance, sunCol);
}

// (021) Image-Based / Environmental Ambient Shading
vec3 shadeAmbient(Material mat, vec3 normal, vec3 viewDir, vec3 skyIrradiance, vec3 skyReflection, float ao) {
    float NdotV = max(dot(normal, viewDir), 1e-4);

    vec3  specularEnv = EnvBRDFApprox(mat.F0, mat.pRough, NdotV) * PBR_AMBIENT_SPECULAR,
          diffuseEnv  = (1.0 - specularEnv) * (1.0 - mat.metallic),
          diffuse     = diffuseEnv * mat.albedo * skyIrradiance,
          specular    = specularEnv * skyReflection;

    return (diffuse + specular) * ao;
}

// (030) Unified PBR Surface Shading Composite
vec3 PBRModule(Material mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 sunIlluminance, vec3 sunCol, float shadow, vec3 skyIrradiance, vec3 skyReflection, float ao, float emissiveStrength) {
    vec3 compositeColor  = shadeDirect(mat, normal, viewDir, lightDir, sunIlluminance, sunCol) * shadow;
    compositeColor      += shadeAmbient(mat, normal, viewDir, skyIrradiance, skyReflection, ao);
    compositeColor      += mat.albedo * mat.emissive * emissiveStrength;

    return compositeColor;
}

#endif
